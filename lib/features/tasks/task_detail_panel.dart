import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/ids.dart';
import '../../core/domain/task.dart';
import 'task_providers.dart';

class TaskDetailPanel extends ConsumerWidget {
  const TaskDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskId = ref.watch(selectedTaskIdProvider);
    return taskId == null
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist, size: 32),
                  SizedBox(height: 12),
                  Text('Task details'),
                  SizedBox(height: 8),
                  Text('Select a task to see its details.'),
                ],
              ),
            ),
          )
        : TaskDetailView(taskId: taskId);
  }
}

class TaskDetailView extends ConsumerWidget {
  const TaskDetailView({
    required this.taskId,
    this.showCloseButton = false,
    super.key,
  });

  final TaskId taskId;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskProvider(taskId));
    return task.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const Center(child: Text('Task details could not be loaded.')),
      data: (value) => value == null
          ? const Center(child: Text('This task no longer exists.'))
          : _TaskDetailsContent(task: value, showCloseButton: showCloseButton),
    );
  }
}

class _TaskDetailsContent extends ConsumerWidget {
  const _TaskDetailsContent({
    required this.task,
    required this.showCloseButton,
  });

  final Task task;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Task details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (showCloseButton)
            IconButton(
              tooltip: 'Close task details',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(task.title.value, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(task.notes?.isNotEmpty == true ? task.notes! : 'No notes.'),
      const SizedBox(height: 24),
      FilledButton.tonalIcon(
        onPressed: () => _editTask(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      OutlinedButton.icon(
        onPressed: () => _toggleCompletion(context, ref),
        icon: Icon(task.isCompleted ? Icons.undo : Icons.check),
        label: Text(task.isCompleted ? 'Restore task' : 'Complete task'),
      ),
      OutlinedButton.icon(
        onPressed: () => _duplicateTask(context, ref),
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Duplicate'),
      ),
      TextButton.icon(
        onPressed: () => _deleteTask(context, ref),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete'),
      ),
    ],
  );

  Future<void> _editTask(BuildContext context, WidgetRef ref) async {
    final changes = await showDialog<_TaskDetailsInput>(
      context: context,
      builder: (context) => _TaskDetailsDialog(task: task),
    );
    if (changes == null || !context.mounted) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .edit(task.id, title: changes.title, notes: changes.notes);
      _refresh(ref);
    } catch (error) {
      debugPrint('Could not edit task: $error');
      if (context.mounted) _showError(context, 'Could not save the task.');
    }
  }

  Future<void> _toggleCompletion(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      if (task.isCompleted) {
        await repository.restore(task.id, at: DateTime.now());
      } else {
        await repository.complete(task.id, at: DateTime.now());
      }
      _refresh(ref);
    } catch (error) {
      debugPrint('Could not update task completion: $error');
      if (context.mounted) _showError(context, 'Could not update the task.');
    }
  }

  Future<void> _duplicateTask(BuildContext context, WidgetRef ref) async {
    try {
      final duplicate = await ref
          .read(taskRepositoryProvider)
          .duplicate(task.id);
      ref.invalidate(tasksForListProvider(task.listId));
      ref.read(selectedTaskIdProvider.notifier).select(duplicate.id);
      if (showCloseButton && context.mounted) Navigator.pop(context);
    } catch (error) {
      debugPrint('Could not duplicate task: $error');
      if (context.mounted) _showError(context, 'Could not duplicate the task.');
    }
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref) async {
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
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(taskRepositoryProvider).delete(task.id);
      ref.invalidate(tasksForListProvider(task.listId));
      ref.read(selectedTaskIdProvider.notifier).select(null);
      if (showCloseButton && context.mounted) Navigator.pop(context);
    } catch (error) {
      debugPrint('Could not delete task: $error');
      if (context.mounted) _showError(context, 'Could not delete the task.');
    }
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(taskProvider(task.id));
    ref.invalidate(tasksForListProvider(task.listId));
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TaskDetailsInput {
  const _TaskDetailsInput({required this.title, required this.notes});

  final String title;
  final String? notes;
}

class _TaskDetailsDialog extends StatefulWidget {
  const _TaskDetailsDialog({required this.task});

  final Task task;

  @override
  State<_TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends State<_TaskDetailsDialog> {
  late final TextEditingController titleController;
  late final TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.task.title.value);
    notesController = TextEditingController(text: widget.task.notes ?? '');
  }

  @override
  void dispose() {
    titleController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit task'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final title = titleController.text.trim();
          if (title.isEmpty) return;
          final notes = notesController.text.trim();
          Navigator.pop(
            context,
            _TaskDetailsInput(
              title: title,
              notes: notes.isEmpty ? null : notes,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}
