import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/navigation/shell_destination.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final destination = ShellDestination.fromLocation(location);
    final selectedIndex = destination == null
        ? 0
        : ShellDestination.values.indexOf(destination);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Scaffold(
            appBar: _appBar(),
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
            appBar: _appBar(),
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
          appBar: _appBar(),
          body: Row(
            children: [
              SizedBox(
                width: 244,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in ShellDestination.values)
                      _SidebarDestination(
                        destination: item,
                        selected: destination == item,
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 320,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: const Center(
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  AppBar _appBar() =>
      AppBar(title: const Text('My Task Up'), automaticallyImplyLeading: false);
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.destination,
    required this.selected,
  });

  final ShellDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    child: ListTile(
      selected: selected,
      leading: Icon(destination.icon),
      title: Text(destination.label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => context.go(destination.path),
    ),
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
