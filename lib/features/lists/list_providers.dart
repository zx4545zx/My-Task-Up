import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/task_list.dart';
import '../reminders/reminder_providers.dart';
import 'list_repository.dart';

final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(
    ref.watch(appDatabaseProvider),
    onChanged: () => ref.read(reminderCoordinatorProvider).reconcile(),
  ),
);

final taskListsProvider = FutureProvider<List<TaskList>>(
  (ref) => ref.watch(listRepositoryProvider).all(),
);

final taskListProvider = FutureProvider.family<TaskList?, ListId>(
  (ref, id) => ref.watch(listRepositoryProvider).get(id),
);
