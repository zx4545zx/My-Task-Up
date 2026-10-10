import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/app_settings.dart';
import 'package:my_task_up/core/domain/ids.dart';
import 'package:my_task_up/core/domain/task.dart';
import 'package:my_task_up/features/lists/list_repository.dart';
import 'package:my_task_up/features/settings/settings_repository.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';

void main() {
  late AppDatabase database;
  late ListRepository lists;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    lists = ListRepository(database);
  });

  tearDown(() => database.close());

  test('creates, renames, and explicitly reorders custom lists', () async {
    final errands = await lists.create('Errands');
    final work = await lists.create('Work');
    await lists.rename(errands.id, 'Personal');
    await lists.reorder([work.id, errands.id]);

    final ordered = await lists.all();
    expect(ordered.map((list) => list.name), ['Inbox', 'Work', 'Personal']);
    expect(ordered.map((list) => list.position), [0, 1, 2]);
    expect(ordered.first.isInbox, isTrue);
    await expectLater(lists.reorder([work.id, work.id]), throwsStateError);
    expect((await lists.all()).map((list) => list.name), [
      'Inbox',
      'Work',
      'Personal',
    ]);
  });

  test(
    'moving tasks to Inbox keeps subtasks and repairs default list',
    () async {
      final list = await lists.create('Projects');
      await SettingsRepository(database).save(
        AppSettings(
          defaultListId: list.id,
          showCompleted: true,
          notificationsEnabled: true,
          themeMode: AppThemeMode.system,
        ),
      );
      final now = DateTime.utc(2026, 10, 10);
      final parent = Task(
        id: TaskId.newId(),
        listId: list.id,
        title: TaskTitle('Parent'),
        repeat: const NeverRepeat(),
        position: 0,
        createdAt: now,
        updatedAt: now,
      );
      final child = Task(
        id: TaskId.newId(),
        listId: list.id,
        parentId: parent.id,
        title: TaskTitle('Child'),
        repeat: const NeverRepeat(),
        position: 0,
        createdAt: now,
        updatedAt: now,
      );
      final tasks = TaskRepository(database);
      await tasks.save(parent);
      await tasks.save(child);

      await lists.delete(
        list.id,
        disposition: ListTaskDisposition.moveTasksToInbox,
      );

      final restored = await tasks.all();
      expect(restored, hasLength(2));
      expect(restored.every((task) => task.listId == ListId.inbox), isTrue);
      expect(
        restored.singleWhere((task) => task.parentId != null).parentId,
        parent.id,
      );
      expect(
        (await SettingsRepository(database).get()).defaultListId,
        ListId.inbox,
      );
      expect(await lists.get(list.id), isNull);
    },
  );

  test('deletes list tasks and protects Inbox', () async {
    final list = await lists.create('Temporary');
    final now = DateTime.utc(2026, 10, 10);
    final task = Task(
      id: TaskId.newId(),
      listId: list.id,
      title: TaskTitle('Delete me'),
      repeat: const NeverRepeat(),
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
    final tasks = TaskRepository(database);
    await tasks.save(task);

    await expectLater(
      lists.delete(ListId.inbox, disposition: ListTaskDisposition.deleteTasks),
      throwsStateError,
    );
    await lists.delete(list.id, disposition: ListTaskDisposition.deleteTasks);

    expect(await tasks.get(task.id), isNull);
    expect((await lists.all()).map((item) => item.id), [ListId.inbox]);
  });
}
