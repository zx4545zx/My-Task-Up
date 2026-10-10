import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/ids.dart';
import 'list_providers.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({required this.listId, super.key});

  final ListId listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(taskListProvider(listId));
    return list.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const Center(child: Text('This list could not be loaded.')),
      data: (value) => value == null
          ? const Center(child: Text('This list no longer exists.'))
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Tasks in this list will appear here.'),
                ],
              ),
            ),
    );
  }
}
