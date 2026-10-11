import 'ids.dart';

enum AppThemeMode { system, light, dark }

final class AppSettings {
  const AppSettings({
    required this.defaultListId,
    required this.showCompleted,
    required this.notificationsEnabled,
    required this.themeMode,
  });

  final ListId defaultListId;
  final bool showCompleted;
  final bool notificationsEnabled;
  final AppThemeMode themeMode;

  static final defaults = AppSettings(
    defaultListId: ListId.inbox,
    showCompleted: true,
    notificationsEnabled: false,
    themeMode: AppThemeMode.system,
  );
}
