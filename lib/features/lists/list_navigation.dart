import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/task_list.dart';
import '../navigation/shell_destination.dart';
import '../settings/settings_providers.dart';
import '../tasks/task_providers.dart';
import 'list_providers.dart';
import 'list_repository.dart';

class ListNavigation extends ConsumerWidget {
  const ListNavigation({
    required this.location,
    this.closeOnSelect = false,
    super.key,
  });

  final String location;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(taskListsProvider);
    return lists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const Center(child: Text('Lists could not be loaded.')),
      data: (items) {
        final customLists = items.where((item) => !item.isInbox).toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  for (final destination in ShellDestination.values)
                    ListTile(
                      leading: Icon(destination.icon),
                      title: Text(destination.label),
                      selected: location == destination.path,
                      onTap: () => _go(context, destination.path),
                    ),
                  if (customLists.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                      child: Text('My lists'),
                    ),
                ]),
              ),
            ),
            if (customLists.isNotEmpty)
              SliverReorderableList(
                itemCount: customLists.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _moveList(context, ref, customLists, oldIndex, newIndex),
                itemBuilder: (context, index) =>
                    _customListTile(context, ref, customLists, index),
              ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add list'),
                onTap: () => _createList(context, ref),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _customListTile(
    BuildContext context,
    WidgetRef ref,
    List<TaskList> lists,
    int index,
  ) {
    final list = lists[index];
    return Material(
      key: ValueKey(list.id),
      type: MaterialType.transparency,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Tooltip(
            message: 'Reorder list',
            child: Icon(Icons.drag_indicator),
          ),
        ),
        title: Text(list.name),
        selected: location == '/lists/${list.id.value}',
        onTap: () => _go(context, '/lists/${list.id.value}'),
        trailing: PopupMenuButton<_ListAction>(
          tooltip: 'List actions',
          onSelected: (action) {
            switch (action) {
              case _ListAction.moveUp:
                _moveList(context, ref, lists, index, index - 1);
              case _ListAction.moveDown:
                _moveList(context, ref, lists, index, index + 1);
              case _ListAction.rename:
                _renameList(context, ref, list);
              case _ListAction.delete:
                _deleteList(context, ref, list);
            }
          },
          itemBuilder: (context) => [
            if (index > 0)
              const PopupMenuItem(
                value: _ListAction.moveUp,
                child: Text('Move up'),
              ),
            if (index < lists.length - 1)
              const PopupMenuItem(
                value: _ListAction.moveDown,
                child: Text('Move down'),
              ),
            const PopupMenuItem(
              value: _ListAction.rename,
              child: Text('Rename'),
            ),
            const PopupMenuItem(
              value: _ListAction.delete,
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveList(
    BuildContext context,
    WidgetRef ref,
    List<TaskList> lists,
    int index,
    int newIndex,
  ) async {
    final reordered = lists.toList();
    final list = reordered.removeAt(index);
    reordered.insert(newIndex, list);
    try {
      await ref
          .read(listRepositoryProvider)
          .reorder(reordered.map((item) => item.id).toList());
      ref.invalidate(taskListsProvider);
    } catch (error) {
      debugPrint('Could not reorder lists: $error');
      if (context.mounted) _showError(context, 'Could not reorder lists.');
    }
  }

  void _go(BuildContext context, String path) {
    if (closeOnSelect) Scaffold.of(context).closeDrawer();
    context.go(path);
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final name = await _askForName(context, title: 'New list');
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    try {
      final list = await ref.read(listRepositoryProvider).create(name);
      ref.invalidate(taskListsProvider);
      if (context.mounted) _go(context, '/lists/${list.id.value}');
    } catch (error) {
      debugPrint('Could not create list: $error');
      if (context.mounted) _showError(context, 'Could not create the list.');
    }
  }

  Future<void> _renameList(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) async {
    final name = await _askForName(
      context,
      title: 'Rename list',
      initialValue: list.name,
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    try {
      await ref.read(listRepositoryProvider).rename(list.id, name);
      ref.invalidate(taskListsProvider);
      ref.invalidate(taskListProvider(list.id));
    } catch (error) {
      debugPrint('Could not rename list: $error');
      if (context.mounted) _showError(context, 'Could not rename the list.');
    }
  }

  Future<void> _deleteList(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) async {
    final disposition = await showDialog<ListTaskDisposition>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${list.name}?'),
        content: const Text('Choose what to do with its tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, ListTaskDisposition.moveTasksToInbox),
            child: const Text('Move tasks to Inbox'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, ListTaskDisposition.deleteTasks),
            child: const Text('Delete list and tasks'),
          ),
        ],
      ),
    );
    if (disposition == null || !context.mounted) return;
    try {
      await ref
          .read(listRepositoryProvider)
          .delete(list.id, disposition: disposition);
      ref.invalidate(taskListsProvider);
      ref.invalidate(appSettingsProvider);
      ref.read(databaseRevisionProvider.notifier).changed();
      if (location == '/lists/${list.id.value}' && context.mounted) {
        _go(context, ShellDestination.inbox.path);
      }
    } catch (error) {
      debugPrint('Could not delete list: $error');
      if (context.mounted) _showError(context, 'Could not delete the list.');
    }
  }

  Future<String?> _askForName(
    BuildContext context, {
    required String title,
    String initialValue = '',
  }) => showDialog<String>(
    context: context,
    builder: (context) =>
        _ListNameDialog(title: title, initialValue: initialValue),
  );

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _ListAction { moveUp, moveDown, rename, delete }

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'List name'),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}
