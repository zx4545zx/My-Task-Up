import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/domain/ids.dart';
import '../features/lists/list_navigation.dart';
import '../features/settings/settings_providers.dart';
import '../features/reminders/reminder_providers.dart';
import '../features/navigation/shell_destination.dart';
import '../features/tasks/task_detail_panel.dart';
import '../features/tasks/task_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcileReminders());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reconcileReminders();
  }

  Future<void> _reconcileReminders() async {
    try {
      await ref.read(reminderCoordinatorProvider).reconcile();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final child = widget.child;
    final destination = ShellDestination.fromLocation(location);
    final selectedIndex = destination == null
        ? 0
        : ShellDestination.values.indexOf(destination);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _createTask,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _createTask,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelectedTask,
        const SingleActivator(LogicalKeyboardKey.escape): _clearSelection,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Scaffold(
              drawer: Drawer(
                child: SafeArea(
                  child: ListNavigation(
                    location: location,
                    closeOnSelect: true,
                  ),
                ),
              ),
              appBar: _appBar(showMenu: true),
              body: child,
              bottomNavigationBar: NavigationBar(
                selectedIndex: selectedIndex,
                destinations: [
                  for (final item in ShellDestination.values)
                    NavigationDestination(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                ],
                onDestinationSelected: (index) =>
                    context.go(ShellDestination.values[index].path),
              ),
            );
          }

          if (constraints.maxWidth <= 1100) {
            return Scaffold(
              drawer: Drawer(
                child: SafeArea(
                  child: ListNavigation(
                    location: location,
                    closeOnSelect: true,
                  ),
                ),
              ),
              appBar: _appBar(showMenu: true),
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: destination == null ? null : selectedIndex,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final item in ShellDestination.values)
                        NavigationRailDestination(
                          icon: Icon(item.icon),
                          label: Text(item.label),
                        ),
                    ],
                    onDestinationSelected: (index) =>
                        context.go(ShellDestination.values[index].path),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: _appBar(showMenu: false),
            body: Row(
              children: [
                SizedBox(width: 244, child: ListNavigation(location: location)),
                const VerticalDivider(width: 1),
                Expanded(child: child),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 320,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: const TaskDetailPanel(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _isEditingText =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  bool get _hasModalRoute => ModalRoute.of(context)?.isCurrent != true;

  Future<void> _createTask() async {
    if (_hasModalRoute) return;
    final settings = ref.read(appSettingsProvider).asData?.value;
    var listId = settings?.defaultListId ?? ListId.inbox;
    final prefix = '/lists/';
    if (widget.location.startsWith(prefix)) {
      try {
        listId = ListId.parse(widget.location.substring(prefix.length));
      } on FormatException catch (error) {
        debugPrint('Could not use current list for new task: $error');
      }
    }
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const _QuickTaskDialog(),
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    try {
      final task = await ref
          .read(taskRepositoryProvider)
          .create(title: title, listId: listId);
      if (!mounted) return;
      if (widget.location != '$prefix${listId.value}') {
        context.go('$prefix${listId.value}');
      }
      ref.read(selectedTaskIdProvider.notifier).select(task.id);
    } catch (error) {
      debugPrint('Could not create task from shortcut: $error');
      if (mounted) _showShortcutError('Could not create the task.');
    }
  }

  void _openSearch() {
    if (!_hasModalRoute) context.go('/search');
  }

  Future<void> _deleteSelectedTask() async {
    if (_hasModalRoute || _isEditingText) return;
    final taskId = ref.read(selectedTaskIdProvider);
    if (taskId == null) return;
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
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(taskRepositoryProvider).delete(taskId);
      ref.read(selectedTaskIdProvider.notifier).select(null);
    } catch (error) {
      debugPrint('Could not delete selected task: $error');
      if (mounted) _showShortcutError('Could not delete the task.');
    }
  }

  void _clearSelection() {
    if (_hasModalRoute || _isEditingText) return;
    ref.read(selectedTaskIdProvider.notifier).select(null);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _showShortcutError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  AppBar _appBar({required bool showMenu}) => AppBar(
    leading: showMenu
        ? Builder(
            builder: (context) => IconButton(
              tooltip: 'Open navigation menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          )
        : null,
    title: const Text('My Task Up'),
    automaticallyImplyLeading: false,
    actions: [
      IconButton(
        tooltip: 'Search tasks',
        icon: const Icon(Icons.search),
        onPressed: () => context.go('/search'),
      ),
    ],
  );
}

class _QuickTaskDialog extends StatefulWidget {
  const _QuickTaskDialog();

  @override
  State<_QuickTaskDialog> createState() => _QuickTaskDialogState();
}

class _QuickTaskDialogState extends State<_QuickTaskDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyboard);
  }

  bool _handleKeyboard(KeyEvent event) {
    if (event is! KeyDownEvent ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorStateOfType<_QuickTaskDialogState>() !=
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
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New task'),
    content: TextField(
      autofocus: true,
      controller: _controller,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: 'Task title'),
      onSubmitted: (_) => _save(),
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

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(message),
      ],
    ),
  );
}
