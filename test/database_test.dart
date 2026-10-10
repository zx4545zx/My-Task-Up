import 'dart:io';

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
  late Directory directory;
  late File file;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('my-task-up-');
    file = File('${directory.path}/tasks.sqlite');
    database = AppDatabase.forTesting(NativeDatabase(file));
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'seeds Inbox and default settings, then persists task data on reopen',
    () async {
      final lists = await ListRepository(database).all();
      expect(lists, hasLength(1));
      expect(lists.single.name, 'Inbox');
      expect(lists.single.isInbox, isTrue);

      final settings = await SettingsRepository(database).get();
      expect(settings.defaultListId, ListId.inbox);
      expect(settings.themeMode, AppThemeMode.system);

      final now = DateTime.utc(2026, 10, 10);
      final task = Task(
        id: TaskId.newId(),
        listId: ListId.inbox,
        title: TaskTitle('  Write tests  '),
        notes: 'survives restart',
        due: LocalDue(year: 2027, month: 2, day: 28, minute: 540),
        repeat: CustomRepeat(
          interval: RepeatInterval.weeks,
          every: 2,
          weekdays: const {Weekday.monday, Weekday.friday},
        ),
        position: 3,
        createdAt: now,
        updatedAt: now,
      );
      await TaskRepository(database).save(task);
      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(file));
      final restored = await TaskRepository(database).get(task.id);
      expect(restored?.title.value, 'Write tests');
      expect(restored?.notes, 'survives restart');
      expect(restored?.due?.dayKey, 20270228);
      expect(restored?.due?.minute, 540);
      expect(restored?.repeat, isA<CustomRepeat>());
      expect((restored!.repeat as CustomRepeat).weekdays, {
        Weekday.monday,
        Weekday.friday,
      });
    },
  );

  test('rejects nested subtasks and invalid local values', () async {
    final repository = TaskRepository(database);
    final now = DateTime.utc(2026, 10, 10);
    final parent = Task(
      id: TaskId.newId(),
      listId: ListId.inbox,
      title: TaskTitle('Parent'),
      repeat: const NeverRepeat(),
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
    final child = Task(
      id: TaskId.newId(),
      listId: ListId.inbox,
      parentId: parent.id,
      title: TaskTitle('Child'),
      repeat: const NeverRepeat(),
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(parent);
    await repository.save(child);

    final grandchild = Task(
      id: TaskId.newId(),
      listId: ListId.inbox,
      parentId: child.id,
      title: TaskTitle('Grandchild'),
      repeat: const NeverRepeat(),
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
    await expectLater(repository.save(grandchild), throwsStateError);
    expect(() => TaskTitle('  '), throwsArgumentError);
    expect(() => LocalDue(year: 2026, month: 2, day: 30), throwsArgumentError);
  });
}
