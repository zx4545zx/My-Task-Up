import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/domain/app_settings.dart';
import '../backup/backup_service.dart';
import '../backup/file_picker_web_options.dart';
import '../../core/domain/ids.dart';
import '../lists/list_providers.dart';
import '../reminders/reminder_coordinator.dart';
import '../reminders/reminder_providers.dart';
import '../tasks/task_providers.dart';
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
              Text(
                'Backup and data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Export backup'),
                subtitle: const Text('Save tasks, lists and settings as JSON.'),
                onTap: () => _export(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Import backup'),
                subtitle: const Text(
                  'Replace current data from a JSON backup.',
                ),
                onTap: () => _import(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete all data',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('Keep Inbox and reset settings.'),
                onTap: () => _deleteAll(context, ref),
              ),
              const SizedBox(height: 24),
              const Text('My Task Up 1.0.0'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final json = await BackupService(
        ref.read(appDatabaseProvider),
      ).exportJson();
      final bytes = Uint8List.fromList(utf8.encode(json));
      if (bytes.length > maxBackupSizeBytes) {
        throw const FormatException('Backup exceeds the 50 MiB limit.');
      }
      final result = await FilePicker.saveFile(
        fileName: 'my-task-up-backup.json',
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (result != null && context.mounted) {
        _showMessage(context, 'Backup exported.');
      }
    } catch (error) {
      debugPrint('Could not export backup: $error');
      if (context.mounted) _showMessage(context, 'Could not export backup.');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a My Task Up JSON backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
        webOptions: backupPickerWebOptions,
      );
      if (file == null) return;
      final size = await file.length();
      if (size == null) {
        throw const FormatException('Could not verify backup file size.');
      }
      if (size > maxBackupSizeBytes) {
        throw const FormatException('Backup exceeds the 50 MiB limit.');
      }
      final source = utf8.decode(await file.readAsBytes());
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace current data?'),
          content: const Text(
            'This replaces all tasks, lists and settings with the selected backup. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await ref.read(settingsRepositoryProvider).waitForPendingUpdates();
      await BackupService(ref.read(appDatabaseProvider)).importJson(source);
      if (!context.mounted) return;
      _refreshAfterDataChange(ref);
      await _reconcileReminders(context, ref, 'Backup imported.');
    } on FormatException catch (error) {
      debugPrint('Invalid backup: $error');
      if (context.mounted) {
        _showMessage(context, 'Invalid backup. No data was changed.');
      }
    } catch (error) {
      debugPrint('Could not import backup: $error');
      if (context.mounted) {
        _showMessage(context, 'Could not import backup. No data was changed.');
      }
    }
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'All tasks and custom lists will be permanently deleted. '
          'Inbox remains and settings reset. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(settingsRepositoryProvider).waitForPendingUpdates();
      await BackupService(ref.read(appDatabaseProvider)).deleteAll();
      if (!context.mounted) return;
      _refreshAfterDataChange(ref);
      await _reconcileReminders(context, ref, 'All data deleted.');
    } catch (error) {
      debugPrint('Could not delete all data: $error');
      if (context.mounted) _showMessage(context, 'Could not delete all data.');
    }
  }

  void _refreshAfterDataChange(WidgetRef ref) {
    ref.read(databaseRevisionProvider.notifier).changed();
    ref.read(selectedTaskIdProvider.notifier).select(null);
    ref.invalidate(appSettingsProvider);
  }

  Future<void> _reconcileReminders(
    BuildContext context,
    WidgetRef ref,
    String successMessage,
  ) async {
    try {
      await ref.read(reminderCoordinatorProvider).reconcile();
      final database = ref.read(appDatabaseProvider);
      final registrations = await database
          .select(database.reminderRegistrations)
          .get();
      final hasPending = registrations.any(
        (registration) => registration.state != 'scheduled',
      );
      if (context.mounted) {
        _showMessage(
          context,
          hasPending
              ? 'Data changed, but some reminders still need attention.'
              : successMessage,
        );
      }
    } catch (error) {
      debugPrint('Could not reconcile reminders after data change: $error');
      if (context.mounted) {
        _showMessage(
          context,
          'Data changed, but some reminders could not be updated.',
        );
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
