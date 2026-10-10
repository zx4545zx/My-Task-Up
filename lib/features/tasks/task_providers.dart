import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/task.dart';
import 'task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(appDatabaseProvider)),
);

final tasksForListProvider = FutureProvider.family<List<Task>, ListId>(
  (ref, listId) => ref.watch(taskRepositoryProvider).forList(listId),
);

final taskProvider = FutureProvider.family<Task?, TaskId>(
  (ref, taskId) => ref.watch(taskRepositoryProvider).get(taskId),
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
