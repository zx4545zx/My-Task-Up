import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/ids.dart';
import '../../core/domain/task.dart';
import '../lists/list_providers.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    final subtasks = ref.watch(subtasksProvider(task.id));
    final lists = ref.watch(taskListsProvider);
    return ListView(
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
        Text(
          task.title.value,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(task.notes?.isNotEmpty == true ? task.notes! : 'No notes.'),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Due'),
          subtitle: Text(_dueLabel(context)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Repeat'),
          subtitle: Text(_repeatLabel(task.repeat)),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 24),
        lists.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) =>
              const Text('Lists could not be loaded.'),
          data: (items) => DropdownButtonFormField<ListId>(
            initialValue: task.listId,
            decoration: InputDecoration(
              labelText: task.parentId == null
                  ? 'Move task and subtasks to list'
                  : 'Move parent task group to list',
            ),
            items: [
              for (final item in items)
                DropdownMenuItem(value: item.id, child: Text(item.name)),
            ],
            onChanged: (destination) {
              if (destination != null && destination != task.listId) {
                _moveTask(context, ref, destination);
              }
            },
          ),
        ),
        if (task.parentId == null) ...[
          const SizedBox(height: 24),
          Text('Subtasks', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _AddSubtaskField(
            onSubmitted: (title) => _createSubtask(context, ref, title),
          ),
          const SizedBox(height: 8),
          subtasks.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) =>
                const Text('Subtasks could not be loaded.'),
            data: (items) => items.isEmpty
                ? const Text('No subtasks yet.')
                : SizedBox(
                    height: math.min(280.0, items.length * 64.0),
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: true,
                      itemCount: items.length,
                      onReorderItem: (oldIndex, newIndex) => _reorderSubtasks(
                        context,
                        ref,
                        items,
                        oldIndex,
                        newIndex,
                      ),
                      itemBuilder: (context, index) {
                        final subtask = items[index];
                        return ListTile(
                          key: ValueKey(subtask.id),
                          leading: Checkbox(
                            value: subtask.isCompleted,
                            onChanged: (_) =>
                                _toggleSubtask(context, ref, subtask),
                          ),
                          title: Text(subtask.title.value),
                          onTap: () => _openSubtask(context, ref, subtask.id),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref) async {
    final changes = await showDialog<_TaskDetailsInput>(
      context: context,
      builder: (context) => _TaskDetailsDialog(task: task),
    );
    if (changes == null || !context.mounted) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .edit(
            task.id,
            title: changes.title,
            notes: changes.notes,
            due: changes.due,
            repeat: changes.repeat,
          );
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

  Future<void> _createSubtask(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    try {
      await ref.read(taskRepositoryProvider).createSubtask(task.id, title);
      ref.invalidate(subtasksProvider(task.id));
      ref.invalidate(todayTasksProvider);
      ref.invalidate(upcomingTasksProvider);
    } catch (error) {
      debugPrint('Could not create subtask: $error');
      if (context.mounted) _showError(context, 'Could not create the subtask.');
    }
  }

  Future<void> _toggleSubtask(
    BuildContext context,
    WidgetRef ref,
    Task subtask,
  ) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      if (subtask.isCompleted) {
        await repository.restore(subtask.id, at: DateTime.now());
      } else {
        await repository.complete(subtask.id, at: DateTime.now());
      }
      ref.invalidate(subtasksProvider(task.id));
      ref.invalidate(taskProvider(subtask.id));
      ref.invalidate(todayTasksProvider);
      ref.invalidate(upcomingTasksProvider);
    } catch (error) {
      debugPrint('Could not update subtask: $error');
      if (context.mounted) _showError(context, 'Could not update the subtask.');
    }
  }

  Future<void> _reorderSubtasks(
    BuildContext context,
    WidgetRef ref,
    List<Task> subtasks,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex == oldIndex) return;
    final reordered = subtasks.toList();
    final subtask = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, subtask);
    try {
      await ref
          .read(taskRepositoryProvider)
          .reorderSiblings(
            task.listId,
            task.id,
            reordered.map((item) => item.id).toList(),
          );
      ref.invalidate(subtasksProvider(task.id));
    } catch (error) {
      debugPrint('Could not reorder subtasks: $error');
      if (context.mounted) _showError(context, 'Could not reorder subtasks.');
    }
  }

  void _openSubtask(BuildContext context, WidgetRef ref, TaskId subtaskId) {
    ref.read(selectedTaskIdProvider.notifier).select(subtaskId);
    if (showCloseButton) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.9,
          child: TaskDetailView(taskId: subtaskId, showCloseButton: true),
        ),
      );
    }
  }

  Future<void> _moveTask(
    BuildContext context,
    WidgetRef ref,
    ListId destination,
  ) async {
    try {
      await ref.read(taskRepositoryProvider).moveToList(task.id, destination);
      ref.invalidate(tasksForListProvider(task.listId));
      ref.invalidate(tasksForListProvider(destination));
      ref.invalidate(subtasksProvider(task.parentId ?? task.id));
      ref.invalidate(taskProvider(task.id));
      ref.invalidate(todayTasksProvider);
      ref.invalidate(upcomingTasksProvider);
    } catch (error) {
      debugPrint('Could not move task: $error');
      if (context.mounted) _showError(context, 'Could not move the task.');
    }
  }

  Future<void> _duplicateTask(BuildContext context, WidgetRef ref) async {
    try {
      final duplicate = await ref
          .read(taskRepositoryProvider)
          .duplicate(task.id);
      ref.invalidate(tasksForListProvider(task.listId));
      ref.invalidate(subtasksProvider(task.parentId ?? task.id));
      ref.invalidate(todayTasksProvider);
      ref.invalidate(upcomingTasksProvider);
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
      ref.invalidate(subtasksProvider(task.parentId ?? task.id));
      ref.invalidate(todayTasksProvider);
      ref.invalidate(upcomingTasksProvider);
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
    ref.invalidate(subtasksProvider(task.parentId ?? task.id));
    ref.invalidate(todayTasksProvider);
    ref.invalidate(upcomingTasksProvider);
  }

  String _dueLabel(BuildContext context) {
    final due = task.due;
    if (due == null) return 'No due date';
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(
      DateTime(due.year, due.month, due.day),
    );
    if (due.minute == null) return '$date · All day';
    final time = localizations.formatTimeOfDay(
      TimeOfDay(hour: due.minute! ~/ 60, minute: due.minute! % 60),
    );
    return '$date · $time';
  }

  String _repeatLabel(RepeatRule repeat) => switch (repeat) {
    NeverRepeat() => 'Never',
    DailyRepeat() => 'Daily',
    WeekdaysRepeat() => 'Every weekday',
    WeeklyRepeat() => 'Weekly',
    MonthlyRepeat() => 'Monthly',
    YearlyRepeat() => 'Yearly',
    CustomRepeat(:final interval, :final every, :final weekdays) =>
      'Every $every ${interval.name}${weekdays.isEmpty ? '' : ' on ${weekdays.map(_weekdayLabel).join(', ')}'}',
  };

  String _weekdayLabel(Weekday weekday) => switch (weekday) {
    Weekday.monday => 'Mon',
    Weekday.tuesday => 'Tue',
    Weekday.wednesday => 'Wed',
    Weekday.thursday => 'Thu',
    Weekday.friday => 'Fri',
    Weekday.saturday => 'Sat',
    Weekday.sunday => 'Sun',
  };

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddSubtaskField extends StatefulWidget {
  const _AddSubtaskField({required this.onSubmitted});

  final Future<void> Function(String title) onSubmitted;

  @override
  State<_AddSubtaskField> createState() => _AddSubtaskFieldState();
}

class _AddSubtaskFieldState extends State<_AddSubtaskField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String title) async {
    if (title.trim().isEmpty) return;
    await widget.onSubmitted(title.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    textInputAction: TextInputAction.done,
    decoration: const InputDecoration(
      hintText: 'Add a subtask',
      prefixIcon: Icon(Icons.add),
    ),
    onSubmitted: _submit,
  );
}

