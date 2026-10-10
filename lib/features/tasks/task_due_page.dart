import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/task.dart';
import '../settings/settings_providers.dart';
import 'task_detail_panel.dart';
import 'task_providers.dart';

class TaskDuePage extends ConsumerWidget {
  const TaskDuePage({required this.upcoming, super.key});

  final bool upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = upcoming ? 'Upcoming' : 'Today';
    final tasks = ref.watch(
      upcoming ? upcomingTasksProvider : todayTasksProvider,
    );
    final showCompleted =
        ref.watch(appSettingsProvider).asData?.value.showCompleted ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        Expanded(
          child: tasks.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Center(child: Text('Tasks could not be loaded.')),
            data: (items) {
              final active = items.where((task) => !task.isCompleted).toList();
              final completed = items
                  .where((task) => task.isCompleted)
                  .toList();
              final groups = _groupByDay(active);
              return CustomScrollView(
                slivers: [
                  if (groups.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No tasks due here.')),
                    )
                  else
                    for (final group in groups.entries) ...[
                      if (upcoming)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                            child: Text(
                              _formatDay(context, group.key),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      SliverList.builder(
                        itemCount: group.value.length,
                        itemBuilder: (context, index) => _TaskDueTile(
                          task: group.value[index],
                          onToggle: () =>
                              _toggle(ref, context, group.value[index]),
                          onOpen: () =>
                              _openTask(context, ref, group.value[index]),
                        ),
                      ),
                    ],
                  if (showCompleted && completed.isNotEmpty)
                    SliverToBoxAdapter(
                      child: ExpansionTile(
                        title: Text('Completed (${completed.length})'),
                        children: completed
                            .map(
                              (task) => _TaskDueTile(
                                task: task,
                                onToggle: () => _toggle(ref, context, task),
                                onOpen: () => _openTask(context, ref, task),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Map<DateTime, List<Task>> _groupByDay(List<Task> tasks) {
    final groups = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final due = task.due!;
      final day = DateTime(due.year, due.month, due.day);
      (groups[day] ??= []).add(task);
    }
    return groups;
  }

  String _formatDay(BuildContext context, DateTime day) =>
      MaterialLocalizations.of(context).formatMediumDate(day);

  Future<void> _toggle(WidgetRef ref, BuildContext context, Task task) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      if (task.isCompleted) {
        await repository.restore(task.id, at: DateTime.now());
      } else {
        await repository.complete(task.id, at: DateTime.now());
      }
      ref.invalidate(upcoming ? upcomingTasksProvider : todayTasksProvider);
      ref.invalidate(taskProvider(task.id));
    } catch (error) {
      debugPrint('Could not update task completion: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the task.')),
        );
      }
    }
  }

  void _openTask(BuildContext context, WidgetRef ref, Task task) {
    ref.read(selectedTaskIdProvider.notifier).select(task.id);
    if (MediaQuery.sizeOf(context).width <= 1100) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.9,
          child: TaskDetailView(taskId: task.id, showCloseButton: true),
        ),
      );
    }
  }
}

class _TaskDueTile extends StatelessWidget {
  const _TaskDueTile({
    required this.task,
    required this.onToggle,
    required this.onOpen,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Checkbox(value: task.isCompleted, onChanged: (_) => onToggle()),
    title: Text(
      task.title.value,
      style: task.isCompleted
          ? const TextStyle(decoration: TextDecoration.lineThrough)
          : null,
    ),
    subtitle: task.due!.minute == null
        ? null
        : Text(_formatTime(task.due!.minute!)),
    onTap: onOpen,
  );

  String _formatTime(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
}
