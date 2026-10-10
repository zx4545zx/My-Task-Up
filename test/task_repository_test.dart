import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/ids.dart';
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