class _TaskDetailsInput {
  const _TaskDetailsInput({
    required this.title,
    required this.notes,
    required this.due,
    required this.repeat,
  });

  final String title;
  final String? notes;
  final LocalDue? due;
  final RepeatRule repeat;
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
  late final TextEditingController everyController;
  late LocalDue? due;
  late String repeatType;
  late RepeatInterval interval;
  late Set<Weekday> weekdays;
  int? repeatAnchorDayKey;
  bool repeatChanged = false;
  bool dueError = false;
  bool recurrenceError = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyboard);
    titleController = TextEditingController(text: widget.task.title.value);
    notesController = TextEditingController(text: widget.task.notes ?? '');
    due = widget.task.due;
    final repeat = widget.task.repeat;
    repeatType = switch (repeat) {
      NeverRepeat() => 'never',
      DailyRepeat() => 'daily',
      WeekdaysRepeat() => 'weekdays',
      WeeklyRepeat() => 'weekly',
      MonthlyRepeat() => 'monthly',
      YearlyRepeat() => 'yearly',
      CustomRepeat() => 'custom',
    };
    interval = repeat is CustomRepeat ? repeat.interval : RepeatInterval.days;
    everyController = TextEditingController(
      text: repeat is CustomRepeat ? '${repeat.every}' : '1',
    );
    weekdays = repeat is CustomRepeat ? {...repeat.weekdays} : {};
    repeatAnchorDayKey = switch (repeat) {
      CustomRepeat(:final anchorDayKey) => anchorDayKey,
      MonthlyRepeat(:final anchorDayKey) => anchorDayKey,
      YearlyRepeat(:final anchorDayKey) => anchorDayKey,
      _ => null,
    };
  }

  bool _handleKeyboard(KeyEvent event) {
    if (event is! KeyDownEvent ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorStateOfType<_TaskDetailsDialogState>() !=
            this) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _save();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyboard);
    titleController.dispose();
    notesController.dispose();
    everyController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: due == null
          ? today
          : DateTime(due!.year, due!.month, due!.day),
      firstDate: DateTime(100),
      lastDate: DateTime(9999, 12, 31),
    );
    if (selected == null) return;
    setState(() {
      due = LocalDue(
        year: selected.year,
        month: selected.month,
        day: selected.day,
        minute: due?.minute,
      );
      repeatChanged = true;
      dueError = false;
    });
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: due?.minute == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: due!.minute! ~/ 60, minute: due!.minute! % 60),
    );
    if (selected == null || due == null) return;
    setState(() {
      due = LocalDue(
        year: due!.year,
        month: due!.month,
        day: due!.day,
        minute: selected.hour * 60 + selected.minute,
      );
    });
  }

  RepeatRule _repeatRule() => switch (repeatType) {
    'daily' => const DailyRepeat(),
    'weekdays' => const WeekdaysRepeat(),
    'weekly' => const WeeklyRepeat(),
    'monthly' => MonthlyRepeat(
      anchorDayKey: repeatChanged ? due?.dayKey : repeatAnchorDayKey,
    ),
    'yearly' => YearlyRepeat(
      anchorDayKey: repeatChanged ? due?.dayKey : repeatAnchorDayKey,
    ),
    'custom' => CustomRepeat(
      interval: interval,
      every: int.parse(everyController.text),
      weekdays: interval == RepeatInterval.weeks ? weekdays : const {},
      anchorDayKey: interval == RepeatInterval.weeks && weekdays.isNotEmpty
          ? (repeatChanged ? due?.dayKey : repeatAnchorDayKey)
          : null,
    ),
    _ => const NeverRepeat(),
  };

  void _save() {
    final title = titleController.text.trim();
    final every = int.tryParse(everyController.text);
    if (title.isEmpty || (repeatType != 'never' && due == null)) {
      setState(() => dueError = due == null && repeatType != 'never');
      return;
    }
    if (repeatType == 'custom' &&
        (every == null || every < 1 || every > 9999)) {
      setState(() => recurrenceError = true);
      return;
    }
    final notes = notesController.text.trim();
    Navigator.pop(
      context,
      _TaskDetailsInput(
        title: title,
        notes: notes.isEmpty ? null : notes,
        due: due,
        repeat: _repeatRule(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return AlertDialog(
      title: const Text('Edit task'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Title'),
                onSubmitted: (_) => _save(),
              ),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes'),
                onSubmitted: (_) => _save(),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Due date'),
                subtitle: Text(
                  due == null
                      ? 'No date'
                      : localizations.formatMediumDate(
                          DateTime(due!.year, due!.month, due!.day),
                        ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Choose due date',
                      onPressed: _chooseDate,
                      icon: const Icon(Icons.edit_calendar_outlined),
                    ),
                    if (due != null)
                      IconButton(
                        tooltip: 'Clear due date',
                        onPressed: () => setState(() {
                          due = null;
                          repeatChanged = true;
                          dueError = false;
                        }),
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
              ),
              if (dueError)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choose a due date for recurring tasks.'),
                ),
              if (due != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Due time'),
                  subtitle: Text(
                    due!.minute == null
                        ? 'All day'
                        : localizations.formatTimeOfDay(
                            TimeOfDay(
                              hour: due!.minute! ~/ 60,
                              minute: due!.minute! % 60,
                            ),
                          ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Choose due time',
                        onPressed: _chooseTime,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      if (due!.minute != null)
                        IconButton(
                          tooltip: 'Clear due time',
                          onPressed: () => setState(() {
                            due = LocalDue(
                              year: due!.year,
                              month: due!.month,
                              day: due!.day,
                            );
                          }),
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: repeatType,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem(value: 'never', child: Text('Never')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(
                    value: 'weekdays',
                    child: Text('Every weekday'),
                  ),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom')),
                ],
                onChanged: (value) => setState(() {
                  repeatType = value ?? 'never';
                  repeatChanged = true;
                }),
              ),
              if (repeatType == 'custom') ...[
                if (recurrenceError)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Enter an interval from 1 to 9999.'),
                  ),
                Row(
                  children: [
                    const Text('Every'),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 88,
                      child: TextField(
                        controller: everyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Count'),
                        onChanged: (_) => setState(() {
                          repeatChanged = true;
                          recurrenceError = false;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<RepeatInterval>(
                        initialValue: interval,
                        items: const [
                          DropdownMenuItem(
                            value: RepeatInterval.days,
                            child: Text('days'),
                          ),
                          DropdownMenuItem(
                            value: RepeatInterval.weeks,
                            child: Text('weeks'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          interval = value ?? RepeatInterval.days;
                          repeatChanged = true;
                        }),
                      ),
                    ),
                  ],
                ),
                if (interval == RepeatInterval.weeks)
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final weekday in Weekday.values)
                        FilterChip(
                          label: Text(_weekdayLabel(weekday)),
                          selected: weekdays.contains(weekday),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              weekdays.add(weekday);
                            } else {
                              weekdays.remove(weekday);
                            }
                            repeatChanged = true;
                          }),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  String _weekdayLabel(Weekday weekday) => switch (weekday) {
    Weekday.monday => 'Mon',
    Weekday.tuesday => 'Tue',
    Weekday.wednesday => 'Wed',
    Weekday.thursday => 'Thu',
    Weekday.friday => 'Fri',
    Weekday.saturday => 'Sat',
    Weekday.sunday => 'Sun',
  };
}
