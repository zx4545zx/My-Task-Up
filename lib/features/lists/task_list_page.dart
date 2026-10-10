import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                    data: (items) => items.isEmpty
                        ? const Center(child: Text('No tasks yet.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final task = items[index];
                              return ListTile(
                                key: ValueKey(task.id),
                                leading: Checkbox(
                                  value: task.isCompleted,
                                  onChanged: (_) => _toggleTask(task),
                                ),
                                title: Text(
                                  task.title.value,
                                  style: task.isCompleted
                                      ? const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                        )
                                      : null,
                                ),
                                subtitle: task.notes == null
                                    ? null
                                    : Text(task.notes!),
                                selected:
                                    ref.watch(selectedTaskIdProvider) ==
                                    task.id,
                                onTap: () => _openTask(task.id),
                                trailing: PopupMenuButton<_TaskAction>(
                                  tooltip: 'Task actions',
                                  onSelected: (action) {
                                    switch (action) {
                                      case _TaskAction.duplicate:
                                        _duplicateTask(task.id);
                                      case _TaskAction.delete:
                                        _deleteTask(task.id);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: _TaskAction.duplicate,
                                      child: Text('Duplicate'),
                                    ),
                                    PopupMenuItem(
                                      value: _TaskAction.delete,
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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
          .create(title: title, listId: widget.listId);
      _titleController.clear();
      ref.invalidate(tasksForListProvider(widget.listId));
      ref.read(selectedTaskIdProvider.notifier).select(task.id);
    } catch (error) {
      debugPrint('Could not create task: $error');
      if (mounted) _showError('Could not create the task.');
    }
  }

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

  Future<void> _duplicateTask(TaskId id) async {
    try {
      final task = await ref.read(taskRepositoryProvider).duplicate(id);
      ref.invalidate(tasksForListProvider(widget.listId));
      ref.read(selectedTaskIdProvider.notifier).select(task.id);
    } catch (error) {
      debugPrint('Could not duplicate task: $error');
      if (mounted) _showError('Could not duplicate the task.');
    }
  }

  Future<void> _deleteTask(TaskId id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This task will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(taskRepositoryProvider).delete(id);
      ref.invalidate(tasksForListProvider(widget.listId));
      ref.read(selectedTaskIdProvider.notifier).select(null);
    } catch (error) {
      debugPrint('Could not delete task: $error');
      if (mounted) _showError('Could not delete the task.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _TaskAction { duplicate, delete }
