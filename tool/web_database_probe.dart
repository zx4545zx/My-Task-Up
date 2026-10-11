import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/ids.dart';
import 'package:my_task_up/core/domain/task.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  try {
    final id = TaskId.parse('00000000-0000-4000-8000-000000000002');
    final now = DateTime.utc(2026, 10, 10);
    final database = AppDatabase();
    await TaskRepository(database).save(
      Task(
        id: id,
        listId: ListId.inbox,
        title: TaskTitle('Durable browser task'),
        repeat: const NeverRepeat(),
        position: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.close();

    final reopened = AppDatabase();
    final restored = await TaskRepository(reopened).get(id);
    await reopened.close();
    final result = restored?.title.value == 'Durable browser task'
        ? 'WEB_DATABASE_PERSISTENCE_PASS'
        : 'WEB_DATABASE_PERSISTENCE_FAIL';
    web.document.title = result;
    if (result.endsWith('FAIL')) throw StateError(result);
  } catch (error) {
    web.document.title = 'WEB_DATABASE_PERSISTENCE_FAIL: $error';
    rethrow;
  }
}
