import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/database/app_database.dart';
import '../../core/domain/app_settings.dart';
import '../settings/settings_repository.dart';

const reminderUnsupportedMessage =
    'Scheduled reminders are unavailable on this platform.';

abstract interface class ReminderPlatform {
  bool get supported;
  String? get notice;
  Future<void> initialize();
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<void> schedule({
    required int id,
    required String title,
    required String payload,
    required DateTime dueAt,
  });
  Future<void> cancel(int id);
}

final class ReminderCoordinator {
  ReminderCoordinator(this.database, this.settings, this.platform);

  final AppDatabase database;
  final SettingsRepository settings;
  final ReminderPlatform platform;
  Future<void> _pending = Future<void>.value();

  Future<void> reconcile() {
    final next = _pending.then((_) => _reconcile());
    _pending = next.catchError((Object error, StackTrace stackTrace) {
      _logReminderError('reconcile reminders', error, stackTrace);
    });
    return next;
  }

  Future<ReminderToggleResult> setEnabled(bool enabled) async {
    final current = await settings.get();
    if (!enabled) {
      await settings.save(_withNotifications(current, false));
      try {
        await reconcile();
        return const ReminderToggleResult(enabled: false);
      } catch (error, stackTrace) {
        _logReminderError('disable reminders', error, stackTrace);
        return const ReminderToggleResult(
          enabled: false,
          message:
              'Reminders are off, but some notifications could not be canceled.',
        );
      }
    }
    if (!platform.supported) {
      return const ReminderToggleResult(
        enabled: false,
        message: reminderUnsupportedMessage,
      );
    }
    try {
      await platform.initialize();
      if (!await platform.requestPermission()) {
        await settings.save(_withNotifications(current, false));
        await reconcile();
        return const ReminderToggleResult(
          enabled: false,
          message: 'Notification permission was not granted.',
        );
      }
      await settings.save(_withNotifications(current, true));
      await reconcile();
      final pendingSchedules = await (database.select(
        database.reminderRegistrations,
      )..where((row) => row.state.equals('pendingSchedule'))).get();
      return ReminderToggleResult(
        enabled: true,
        message: pendingSchedules.isNotEmpty
            ? 'Some reminders could not be scheduled and will be retried.'
            : platform.notice,
      );
    } catch (error, stackTrace) {
      _logReminderError('enable reminders', error, stackTrace);
      await settings.save(_withNotifications(current, false));
      try {
        await reconcile();
      } catch (cleanupError, cleanupStackTrace) {
        _logReminderError(
          'clean up after enabling reminders failed',
          cleanupError,
          cleanupStackTrace,
        );
      }
      return const ReminderToggleResult(
        enabled: false,
        message: 'Could not enable notifications.',
      );
    }
  }

  Future<void> _reconcile() async {
    final config = await settings.get();
    final enabled = config.notificationsEnabled && platform.supported;
    if (platform.supported) await platform.initialize();
    final canSchedule = enabled && await platform.hasPermission();
    final now = DateTime.now();
    final day = now.year * 10000 + now.month * 100 + now.day;
    final minute = now.hour * 60 + now.minute + (now.second == 0 ? 0 : 1);
    final candidates = enabled
        ? await (database.select(database.tasks)..where(
                (task) =>
                    task.completedAt.isNull() &
                    task.dueMinute.isNotNull() &
                    (task.dueDay.isBiggerThanValue(day) |
                        (task.dueDay.equals(day) &
                            task.dueMinute.isBiggerOrEqualValue(minute))),
              ))
              .get()
        : <StoredTask>[];
    final wanted = {for (final task in candidates) task.id: task};
    final registrations = await database
        .select(database.reminderRegistrations)
        .get();

    for (var registration in registrations) {
      final task = wanted.remove(registration.taskId);
      if (task == null) {
        await _cancelAndRemove(registration.notificationId);
        continue;
      }
      final changed =
          registration.dueDay != task.dueDay ||
          registration.dueMinute != task.dueMinute;
      if (changed || registration.state == 'pendingCancel') {
        await database
            .into(database.reminderRegistrations)
            .insertOnConflictUpdate(
              ReminderRegistrationsCompanion(
                notificationId: Value(registration.notificationId),
                taskId: Value(task.id),
                dueDay: Value(task.dueDay!),
                dueMinute: Value(task.dueMinute!),
                state: const Value('pendingCancel'),
              ),
            );
        try {
          await platform.cancel(registration.notificationId);
        } catch (error, stackTrace) {
          _logReminderError('cancel changed reminder', error, stackTrace);
          continue;
        }
        await _setRegistration(
          registration.notificationId,
          task,
          'pendingSchedule',
        );
        registration = registration.copyWith(
          dueDay: task.dueDay!,
          dueMinute: task.dueMinute!,
          state: 'pendingSchedule',
        );
      }
      if (canSchedule) await _schedule(registration.notificationId, task);
    }

    if (!canSchedule) return;
    for (final task in wanted.values) {
      final id = await database
          .into(database.reminderRegistrations)
          .insert(
            ReminderRegistrationsCompanion.insert(
              taskId: task.id,
              dueDay: task.dueDay!,
              dueMinute: task.dueMinute!,
              state: 'pendingSchedule',
            ),
          );
      await _schedule(id, task);
    }
  }

