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
      ref.read(taskSearchRevisionProvider.notifier).changed();
      return ref.read(reminderCoordinatorProvider).reconcile();
    },
  ),
);

final taskSearchRevisionProvider =
    NotifierProvider<TaskSearchRevisionController, int>(
      TaskSearchRevisionController.new,
    );

class TaskSearchRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state++;
}

final tasksForListProvider = FutureProvider.family<List<Task>, ListId>(
  (ref, listId) => ref.watch(taskRepositoryProvider).forList(listId),
);

final taskSearchProvider = FutureProvider.autoDispose
    .family<List<Task>, String>((ref, query) {
      ref.watch(taskSearchRevisionProvider);
      return ref.watch(taskRepositoryProvider).search(query);
    });

final taskProvider = FutureProvider.family<Task?, TaskId>(
  (ref, taskId) => ref.watch(taskRepositoryProvider).get(taskId),
);

final todayTasksProvider = FutureProvider.autoDispose<List<Task>>(
  (ref) => ref.read(taskRepositoryProvider).dueOn(DateTime.now()),
);

final upcomingTasksProvider = FutureProvider.autoDispose<List<Task>>(
  (ref) => ref.read(taskRepositoryProvider).upcomingAfter(DateTime.now()),
);

final subtasksProvider = FutureProvider.family<List<Task>, TaskId>(
  (ref, parentId) => ref.watch(taskRepositoryProvider).subtasksFor(parentId),
);

final selectedTaskIdProvider =
    NotifierProvider<SelectedTaskController, TaskId?>(
      SelectedTaskController.new,
    );

class SelectedTaskController extends Notifier<TaskId?> {
  @override
  TaskId? build() => null;

  void select(TaskId? taskId) => state = taskId;
}
