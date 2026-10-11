import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/task.dart';
import '../reminders/reminder_providers.dart';
import 'task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    ref.watch(appDatabaseProvider),
    onChanged: () {
      ref.read(databaseRevisionProvider.notifier).changed();
      return ref.read(reminderCoordinatorProvider).reconcile();
    },
  ),
);

final databaseRevisionProvider =
    NotifierProvider<DatabaseRevisionController, int>(
      DatabaseRevisionController.new,
    );

class DatabaseRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state++;
}

final tasksForListProvider = FutureProvider.family<List<Task>, ListId>((
  ref,
  listId,
) {
  ref.watch(databaseRevisionProvider);
  return ref.watch(taskRepositoryProvider).forList(listId);
});

final taskSearchProvider = FutureProvider.autoDispose
    .family<List<Task>, String>((ref, query) {
      ref.watch(databaseRevisionProvider);
      return ref.watch(taskRepositoryProvider).search(query);
    });

final taskProvider = FutureProvider.family<Task?, TaskId>((ref, taskId) {
  ref.watch(databaseRevisionProvider);
  return ref.watch(taskRepositoryProvider).get(taskId);
});

final todayTasksProvider = FutureProvider.autoDispose<List<Task>>((ref) {
  ref.watch(databaseRevisionProvider);
  return ref.watch(taskRepositoryProvider).dueOn(DateTime.now());
});

final upcomingTasksProvider = FutureProvider.autoDispose<List<Task>>((ref) {
  ref.watch(databaseRevisionProvider);
  return ref.watch(taskRepositoryProvider).upcomingAfter(DateTime.now());
});

final subtasksProvider = FutureProvider.family<List<Task>, TaskId>((
  ref,
  parentId,
) {
  ref.watch(databaseRevisionProvider);
  return ref.watch(taskRepositoryProvider).subtasksFor(parentId);
});

final selectedTaskIdProvider =
    NotifierProvider<SelectedTaskController, TaskId?>(
      SelectedTaskController.new,
    );

class SelectedTaskController extends Notifier<TaskId?> {
  @override
  TaskId? build() => null;

  void select(TaskId? taskId) => state = taskId;
}
