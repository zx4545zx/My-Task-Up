import 'package:drift/drift.dart';

@DataClassName('StoredTaskList')
class TaskLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get position => integer()();
  BoolColumn get isInbox => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StoredTask')
@TableIndex(
  name: 'tasks_by_list_order',
  columns: {#listId, #parentId, #position},
)
@TableIndex(name: 'tasks_by_due_day', columns: {#dueDay})
@TableIndex(name: 'tasks_by_completion', columns: {#completedAt})
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().references(TaskLists, #id)();
  TextColumn get parentId => text().nullable().references(Tasks, #id)();
  TextColumn get recurrenceSeriesId => text().nullable()();
  TextColumn get nextOccurrenceId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get dueDay => integer().nullable()();
  IntColumn get dueMinute => integer().nullable()();
  TextColumn get repeatRule =>
      text().withDefault(const Constant('{"type":"never"}'))();
  IntColumn get position => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ReminderRegistration')
class ReminderRegistrations extends Table {
  IntColumn get notificationId => integer().autoIncrement()();
  TextColumn get taskId => text()();
  IntColumn get dueDay => integer()();
  IntColumn get dueMinute => integer()();
  TextColumn get state => text()();

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    <Column<Object>>{taskId},
  ];
}

@DataClassName('StoredAppSettings')
class AppSettingsEntries extends Table {
  TextColumn get id => text()();
  TextColumn get defaultListId => text().references(TaskLists, #id)();
  BoolColumn get showCompleted => boolean().withDefault(const Constant(true))();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