  Future<void> _schedule(int id, StoredTask task) async {
    try {
      await platform.schedule(
        id: id,
        title: task.title,
        payload: task.id,
        dueAt: DateTime(
          task.dueDay! ~/ 10000,
          task.dueDay! ~/ 100 % 100,
          task.dueDay! % 100,
          task.dueMinute! ~/ 60,
          task.dueMinute! % 60,
        ),
      );
      await (database.update(
        database.reminderRegistrations,
      )..where((row) => row.notificationId.equals(id))).write(
        const ReminderRegistrationsCompanion(state: Value('scheduled')),
      );
    } catch (error, stackTrace) {
      _logReminderError('schedule reminder $id', error, stackTrace);
      await (database.update(
        database.reminderRegistrations,
      )..where((row) => row.notificationId.equals(id))).write(
        const ReminderRegistrationsCompanion(state: Value('pendingSchedule')),
      );
    }
  }

  Future<void> _cancelAndRemove(int id) async {
    await (database.update(
      database.reminderRegistrations,
    )..where((row) => row.notificationId.equals(id))).write(
      const ReminderRegistrationsCompanion(state: Value('pendingCancel')),
    );
    try {
      await platform.cancel(id);
      await (database.delete(
        database.reminderRegistrations,
      )..where((row) => row.notificationId.equals(id))).go();
    } catch (error, stackTrace) {
      _logReminderError('cancel reminder $id', error, stackTrace);
    }
  }

  Future<void> _setRegistration(int id, StoredTask task, String state) =>
      (database.update(
        database.reminderRegistrations,
      )..where((row) => row.notificationId.equals(id))).write(
        ReminderRegistrationsCompanion(
          dueDay: Value(task.dueDay!),
          dueMinute: Value(task.dueMinute!),
          state: Value(state),
        ),
      );

  AppSettings _withNotifications(AppSettings settings, bool enabled) =>
      AppSettings(
        defaultListId: settings.defaultListId,
        showCompleted: settings.showCompleted,
        notificationsEnabled: enabled,
        themeMode: settings.themeMode,
      );
}

void _logReminderError(String action, Object error, StackTrace stackTrace) {
  developer.log(
    'Failed to $action',
    name: 'MyTaskUp.reminders',
    error: error,
    stackTrace: stackTrace,
  );
}

final class ReminderToggleResult {
  const ReminderToggleResult({required this.enabled, this.message});

  final bool enabled;
  final String? message;
}

final class LocalReminderPlatform implements ReminderPlatform {
  LocalReminderPlatform()
    : _plugin = FlutterLocalNotificationsPlugin(),
      _supported =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows);

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _supported;
  bool _initialized = false;
  bool _exactAlarms = true;

  @override
  bool get supported => _supported;

  @override
  String? get notice {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'MSIX identity is needed to remove delivered notifications from Windows history.';
    }
    if (defaultTargetPlatform == TargetPlatform.android && !_exactAlarms) {
      return 'Reminders may be delayed because exact-alarm access is off.';
    }
    return null;
  }

  @override
  Future<void> initialize() async {
    if (!_supported || _initialized) return;
    tz.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'My Task Up',
          appUserModelId: 'com.example.my_task_up',
          guid: '2DA52932-2A45-4C89-90ED-5977339A6DB0',
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> hasPermission() async {
    if (!_supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      _exactAlarms = await android?.canScheduleExactNotifications() ?? false;
      return await android?.areNotificationsEnabled() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final macOS = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final permissions = await macOS?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (await android?.requestNotificationsPermission() != true) return false;
      await android?.requestExactAlarmsPermission();
      _exactAlarms = await android?.canScheduleExactNotifications() ?? false;
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final macOS = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      return await macOS?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String payload,
    required DateTime dueAt,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: 'Task reminder',
    scheduledDate: tz.TZDateTime.from(dueAt, tz.local),
    payload: payload,
    notificationDetails: NotificationDetails(
      android: const AndroidNotificationDetails(
        'task_reminders',
        'Task reminders',
        channelDescription: 'Reminders for tasks with due times.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
      windows: const WindowsNotificationDetails(),
    ),
    androidScheduleMode: _exactAlarms
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
