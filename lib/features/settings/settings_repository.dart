import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/app_settings.dart';
import '../../core/domain/ids.dart';

final class SettingsRepository {
  SettingsRepository(this.database);

  final AppDatabase database;
  Future<void> _updates = Future<void>.value();

  Future<AppSettings> get() async {
    final row = await (database.select(
      database.appSettingsEntries,
    )..where((entry) => entry.id.equals('primary'))).getSingle();
    return AppSettings(
      defaultListId: ListId.parse(row.defaultListId),
      showCompleted: row.showCompleted,
      notificationsEnabled: row.notificationsEnabled,
      themeMode: AppThemeMode.values.byName(row.themeMode),
    );
  }

  Future<void> save(AppSettings settings) => database
      .into(database.appSettingsEntries)
      .insertOnConflictUpdate(
        AppSettingsEntriesCompanion.insert(
          id: 'primary',
          defaultListId: settings.defaultListId.value,
          showCompleted: Value(settings.showCompleted),
          notificationsEnabled: Value(settings.notificationsEnabled),
          themeMode: Value(settings.themeMode.name),
        ),
      );

  Future<void> update({
    ListId? defaultListId,
    bool? showCompleted,
    bool? notificationsEnabled,
    AppThemeMode? themeMode,
  }) {
    final operation = _updates.catchError((_) {}).then((_) async {
      final current = await get();
      await save(
        AppSettings(
          defaultListId: defaultListId ?? current.defaultListId,
          showCompleted: showCompleted ?? current.showCompleted,
          notificationsEnabled:
              notificationsEnabled ?? current.notificationsEnabled,
          themeMode: themeMode ?? current.themeMode,
        ),
      );
    });
    _updates = operation;
    return operation;
  }
}
