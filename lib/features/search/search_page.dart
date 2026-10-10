import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lists/list_providers.dart';
import '../settings/settings_providers.dart';
import '../tasks/task_detail_panel.dart';
import '../tasks/task_providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(taskSearchProvider(query));
    final lists = ref.watch(taskListsProvider);
    final showCompleted =
        ref.watch(appSettingsProvider).asData?.value.showCompleted ?? true;
    final listNames = {
      for (final list in lists.asData?.value ?? []) list.id: list.name,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Search',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search tasks and notes',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(() => query = ''),
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: query.trim().isEmpty
              ? const Center(child: Text('Search all lists by title or notes.'))
              : results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => const Center(
                    child: Text('Search could not be completed.'),
                  ),
                  data: (items) {
                    final visible = showCompleted
                        ? items
                        : items.where((task) => !task.isCompleted).toList();
                    if (visible.isEmpty) {
                      return const Center(child: Text('No matching tasks.'));
                    }
                    return ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final task = visible[index];
                        return ListTile(
                          title: Text(task.title.value),
                          subtitle: Text(
                            [
                              if (task.notes?.isNotEmpty == true) task.notes!,
                              listNames[task.listId] ?? 'List',
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected:
                              ref.watch(selectedTaskIdProvider) == task.id,
                          onTap: () {
                            ref
                                .read(selectedTaskIdProvider.notifier)
                                .select(task.id);
                            if (MediaQuery.sizeOf(context).width <= 1100) {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (context) => FractionallySizedBox(
                                  heightFactor: 0.9,
                                  child: TaskDetailView(
                                    taskId: task.id,
                                    showCloseButton: true,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
