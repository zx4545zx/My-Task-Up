import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/lists/list_navigation.dart';
import '../features/reminders/reminder_providers.dart';
import '../features/navigation/shell_destination.dart';
import '../features/tasks/task_detail_panel.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Scaffold(
            drawer: Drawer(
              child: SafeArea(
                child: ListNavigation(location: location, closeOnSelect: true),
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
                child: ListNavigation(location: location, closeOnSelect: true),
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
    );
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
