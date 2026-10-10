import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/domain/app_settings.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final appSettingsProvider = FutureProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).get(),
);
