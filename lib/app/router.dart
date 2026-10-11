import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/domain/ids.dart';
import '../features/lists/task_list_page.dart';
import '../features/navigation/shell_destination.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../features/tasks/task_due_page.dart';
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
            builder: (context, state) => TaskListPage(listId: ListId.inbox),
          ),
          GoRoute(
            path: ShellDestination.today.path,
            builder: (context, state) => const TaskDuePage(upcoming: false),
          ),
          GoRoute(
            path: ShellDestination.upcoming.path,
            builder: (context, state) => const TaskDuePage(upcoming: true),
          ),
          GoRoute(
            path: '/lists/:listId',
            builder: (context, state) {
              final value = state.pathParameters['listId'];
              if (value == null) {
                return const PlaceholderPage(
                  title: 'List not found',
                  message: 'This list does not exist.',
                );
              }
              try {
                return TaskListPage(listId: ListId.parse(value));
              } on FormatException {
                return const PlaceholderPage(
                  title: 'List not found',
                  message: 'This list does not exist.',
                );
              }
            },
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
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
