import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/repeat_rule_codec.dart';
import '../../core/domain/app_settings.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/task.dart';
import '../../core/domain/task_list.dart';

const backupFormat = 'my-task-up';
const backupVersion = 1;
const maxBackupSizeBytes =
    50 *
    1024 *
    1024; // shortcut: cap buffered JSON at 50 MiB, stream before supporting larger backups.

final class BackupService {
  const BackupService(this.database);

  final AppDatabase database;

  Future<String> exportJson() async {
    final data = await database.transaction(() async {
      final lists = await (database.select(
        database.taskLists,
      )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
      final tasks = await database.select(database.tasks).get();
      final settings = await (database.select(
        database.appSettingsEntries,
      )..where((row) => row.id.equals('primary'))).getSingle();
      return {
        'format': backupFormat,
        'version': backupVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'lists': [
          for (final list in lists)
            {
              'id': list.id,
              'name': list.name,
              'position': list.position,
              'isInbox': list.isInbox,
              'createdAt': list.createdAt,
              'updatedAt': list.updatedAt,
            },
        ],
        'tasks': [
          for (final task in tasks)
            {
              'id': task.id,
              'listId': task.listId,
              'parentId': task.parentId,
              'title': task.title,
              'notes': task.notes,
              'dueDay': task.dueDay,
              'dueMinute': task.dueMinute,
              'repeat': jsonDecode(task.repeatRule),
              'position': task.position,
              'createdAt': task.createdAt,
              'updatedAt': task.updatedAt,
              'completedAt': task.completedAt,
            },
        ],
        'settings': {
          'defaultListId': settings.defaultListId,
          'showCompleted': settings.showCompleted,
          'notificationsEnabled': settings.notificationsEnabled,
          'themeMode': settings.themeMode,
        },
      };
    });
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> importJson(String source) async {
    if (source.length > maxBackupSizeBytes) {
      throw const FormatException('Backup exceeds the 50 MiB limit.');
    }
    final backup = _decode(source);
    await database.transaction(() async {
      await _saveSettings(AppSettings.defaults);
      await _deleteTasks();
      await (database.update(database.reminderRegistrations)).write(
        const ReminderRegistrationsCompanion(state: Value('pendingCancel')),
      );

      final incomingLists = {for (final list in backup.lists) list.id.value};
      final currentLists = await database.select(database.taskLists).get();
      for (final list in currentLists) {
        if (!list.isInbox && !incomingLists.contains(list.id)) {
          await (database.delete(
            database.taskLists,
          )..where((row) => row.id.equals(list.id))).go();
        }
      }
      for (final list in backup.lists) {
        await database
            .into(database.taskLists)
            .insertOnConflictUpdate(_listCompanion(list));
      }
      final tasks = backup.tasks.toList()
        ..sort((a, b) {
          if (a.parentId == null && b.parentId != null) return -1;
          if (a.parentId != null && b.parentId == null) return 1;
          return a.position.compareTo(b.position);
        });
      for (final task in tasks) {
        await database
            .into(database.tasks)
            .insertOnConflictUpdate(_taskCompanion(task));
      }
      await _saveSettings(backup.settings);
    });
  }

  Future<void> deleteAll() => database.transaction(() async {
    await _saveSettings(AppSettings.defaults);
    await _deleteTasks();
    await (database.delete(
      database.taskLists,
    )..where((list) => list.isInbox.equals(false))).go();
    await (database.update(
      database.taskLists,
    )..where((list) => list.id.equals(ListId.inbox.value))).write(
      TaskListsCompanion(
        name: const Value('Inbox'),
        position: const Value(0),
        isInbox: const Value(true),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  });

  Future<void> _deleteTasks() async {
    await (database.delete(
      database.tasks,
    )..where((task) => task.parentId.isNotNull())).go();
    await database.delete(database.tasks).go();
  }

  Future<void> _saveSettings(AppSettings settings) => database
      .into(database.appSettingsEntries)
      .insertOnConflictUpdate(
        AppSettingsEntriesCompanion.insert(
          id: 'primary',
          defaultListId: settings.defaultListId.value,
          showCompleted: Value(settings.showCompleted),
          notificationsEnabled: Value(settings.notificationsEnabled),
          themeMode: Value(settings.themeMode.name),
        ),
      );

  TasksCompanion _taskCompanion(Task task) => TasksCompanion.insert(
    id: task.id.value,
    listId: task.listId.value,
    parentId: Value(task.parentId?.value),
    title: task.title.value,
    notes: Value(task.notes),
    dueDay: Value(task.due?.dayKey),
    dueMinute: Value(task.due?.minute),
    repeatRule: Value(encodeRepeatRule(task.repeat)),
    position: task.position,
    createdAt: task.createdAt.millisecondsSinceEpoch,
    updatedAt: task.updatedAt.millisecondsSinceEpoch,
    completedAt: Value(task.completedAt?.millisecondsSinceEpoch),
  );

  TaskListsCompanion _listCompanion(TaskList list) => TaskListsCompanion.insert(
    id: list.id.value,
    name: list.name,
    position: list.position,
    isInbox: Value(list.isInbox),
    createdAt: list.createdAt.millisecondsSinceEpoch,
    updatedAt: list.updatedAt.millisecondsSinceEpoch,
  );

  _Backup _decode(String source) {
    try {
      final root = _object(jsonDecode(source), 'backup');
      if (_string(root['format'], 'format') != backupFormat ||
          _integer(root['version'], 'version') != backupVersion) {
        throw const FormatException('Unsupported backup format or version.');
      }
      final exportedAt = DateTime.tryParse(
        _string(root['exportedAt'], 'exportedAt'),
      );
      if (exportedAt == null) {
        throw const FormatException('Invalid export timestamp.');
      }
      final lists = _array(
        root['lists'],
        'lists',
      ).map((value) => _decodeList(_object(value, 'list'))).toList();
      final tasks = _array(
        root['tasks'],
        'tasks',
      ).map((value) => _decodeTask(_object(value, 'task'))).toList();
      final settings = _decodeSettings(_object(root['settings'], 'settings'));
      _validateRelationships(lists, tasks, settings);
      return _Backup(lists, tasks, settings);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid backup data: $error');
    }
  }

  TaskList _decodeList(Map<String, Object?> value) => TaskList(
    id: ListId.parse(_string(value['id'], 'list.id')),
    name: _string(value['name'], 'list.name'),
    position: _integer(value['position'], 'list.position'),
    isInbox: _boolean(value['isInbox'], 'list.isInbox'),
    createdAt: _dateTime(value['createdAt'], 'list.createdAt'),
    updatedAt: _dateTime(value['updatedAt'], 'list.updatedAt'),
  );

  Task _decodeTask(Map<String, Object?> value) {
    final dueDay = _optionalInteger(value['dueDay'], 'task.dueDay');
    final dueMinute = _optionalInteger(value['dueMinute'], 'task.dueMinute');
    if (dueMinute != null && dueDay == null) {
      throw const FormatException('A due time requires a due date.');
    }
    final date = dueDay == null ? null : LocalDue.fromDayKey(dueDay);
    final due = date == null
        ? null
        : LocalDue(
            year: date.year,
            month: date.month,
            day: date.day,
            minute: dueMinute,
          );
    final repeat = decodeRepeatRule(jsonEncode(value['repeat']));
    if (repeat is! NeverRepeat && due == null) {
      throw const FormatException('Recurring tasks require a due date.');
    }
    final notes = value['notes'];
    if (notes != null && notes is! String) {
      throw const FormatException('Invalid task.notes.');
    }
    final parentId = value['parentId'];
    if (parentId != null && parentId is! String) {
      throw const FormatException('Invalid task.parentId.');
    }
    return Task(
      id: TaskId.parse(_string(value['id'], 'task.id')),
      listId: ListId.parse(_string(value['listId'], 'task.listId')),
      parentId: parentId == null ? null : TaskId.parse(parentId as String),
      title: TaskTitle(_string(value['title'], 'task.title')),
      notes: notes as String?,
      due: due,
      repeat: repeat,
      position: _integer(value['position'], 'task.position'),
      createdAt: _dateTime(value['createdAt'], 'task.createdAt'),
      updatedAt: _dateTime(value['updatedAt'], 'task.updatedAt'),
      completedAt: _optionalDateTime(value['completedAt'], 'task.completedAt'),
    );
  }

  AppSettings _decodeSettings(Map<String, Object?> value) => AppSettings(
    defaultListId: ListId.parse(
      _string(value['defaultListId'], 'settings.defaultListId'),
    ),
    showCompleted: _boolean(value['showCompleted'], 'settings.showCompleted'),
    notificationsEnabled: _boolean(
      value['notificationsEnabled'],
      'settings.notificationsEnabled',
    ),
    themeMode: AppThemeMode.values.byName(
      _string(value['themeMode'], 'settings.themeMode'),
    ),
  );

  void _validateRelationships(
    List<TaskList> lists,
    List<Task> tasks,
    AppSettings settings,
  ) {
    final listIds = lists.map((list) => list.id.value).toSet();
    if (listIds.length != lists.length ||
        lists.where((list) => list.isInbox).length != 1 ||
        !lists.any(
          (list) =>
              list.id == ListId.inbox &&
              list.isInbox &&
              list.name == 'Inbox' &&
              list.position == 0,
        )) {
      throw const FormatException('Backup must contain one protected Inbox.');
    }
    if (!listIds.contains(settings.defaultListId.value)) {
      throw const FormatException('The default list does not exist.');
    }
    final taskIds = tasks.map((task) => task.id.value).toSet();
    if (taskIds.length != tasks.length) {
      throw const FormatException('Task IDs must be unique.');
    }
    for (final task in tasks) {
      if (!listIds.contains(task.listId.value)) {
        throw const FormatException('A task refers to a missing list.');
      }
      if (task.parentId case final parentId?) {
        final parent = tasks.where((item) => item.id == parentId).firstOrNull;
        if (parent == null ||
            parent.parentId != null ||
            parent.listId != task.listId) {
          throw const FormatException('Invalid subtask relationship.');
        }
      }
    }
  }
}

class _Backup {
  const _Backup(this.lists, this.tasks, this.settings);

  final List<TaskList> lists;
  final List<Task> tasks;
  final AppSettings settings;
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('Invalid $field object.');
  return Map<String, Object?>.from(value);
}

List<Object?> _array(Object? value, String field) {
  if (value is! List) throw FormatException('Invalid $field array.');
  return value;
}

String _string(Object? value, String field) {
  if (value is! String) throw FormatException('Invalid $field.');
  return value;
}

int _integer(Object? value, String field) {
  if (value is! int) throw FormatException('Invalid $field.');
  return value;
}

int? _optionalInteger(Object? value, String field) =>
    value == null ? null : _integer(value, field);

bool _boolean(Object? value, String field) {
  if (value is! bool) throw FormatException('Invalid $field.');
  return value;
}

DateTime _dateTime(Object? value, String field) =>
    DateTime.fromMillisecondsSinceEpoch(_integer(value, field));

DateTime? _optionalDateTime(Object? value, String field) =>
    value == null ? null : _dateTime(value, field);
