import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/app_settings.dart';
import '../../core/domain/ids.dart';
import '../lists/list_providers.dart';
import '../reminders/reminder_coordinator.dart';
import '../reminders/reminder_providers.dart';
import 'settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final reminderPlatform = ref.watch(reminderPlatformProvider);
    final lists = ref.watch(taskListsProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: settings.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) =>
              const Text('Settings could not be loaded.'),
          data: (value) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Default list',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              lists.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) =>
                    const Text('Lists could not be loaded.'),
                data: (items) => DropdownButtonFormField<ListId>(
                  initialValue:
                      items.any((item) => item.id == value.defaultListId)
                      ? value.defaultListId
                      : ListId.inbox,
                  items: [
                    for (final item in items)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (id) {
                    if (id != null) {
                      _save(ref, context, defaultListId: id);
                    }
                  },
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show completed tasks'),
                value: value.showCompleted,
                onChanged: (show) => _save(ref, context, showCompleted: show),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Task reminders'),
                subtitle: Text(
                  !reminderPlatform.supported
                      ? reminderUnsupportedMessage
                      : reminderPlatform.notice ??
                            'Notify for tasks with a due date and time.',
                ),
                value: value.notificationsEnabled,
                onChanged: !reminderPlatform.supported
                    ? null
                    : (enabled) async {
                        final result = await ref
                            .read(reminderCoordinatorProvider)
                            .setEnabled(enabled);
                        ref.invalidate(appSettingsProvider);
                        if (result.message case final message?) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          }
                        }
                      },
              ),
              const SizedBox(height: 16),
              Text('Theme', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in AppThemeMode.values)
                    ChoiceChip(
                      label: Text(_label(mode)),
                      selected: value.themeMode == mode,
                      onSelected: (_) => _save(ref, context, themeMode: mode),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('My Task Up 1.0.0'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    WidgetRef ref,
    BuildContext context, {
    ListId? defaultListId,
    bool? showCompleted,
    AppThemeMode? themeMode,
  }) async {
    try {
      await ref
          .read(settingsRepositoryProvider)
          .update(
            defaultListId: defaultListId,
            showCompleted: showCompleted,
            themeMode: themeMode,
          );
      ref.invalidate(appSettingsProvider);
    } catch (error) {
      debugPrint('Could not save settings: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save settings.')),
        );
      }
    }
  }

  String _label(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => 'System',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };
}
