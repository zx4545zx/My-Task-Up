import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/task_list.dart';

final class ListRepository {
  const ListRepository(this.database);

  final AppDatabase database;

  Future<List<TaskList>> all() async {
    final rows = await (database.select(
      database.taskLists,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
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
