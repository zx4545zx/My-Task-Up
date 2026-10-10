import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/app_settings.dart';
import 'package:my_task_up/core/domain/ids.dart';
import 'package:my_task_up/core/domain/task.dart';
import 'package:my_task_up/features/backup/backup_service.dart';
import 'package:my_task_up/features/lists/list_repository.dart';
import 'package:my_task_up/features/settings/settings_repository.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('exports and imports tasks, lists, recurrence and settings', () async {
    final lists = ListRepository(database);
    final tasks = TaskRepository(database);
    final work = await lists.create('Work');
    final root = await tasks.create(title: 'Release plan', listId: work.id);
    await tasks.edit(
      root.id,
      title: root.title.value,
      notes: 'Keep a local copy',
      due: LocalDue(year: 2027, month: 2, day: 28, minute: 600),
      repeat: CustomRepeat(interval: RepeatInterval.days, every: 3),
    );
    final child = await tasks.createSubtask(root.id, 'Review checklist');
    await tasks.complete(child.id, at: DateTime.utc(2026, 10, 10));
    await SettingsRepository(database).update(
      defaultListId: work.id,
      showCompleted: false,
      themeMode: AppThemeMode.dark,
    );
    final backup = await BackupService(database).exportJson();

    final destination = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(destination.close);
    final replaced = await TaskRepository(
      destination,
    ).create(title: 'Replace this task');
    await TaskRepository(destination).edit(
      replaced.id,
      title: replaced.title.value,
      notes: null,
      due: LocalDue(year: 2099, month: 1, day: 1, minute: 600),
      repeat: const NeverRepeat(),
    );
    await destination
        .into(destination.reminderRegistrations)
        .insert(
          ReminderRegistrationsCompanion.insert(
            taskId: replaced.id.value,
            dueDay: 20990101,
            dueMinute: 600,
            state: 'scheduled',
          ),
        );
    await BackupService(destination).importJson(backup);

    final imported = await TaskRepository(destination).get(root.id);
    final importedChild = await TaskRepository(destination).get(child.id);
    final importedSettings = await SettingsRepository(destination).get();
    expect((await ListRepository(destination).all()).map((list) => list.id), [
      ListId.inbox,
      work.id,
    ]);
    expect(imported?.notes, 'Keep a local copy');
    expect(imported?.due?.dayKey, 20270228);
    expect(imported?.due?.minute, 600);
    expect(imported?.repeat, isA<CustomRepeat>());
    expect(importedChild?.parentId, root.id);
    expect(importedChild?.isCompleted, isTrue);
    expect(importedSettings.defaultListId, work.id);
    expect(importedSettings.showCompleted, isFalse);
    expect(importedSettings.themeMode, AppThemeMode.dark);
    expect(
      await TaskRepository(destination).search('Replace this task'),
      isEmpty,
    );
    final registration = await destination
        .select(destination.reminderRegistrations)
        .getSingle();
    expect(registration.state, 'pendingCancel');
  });

  test('invalid relationship leaves all existing data unchanged', () async {
    final tasks = TaskRepository(database);
    final existing = await tasks.create(title: 'Keep me');
    final settings = SettingsRepository(database);
    final originalSettings = await settings.get();
    final backup =
        jsonDecode(await BackupService(database).exportJson())
            as Map<String, dynamic>;
    (backup['settings'] as Map<String, dynamic>)['defaultListId'] =
        '00000000-0000-4000-8000-000000000099';

    await expectLater(
      BackupService(database).importJson(jsonEncode(backup)),
      throwsA(isA<FormatException>()),
    );
    expect(await tasks.get(existing.id), isNotNull);
    final unchangedSettings = await settings.get();
    expect(unchangedSettings.defaultListId, originalSettings.defaultListId);
    expect(unchangedSettings.showCompleted, originalSettings.showCompleted);
    expect(
      unchangedSettings.notificationsEnabled,
      originalSettings.notificationsEnabled,
    );
    expect(unchangedSettings.themeMode, originalSettings.themeMode);
  });

  test('database failure during import rolls back the transaction', () async {
    final existing = await TaskRepository(
      database,
    ).create(title: 'Existing task');
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    await TaskRepository(source).create(title: 'Imported task');
    final backup = await BackupService(source).exportJson();
    await database.customStatement('''
      CREATE TRIGGER reject_backup_task
      BEFORE INSERT ON tasks
      WHEN NEW.title = 'Imported task'
      BEGIN SELECT RAISE(ABORT, 'blocked by test'); END;
    ''');

    await expectLater(
      BackupService(database).importJson(backup),
      throwsA(anything),
    );
    expect(await TaskRepository(database).get(existing.id), isNotNull);
    expect(await TaskRepository(database).search('Imported task'), isEmpty);
  });

  test('oversized backup is rejected before any data is changed', () async {
    final task = await TaskRepository(database).create(title: 'Keep me');
    final oversized = ''.padRight(maxBackupSizeBytes + 1);

    await expectLater(
      BackupService(database).importJson(oversized),
      throwsA(isA<FormatException>()),
    );
    expect(await TaskRepository(database).get(task.id), isNotNull);
  });

  test('delete all resets data and settings but retains Inbox', () async {
    final work = await ListRepository(database).create('Work');
    await TaskRepository(database).create(title: 'Remove me', listId: work.id);
    await SettingsRepository(database).update(
      defaultListId: work.id,
      showCompleted: false,
      themeMode: AppThemeMode.dark,
    );

    await BackupService(database).deleteAll();

    expect((await ListRepository(database).all()).map((list) => list.id), [
      ListId.inbox,
    ]);
    expect(await TaskRepository(database).all(), isEmpty);
    final settings = await SettingsRepository(database).get();
    expect(settings.defaultListId, ListId.inbox);
    expect(settings.showCompleted, isTrue);
    expect(settings.notificationsEnabled, isFalse);
    expect(settings.themeMode, AppThemeMode.system);
  });
}
