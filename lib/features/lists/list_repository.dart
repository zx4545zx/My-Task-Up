import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/task_list.dart';

enum ListTaskDisposition { deleteTasks, moveTasksToInbox }

final class ListRepository {
  const ListRepository(this.database);

  final AppDatabase database;

  Future<List<TaskList>> all() async {
    final rows =
        await (database.select(database.taskLists)..orderBy([
              (row) => OrderingTerm.asc(row.position),
              (row) => OrderingTerm.asc(row.id),
            ]))
            .get();
    return rows
        .map(
          (row) => TaskList(
            id: ListId.parse(row.id),
            name: row.name,
            position: row.position,
            isInbox: row.isInbox,
            createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
          ),
        )
        .toList();
  }

  Future<TaskList?> get(ListId id) async {
    final row = await (database.select(
      database.taskLists,
    )..where((list) => list.id.equals(id.value))).getSingleOrNull();
    return row == null
        ? null
        : TaskList(
            id: ListId.parse(row.id),
            name: row.name,
            position: row.position,
            isInbox: row.isInbox,
            createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
          );
  }

  Future<TaskList> create(String name) async {
    final now = DateTime.now();
    final current = await all();
    final list = TaskList(
      id: ListId.newId(),
      name: name,
      position: current.isEmpty ? 0 : current.last.position + 1,
      isInbox: false,
      createdAt: now,
      updatedAt: now,
    );
    await save(list);
    return list;
  }

  Future<TaskList> rename(ListId id, String name) async {
    final existing = await get(id);
    if (existing == null) throw StateError('List does not exist.');
    if (existing.isInbox) throw StateError('Inbox cannot be renamed.');
    final updated = TaskList(
      id: existing.id,
      name: name,
      position: existing.position,
      isInbox: false,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await save(updated);
    return updated;
  }

  Future<void> reorder(List<ListId> orderedIds) =>
      database.transaction(() async {
        final lists = await (database.select(
          database.taskLists,
        )..where((list) => list.isInbox.equals(false))).get();
        final existingIds = lists.map((list) => list.id).toSet();
        final requestedIds = orderedIds.map((id) => id.value).toSet();
        if (orderedIds.length != lists.length ||
            requestedIds.length != lists.length ||
            requestedIds.difference(existingIds).isNotEmpty ||
            existingIds.difference(requestedIds).isNotEmpty) {
          throw StateError(
            'Reordering must include every custom list exactly once.',
          );
        }
        for (var index = 0; index < orderedIds.length; index++) {
          await (database.update(database.taskLists)
                ..where((list) => list.id.equals(orderedIds[index].value)))
              .write(TaskListsCompanion(position: Value(index + 1)));
        }
      });

  Future<void> delete(
    ListId id, {
    required ListTaskDisposition disposition,
  }) => database.transaction(() async {
    final list = await (database.select(
      database.taskLists,
    )..where((row) => row.id.equals(id.value))).getSingleOrNull();
    if (list == null) throw StateError('List does not exist.');
    if (list.isInbox || id == ListId.inbox) {
      throw StateError('Inbox cannot be deleted.');
    }

    final tasks =
        await (database.select(database.tasks)
              ..where((task) => task.listId.equals(id.value))
              ..orderBy([
                (task) => OrderingTerm.asc(task.parentId),
                (task) => OrderingTerm.asc(task.position),
              ]))
            .get();
    if (disposition == ListTaskDisposition.deleteTasks) {
      for (final task in tasks.where((task) => task.parentId != null)) {
        await (database.delete(
          database.tasks,
        )..where((row) => row.id.equals(task.id))).go();
      }
      for (final task in tasks.where((task) => task.parentId == null)) {
        await (database.delete(
          database.tasks,
        )..where((row) => row.id.equals(task.id))).go();
      }
    } else {
      final inboxTasks = await (database.select(
        database.tasks,
      )..where((task) => task.listId.equals(ListId.inbox.value))).get();
      final nextPositions = <String?, int>{};
      for (final task in inboxTasks) {
        final parentId = task.parentId;
        nextPositions[parentId] = (nextPositions[parentId] ?? 0) > task.position
            ? nextPositions[parentId]!
            : task.position + 1;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final task in tasks) {
        final position = nextPositions[task.parentId] ?? 0;
        nextPositions[task.parentId] = position + 1;
        await (database.update(
          database.tasks,
        )..where((row) => row.id.equals(task.id))).write(
          TasksCompanion(
            listId: Value(ListId.inbox.value),
            position: Value(position),
            updatedAt: Value(now),
          ),
        );
      }
    }

    final settings = await (database.select(
      database.appSettingsEntries,
    )..where((row) => row.id.equals('primary'))).getSingle();
    if (settings.defaultListId == id.value) {
      await (database.update(
        database.appSettingsEntries,
      )..where((row) => row.id.equals('primary'))).write(
        AppSettingsEntriesCompanion(defaultListId: Value(ListId.inbox.value)),
      );
    }
    await (database.delete(
      database.taskLists,
    )..where((row) => row.id.equals(id.value))).go();
  });

  Future<void> save(TaskList list) => database
      .into(database.taskLists)
      .insertOnConflictUpdate(
        TaskListsCompanion.insert(
          id: list.id.value,
          name: list.name,
          position: list.position,
          isInbox: Value(list.isInbox),
          createdAt: list.createdAt.millisecondsSinceEpoch,
          updatedAt: list.updatedAt.millisecondsSinceEpoch,
        ),
      );
}
