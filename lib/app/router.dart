import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/navigation/shell_destination.dart';
import '../features/settings/settings_page.dart';
import 'shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: ShellDestination.inbox.path,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: ShellDestination.inbox.path,
            builder: (context, state) => const PlaceholderPage(
              title: 'Inbox',
              message: 'Your inbox is ready.',
            ),
          ),
          GoRoute(
            path: ShellDestination.today.path,
            builder: (context, state) => const PlaceholderPage(
              title: 'Today',
              message: 'Tasks due today will appear here.',
            ),
          ),
          GoRoute(
            path: ShellDestination.upcoming.path,
            builder: (context, state) => const PlaceholderPage(
              title: 'Upcoming',
              message: 'Upcoming tasks will appear here.',
            ),
          ),
          GoRoute(
            path: '/lists/:listId',
            builder: (context, state) => PlaceholderPage(
              title: 'My List',
              message: 'List ID: ${state.pathParameters['listId']}',
            ),
          ),
          GoRoute(
            path: ShellDestination.settings.path,
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
