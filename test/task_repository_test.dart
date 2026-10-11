import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/ids.dart';
import 'package:my_task_up/core/domain/task.dart';
import 'package:my_task_up/features/lists/list_repository.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';

void main() {
  late AppDatabase database;
  late TaskRepository tasks;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    tasks = TaskRepository(database);
  });

  tearDown(() => database.close());

  test(
    'creates, edits, completes, restores, duplicates and deletes tasks',
    () async {
      final task = await tasks.create(title: '  Draft release notes  ');
      expect(task.title.value, 'Draft release notes');
      expect(task.listId, ListId.inbox);
      expect(task.position, 0);

      final edited = await tasks.edit(
        task.id,
        title: 'Release notes',
        notes: 'Summarize changes',
        due: null,
        repeat: const NeverRepeat(),
      );
      expect(edited.title.value, 'Release notes');
      expect(edited.notes, 'Summarize changes');

      final completedAt = DateTime.utc(2026, 10, 10, 9);
      final completed = await tasks.complete(task.id, at: completedAt);
      expect(completed.completedAt!.isAtSameMomentAs(completedAt), isTrue);
      expect(
        (await tasks.complete(
          task.id,
          at: completedAt.add(const Duration(days: 1)),
        )).completedAt!.isAtSameMomentAs(completedAt),
        isTrue,
      );

      final duplicate = await tasks.duplicate(task.id);
      expect(duplicate.id, isNot(task.id));
      expect(duplicate.title.value, 'Release notes');
      expect(duplicate.notes, 'Summarize changes');
      expect(duplicate.position, 1);
      expect(duplicate.isCompleted, isFalse);

      final restoredAt = DateTime.utc(2026, 10, 11, 9);
      final restored = await tasks.restore(task.id, at: restoredAt);
      expect(restored.isCompleted, isFalse);
      expect(restored.updatedAt.isAtSameMomentAs(restoredAt), isTrue);

      await tasks.delete(task.id);
      expect(await tasks.get(task.id), isNull);
      expect(await tasks.get(duplicate.id), isNotNull);
    },
  );

  test(
    'completion atomically creates one anchored recurring occurrence',
    () async {
      final task = await tasks.create(title: 'Water plants');
      final due = LocalDue(year: 2026, month: 10, day: 5, minute: 540);
      final recurring = Task(
        id: task.id,
        listId: task.listId,
        title: task.title,
        repeat: CustomRepeat(
          interval: RepeatInterval.weeks,
          every: 2,
          weekdays: {Weekday.monday, Weekday.wednesday},
        ),
        position: task.position,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        due: due,
      );
      await tasks.save(recurring);

      await tasks.complete(task.id, at: DateTime(2026, 10, 5, 9));
      await tasks.complete(task.id, at: DateTime(2026, 10, 5, 10));
      var occurrences = await tasks.forList(ListId.inbox);
      expect(occurrences, hasLength(2));
      expect(occurrences[0].isCompleted, isTrue);
      expect(occurrences[1].due?.dayKey, 20261007);
      expect(occurrences[1].due?.minute, 540);
      expect((occurrences[1].repeat as CustomRepeat).anchorDayKey, 20261005);

      await tasks.complete(occurrences[1].id, at: DateTime(2026, 10, 7, 9));
      occurrences = await tasks.forList(ListId.inbox);
      expect(occurrences, hasLength(3));
      expect(occurrences[2].due?.dayKey, 20261019);
      expect(occurrences[2].isCompleted, isFalse);
    },
  );

  test(
    'restoring and completing a recurring task keeps its next occurrence',
    () async {
      final task = await tasks.create(title: 'Take medicine');
      await tasks.save(
        Task(
          id: task.id,
          listId: task.listId,
          title: task.title,
          repeat: const DailyRepeat(),
          position: task.position,
          createdAt: task.createdAt,
          updatedAt: task.updatedAt,
          due: LocalDue(year: 2026, month: 10, day: 5, minute: 540),
        ),
      );

      await tasks.complete(task.id, at: DateTime(2026, 10, 5, 9));
      var occurrences = await tasks.forList(ListId.inbox);
      final next = occurrences[1];
      expect(next.recurrenceSeriesId, task.id);
      await tasks.edit(
        next.id,
        title: 'Take medicine after breakfast',
        notes: 'Doctor approved this change',
        due: LocalDue(year: 2026, month: 10, day: 12, minute: 600),
        repeat: next.repeat,
      );
      await tasks.complete(next.id, at: DateTime(2026, 10, 6, 9));
      final later = await ListRepository(database).create('Later');
      await tasks.moveToList(next.id, later.id);
      await tasks.restore(task.id, at: DateTime(2026, 10, 7, 9));
      await tasks.complete(task.id, at: DateTime(2026, 10, 7, 10));

      occurrences = await tasks.all();
      final retained = occurrences.singleWhere((item) => item.id == next.id);
      expect(occurrences, hasLength(3));
      expect(retained.title.value, 'Take medicine after breakfast');
      expect(retained.notes, 'Doctor approved this change');
      expect(retained.isCompleted, isTrue);
      expect(retained.listId, later.id);
      expect(retained.due?.dayKey, 20261012);
      expect(retained.due?.minute, 600);
    },
  );

  test('identical recurring roots generate distinct next tasks', () async {
    final first = await tasks.create(title: 'Take vitamins');
    final second = await tasks.create(title: 'Take vitamins');
    for (final root in [first, second]) {
      await tasks.save(
        Task(
          id: root.id,
          listId: root.listId,
          title: root.title,
          repeat: const DailyRepeat(),
          position: root.position,
          createdAt: root.createdAt,
          updatedAt: root.updatedAt,
          due: LocalDue(year: 2026, month: 10, day: 5),
        ),
      );
    }

    await tasks.complete(first.id, at: DateTime(2026, 10, 5));
    await tasks.complete(second.id, at: DateTime(2026, 10, 5));

    final occurrences = await tasks.forList(ListId.inbox);
    expect(occurrences, hasLength(4));
    final firstNext = occurrences.singleWhere(
      (task) => task.id != first.id && task.recurrenceSeriesId == first.id,
    );
    final secondNext = occurrences.singleWhere(
      (task) => task.id != second.id && task.recurrenceSeriesId == second.id,
    );
    expect(firstNext.id, isNot(secondNext.id));
  });

  test(
    'deleting a generated occurrence does not recreate it on restore',
    () async {
      final root = await tasks.create(title: 'Take vitamins');
      await tasks.save(
        Task(
          id: root.id,
          listId: root.listId,
          title: root.title,
          repeat: const DailyRepeat(),
          position: root.position,
          createdAt: root.createdAt,
          updatedAt: root.updatedAt,
          due: LocalDue(year: 2026, month: 10, day: 5),
        ),
      );

      await tasks.complete(root.id, at: DateTime(2026, 10, 5));
      final next = (await tasks.forList(
        ListId.inbox,
      )).singleWhere((task) => task.id != root.id);
      await tasks.delete(next.id);
      await tasks.restore(root.id, at: DateTime(2026, 10, 6));
      await tasks.complete(root.id, at: DateTime(2026, 10, 6, 10));

      expect(await tasks.forList(ListId.inbox), hasLength(1));
    },
  );

  test('monthly recurrence retains its original month-end day', () async {
    final task = await tasks.create(title: 'Pay rent');
    await tasks.save(
      Task(
        id: task.id,
        listId: task.listId,
        title: task.title,
        repeat: const MonthlyRepeat(),
        position: task.position,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        due: LocalDue(year: 2026, month: 1, day: 31),
      ),
    );

    await tasks.complete(task.id, at: DateTime(2026, 1, 31));
    var occurrences = await tasks.forList(ListId.inbox);
    expect(occurrences[1].due?.dayKey, 20260228);
    expect((occurrences[1].repeat as MonthlyRepeat).anchorDayKey, 20260131);

    await tasks.complete(occurrences[1].id, at: DateTime(2026, 2, 28));
    occurrences = await tasks.forList(ListId.inbox);
    expect(occurrences[2].due?.dayKey, 20260331);
  });

  test('search matches titles and notes across lists', () async {
    final work = await ListRepository(database).create('Work');
    final inboxTask = await tasks.create(title: 'Plan launch');
    final literal = await tasks.create(title: '100% done');
    final workTask = await tasks.create(
      title: 'Quarterly report',
      listId: work.id,
    );
    await tasks.edit(
      workTask.id,
      title: workTask.title.value,
      notes: 'Reference needle',
      due: null,
      repeat: const NeverRepeat(),
    );

    expect((await tasks.search('launch')).map((task) => task.id), [
      inboxTask.id,
    ]);
    expect((await tasks.search('NEEDLE')).map((task) => task.id), [
      workTask.id,
    ]);
    expect(await tasks.search('missing'), isEmpty);
    expect((await tasks.search('%')).map((task) => task.id), [literal.id]);
    expect(await tasks.search('  '), isEmpty);
  });

  test('creates single-level subtasks and rejects nested subtasks', () async {
    final parent = await tasks.create(title: 'Plan trip');
    final child = await tasks.createSubtask(parent.id, 'Book flights');

    expect(child.parentId, parent.id);
    expect(child.listId, parent.listId);
    expect((await tasks.subtasksFor(parent.id)).map((task) => task.id), [
      child.id,
    ]);
    await expectLater(
      tasks.createSubtask(child.id, 'Choose seats'),
      throwsA(isA<StateError>()),
    );
  });

  test('reorders all and only the requested siblings', () async {
    final first = await tasks.create(title: 'First');
    final second = await tasks.create(title: 'Second');
    final third = await tasks.create(title: 'Third');

    await tasks.reorderSiblings(ListId.inbox, null, [
      third.id,
      first.id,
      second.id,
    ]);
    expect((await tasks.forList(ListId.inbox)).map((task) => task.id), [
      third.id,
      first.id,
      second.id,
    ]);
    await expectLater(
      tasks.reorderSiblings(ListId.inbox, null, [
        first.id,
        first.id,
        second.id,
      ]),
      throwsA(isA<StateError>()),
    );
    expect((await tasks.forList(ListId.inbox)).map((task) => task.id), [
      third.id,
      first.id,
      second.id,
    ]);

    final childA = await tasks.createSubtask(first.id, 'A');
    final childB = await tasks.createSubtask(first.id, 'B');
    await tasks.reorderSiblings(ListId.inbox, first.id, [childB.id, childA.id]);
    expect((await tasks.subtasksFor(first.id)).map((task) => task.id), [
      childB.id,
      childA.id,
    ]);
  });

  test('moving a subtask moves its parent group together', () async {
    final destination = await ListRepository(database).create('Later');
    final parent = await tasks.create(title: 'Plan trip');
    final child = await tasks.createSubtask(parent.id, 'Book flights');
    final otherChild = await tasks.createSubtask(parent.id, 'Reserve hotel');

    final moved = await tasks.moveToList(child.id, destination.id);

    expect(moved.listId, destination.id);
    expect(moved.parentId, parent.id);
    expect((await tasks.get(parent.id))!.listId, destination.id);
    expect((await tasks.get(otherChild.id))!.listId, destination.id);
    expect(await tasks.forList(ListId.inbox), isEmpty);
    expect((await tasks.forList(destination.id)).map((task) => task.id), [
      parent.id,
    ]);
    expect((await tasks.subtasksFor(parent.id)).map((task) => task.id), [
      child.id,
      otherChild.id,
    ]);
  });
}
