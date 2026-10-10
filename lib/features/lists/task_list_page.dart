import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/task.dart';
import '../../features/tasks/task_detail_panel.dart';
import '../../features/tasks/task_providers.dart';
import 'list_providers.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({required this.listId, super.key});

  final ListId listId;

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(taskListProvider(widget.listId));
    final tasks = ref.watch(tasksForListProvider(widget.listId));
    final showCompleted =
        ref.watch(appSettingsProvider).asData?.value.showCompleted ?? true;
    return list.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const Center(child: Text('This list could not be loaded.')),
      data: (value) => value == null
          ? const Center(child: Text('This list no longer exists.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    value.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Add a task',
                      prefixIcon: Icon(Icons.add),
                    ),
                    onSubmitted: _createTask,
                  ),
                ),
                Expanded(
                  child: tasks.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) =>
                        const Center(child: Text('Tasks could not be loaded.')),
                    data: (items) {
                      final active = items
                          .where((task) => !task.isCompleted)
                          .toList();
                      final completed = items
                          .where((task) => task.isCompleted)
                          .toList();
                      return CustomScrollView(
                        slivers: [
                          if (active.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('No active tasks.')),
                              ),
                            )
                          else
                            SliverReorderableList(
                              itemCount: active.length,
                              onReorderItem: (oldIndex, newIndex) =>
                                  _reorderTasks(
                                    active,
                                    completed,
                                    oldIndex,
                                    newIndex,
                                  ),
                              itemBuilder: (context, index) =>
                                  _buildTaskTile(active[index]),
                            ),
                          if (showCompleted && completed.isNotEmpty)
                            SliverToBoxAdapter(
                              child: ExpansionTile(
                                title: Text('Completed (${completed.length})'),
                                children: completed
                                    .map(_buildTaskTile)
                                    .toList(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _createTask(String title) async {
    if (title.trim().isEmpty) return;
    try {
      final task = await ref
          .read(taskRepositoryProvider)
          .create(
            title: title,
            listId: widget.listId == ListId.inbox ? null : widget.listId,
          );
      _titleController.clear();
      ref.invalidate(tasksForListProvider(task.listId));
      ref.read(selectedTaskIdProvider.notifier).select(task.id);
      if (task.listId != widget.listId && mounted) {
        context.go('/lists/${task.listId.value}');
      }
    } catch (error) {
      debugPrint('Could not create task: $error');
      if (mounted) _showError('Could not create the task.');
    }
  }

  Widget _buildTaskTile(Task task) => ListTile(
    key: ValueKey(task.id),
    leading: Checkbox(
      value: task.isCompleted,
      onChanged: (_) => _toggleTask(task),
    ),
    title: Text(
      task.title.value,
      style: task.isCompleted
          ? const TextStyle(decoration: TextDecoration.lineThrough)
          : null,
    ),
    subtitle: task.notes == null ? null : Text(task.notes!),
    selected: ref.watch(selectedTaskIdProvider) == task.id,
    onTap: () => _openTask(task.id),
  );

  Future<void> _toggleTask(Task task) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      if (task.isCompleted) {
        await repository.restore(task.id, at: DateTime.now());
      } else {
        await repository.complete(task.id, at: DateTime.now());
      }
      ref.invalidate(tasksForListProvider(widget.listId));
      ref.invalidate(taskProvider(task.id));
    } catch (error) {
      debugPrint('Could not update task completion: $error');
      if (mounted) _showError('Could not update the task.');
    }
  }

  void _openTask(TaskId id) {
    ref.read(selectedTaskIdProvider.notifier).select(id);
    if (MediaQuery.sizeOf(context).width <= 1100) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.9,
          child: TaskDetailView(taskId: id, showCloseButton: true),
        ),
      );
    }
  }

  Future<void> _reorderTasks(
    List<Task> active,
    List<Task> completed,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex == oldIndex) return;
    final reordered = active.toList();
    final task = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, task);
    reordered.addAll(completed);
    try {
      await ref
          .read(taskRepositoryProvider)
          .reorderSiblings(
            widget.listId,
            null,
            reordered.map((item) => item.id).toList(),
          );
      ref.invalidate(tasksForListProvider(widget.listId));
    } catch (error) {
      debugPrint('Could not reorder tasks: $error');
      if (mounted) _showError('Could not reorder tasks.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
