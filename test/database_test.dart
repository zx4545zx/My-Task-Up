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

      final settingsRepository = SettingsRepository(database);
      final settings = await settingsRepository.get();
      expect(settings.defaultListId, ListId.inbox);
      expect(settings.themeMode, AppThemeMode.system);
      final work = await ListRepository(database).create('Work');
      await settingsRepository.save(
        AppSettings(
          defaultListId: work.id,
          showCompleted: false,
          notificationsEnabled: false,
          themeMode: AppThemeMode.dark,
        ),
      );

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
        recurrenceSeriesId: TaskId.newId(),
        nextOccurrenceId: TaskId.newId(),
      );
      await TaskRepository(database).save(task);
      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(file));
      final restored = await TaskRepository(database).get(task.id);
      final restoredSettings = await SettingsRepository(database).get();
      expect(restoredSettings.defaultListId, work.id);
      expect(restoredSettings.showCompleted, isFalse);
      expect(restoredSettings.themeMode, AppThemeMode.dark);
      expect(restored?.title.value, 'Write tests');
      expect(restored?.notes, 'survives restart');
      expect(restored?.due?.dayKey, 20270228);
      expect(restored?.due?.minute, 540);
      expect(restored?.repeat, isA<CustomRepeat>());
      expect(restored?.recurrenceSeriesId, task.recurrenceSeriesId);
      expect(restored?.nextOccurrenceId, task.nextOccurrenceId);
      expect((restored!.repeat as CustomRepeat).weekdays, {
        Weekday.monday,
        Weekday.friday,
      });
    },
  );

  test('adds recurrence identity to an existing version 2 database', () async {
    final task = await TaskRepository(database).create(title: 'Existing task');
    await database.customStatement(
      'ALTER TABLE tasks DROP COLUMN recurrence_series_id',
    );
    await database.customStatement(
      'ALTER TABLE tasks DROP COLUMN next_occurrence_id',
    );
    await database.customStatement('PRAGMA user_version = 2');
    await database.close();

    database = AppDatabase.forTesting(NativeDatabase(file));
    expect(await TaskRepository(database).get(task.id), isNotNull);
    final columns = await database
        .customSelect('PRAGMA table_info(tasks)')
        .get();
    expect(
      columns.any((column) => column.data['name'] == 'recurrence_series_id'),
      isTrue,
    );
    expect(
      columns.any((column) => column.data['name'] == 'next_occurrence_id'),
      isTrue,
    );
    await database.close();
    database = AppDatabase.forTesting(NativeDatabase(file));
    expect(await TaskRepository(database).get(task.id), isNotNull);
  });

  test(
    'adds occurrence linkage to version 3 without losing recurrence data',
    () async {
      final seriesId = TaskId.newId();
      final task = await TaskRepository(
        database,
      ).create(title: 'Existing series');
      await TaskRepository(database).save(
        Task(
          id: task.id,
          listId: task.listId,
          recurrenceSeriesId: seriesId,
          title: task.title,
          repeat: const DailyRepeat(),
          due: LocalDue(year: 2026, month: 10, day: 5),
          position: task.position,
          createdAt: task.createdAt,
          updatedAt: task.updatedAt,
        ),
      );
      await database.customStatement(
        'ALTER TABLE tasks DROP COLUMN next_occurrence_id',
      );
      await database.customStatement('PRAGMA user_version = 3');
      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await TaskRepository(database).get(task.id))?.recurrenceSeriesId,
        seriesId,
      );
      final columns = await database
          .customSelect('PRAGMA table_info(tasks)')
          .get();
      expect(
        columns.any((column) => column.data['name'] == 'next_occurrence_id'),
        isTrue,
      );
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await TaskRepository(database).get(task.id))?.recurrenceSeriesId,
        seriesId,
      );
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
