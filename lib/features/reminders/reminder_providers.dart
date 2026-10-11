import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../settings/settings_providers.dart';
import 'reminder_coordinator.dart';

final reminderPlatformProvider = Provider<ReminderPlatform>(
  (ref) => LocalReminderPlatform(),
);

final reminderCoordinatorProvider = Provider<ReminderCoordinator>(
  (ref) => ReminderCoordinator(
    ref.watch(appDatabaseProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(reminderPlatformProvider),
  ),
);
