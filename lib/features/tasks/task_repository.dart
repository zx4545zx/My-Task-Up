import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/repeat_rule_codec.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/task.dart';

final class TaskRepository {
  const TaskRepository(this.database);

  final AppDatabase database;

  Future<List<Task>> all() async =>
      (await database.select(database.tasks).get()).map(_fromRow).toList();

  Future<List<Task>> forList(ListId listId) async =>
      (await (database.select(database.tasks)
                ..where((task) => task.listId.equals(listId.value))
                ..orderBy([
                  (task) => OrderingTerm.asc(task.parentId),
                  (task) => OrderingTerm.asc(task.position),
                ]))
              .get())
          .map(_fromRow)
          .toList();

  Future<Task?> get(TaskId id) async {
    final row = await (database.select(
      database.tasks,
    )..where((task) => task.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<Task> create({required String title, ListId? listId}) async {
    final destination = listId ?? await _defaultListId();
    final lastTask =
        await (database.select(database.tasks)
              ..where(
                (task) =>
                    task.listId.equals(destination.value) &
                    task.parentId.isNull(),
              )
              ..orderBy([(task) => OrderingTerm.desc(task.position)])
              ..limit(1))
            .getSingleOrNull();
    final now = DateTime.now();
    final task = Task(
      id: TaskId.newId(),
      listId: destination,
      title: TaskTitle(title),
      repeat: const NeverRepeat(),
      position: (lastTask?.position ?? -1) + 1,
      createdAt: now,
      updatedAt: now,
    );
    await save(task);
    return task;
  }

  Future<Task> edit(
    TaskId id, {
    required String title,
    required String? notes,
  }) async {
    final existing = await get(id);
    if (existing == null) throw StateError('Task does not exist.');
    final updated = Task(
      id: existing.id,
      listId: existing.listId,
      parentId: existing.parentId,
      title: TaskTitle(title),
      notes: notes,
      due: existing.due,
      repeat: existing.repeat,
      position: existing.position,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      completedAt: existing.completedAt,
    );
    await save(updated);
    return updated;
  }

  Future<Task> complete(TaskId id, {required DateTime at}) async {
    final existing = await get(id);
    if (existing == null) throw StateError('Task does not exist.');
    if (existing.isCompleted) return existing;
    final updated = Task(
      id: existing.id,
      listId: existing.listId,
      parentId: existing.parentId,
      title: existing.title,
      notes: existing.notes,
      due: existing.due,
      repeat: existing.repeat,
      position: existing.position,
      createdAt: existing.createdAt,
      updatedAt: at,
      completedAt: at,
    );
    await save(updated);
    return updated;
  }

  Future<Task> restore(TaskId id, {required DateTime at}) async {
    final existing = await get(id);
    if (existing == null) throw StateError('Task does not exist.');
    if (!existing.isCompleted) return existing;
    final updated = Task(
      id: existing.id,
      listId: existing.listId,
      parentId: existing.parentId,
      title: existing.title,
      notes: existing.notes,
      due: existing.due,
      repeat: existing.repeat,
      position: existing.position,
      createdAt: existing.createdAt,
      updatedAt: at,
    );
    await save(updated);
    return updated;
  }

  Future<Task> duplicate(TaskId id) async {
    final existing = await get(id);
    if (existing == null) throw StateError('Task does not exist.');
    final siblings =
        await (database.select(database.tasks)
              ..where(
                (task) =>
                    task.listId.equals(existing.listId.value) &
                    (existing.parentId == null
                        ? task.parentId.isNull()
                        : task.parentId.equals(existing.parentId!.value)),
              )
              ..orderBy([(task) => OrderingTerm.desc(task.position)])
              ..limit(1))
            .getSingleOrNull();
    final now = DateTime.now();
    final copy = Task(
      id: TaskId.newId(),
      listId: existing.listId,
      parentId: existing.parentId,
      title: existing.title,
      notes: existing.notes,
      due: existing.due,
      repeat: existing.repeat,
      position: (siblings?.position ?? -1) + 1,
      createdAt: now,
      updatedAt: now,
    );
    await save(copy);
    return copy;
  }

  Future<void> save(Task task) => database.transaction(() async {
    final listExists = await (database.select(
      database.taskLists,
    )..where((list) => list.id.equals(task.listId.value))).getSingleOrNull();
    if (listExists == null) throw StateError('Task list does not exist.');

    if (task.parentId case final parentId?) {
      final parent = await (database.select(
        database.tasks,
      )..where((row) => row.id.equals(parentId.value))).getSingleOrNull();
      if (parent == null ||
          parent.parentId != null ||
          parent.listId != task.listId.value) {
        throw StateError(
          'Subtasks must belong to a top-level task in the same list.',
        );
      }
      if (parent.id == task.id.value) {
        throw StateError('A task cannot be its own parent.');
      }
    } else {
      final children = await (database.select(
        database.tasks,
      )..where((row) => row.parentId.equals(task.id.value))).get();
      if (children.any((child) => child.listId != task.listId.value)) {
        throw StateError(
          'A parent and its subtasks must belong to the same list.',
        );
      }
    }

    await database
        .into(database.tasks)
        .insertOnConflictUpdate(
          TasksCompanion.insert(
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
          ),
        );
  });

  Future<void> delete(TaskId id) => database.transaction(() async {
    await (database.delete(
      database.tasks,
    )..where((task) => task.parentId.equals(id.value))).go();
    await (database.delete(
      database.tasks,
    )..where((task) => task.id.equals(id.value))).go();
  });

  Future<ListId> _defaultListId() async {
    final settings = await (database.select(
      database.appSettingsEntries,
    )..where((entry) => entry.id.equals('primary'))).getSingle();
    return ListId.parse(settings.defaultListId);
  }

  Task _fromRow(StoredTask row) {
    final dueDay = row.dueDay;
    final due = dueDay == null
        ? null
        : LocalDue(
            year: dueDay ~/ 10000,
            month: (dueDay ~/ 100) % 100,
            day: dueDay % 100,
            minute: row.dueMinute,
          );
    return Task(
      id: TaskId.parse(row.id),
      listId: ListId.parse(row.listId),
      parentId: row.parentId == null ? null : TaskId.parse(row.parentId!),
      title: TaskTitle(row.title),
      notes: row.notes,
      due: due,
      repeat: decodeRepeatRule(row.repeatRule),
      position: row.position,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      completedAt: row.completedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.completedAt!),
    );
  }
}
