import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/task.dart';
import 'package:my_task_up/features/reminders/reminder_coordinator.dart';
import 'package:my_task_up/features/settings/settings_repository.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository settings;
  late TaskRepository tasks;
  late _FakeReminderPlatform platform;
  late ReminderCoordinator coordinator;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(database);
    platform = _FakeReminderPlatform();
    coordinator = ReminderCoordinator(database, settings, platform);
    tasks = TaskRepository(database, onChanged: coordinator.reconcile);
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async => database.close());

  test(
    'reconciliation registers eligible tasks once and updates changed due',
    () async {
      final task = await _createTask(tasks, due: _futureDue());
      await _createTask(tasks);
      expect((await coordinator.setEnabled(true)).enabled, isTrue);

      var registrations = await database
          .select(database.reminderRegistrations)
          .get();
      expect(registrations, hasLength(1));
      final notificationId = registrations.single.notificationId;
      expect(platform.scheduled.keys, {notificationId});

      await coordinator.reconcile();
      registrations = await database
          .select(database.reminderRegistrations)
          .get();
      expect(registrations, hasLength(1));
      expect(registrations.single.notificationId, notificationId);
      expect(platform.scheduled, hasLength(1));

      final updated = _futureDue(minute: 11 * 60);
      await tasks.edit(
        task.id,
        title: task.title.value,
        notes: null,
        due: updated,
        repeat: task.repeat,
      );
      await coordinator.reconcile();
      registrations = await database
          .select(database.reminderRegistrations)
          .get();
      expect(registrations.single.dueMinute, updated.minute);
      expect(registrations.single.state, 'scheduled');
      expect(platform.canceled, contains(notificationId));
      expect(platform.scheduled[notificationId]?.dueAt.hour, 11);
    },
  );

  test('completion and disabling cancel scheduled notifications', () async {
    final task = await _createTask(tasks, due: _futureDue());
    expect((await coordinator.setEnabled(true)).enabled, isTrue);
    final id = (await database.select(database.reminderRegistrations).get())
        .single
        .notificationId;

    await tasks.complete(task.id, at: DateTime.now());
    expect(
      await database.select(database.reminderRegistrations).get(),
      isEmpty,
    );
    expect(platform.canceled, contains(id));

    final second = await _createTask(tasks, due: _futureDue());
    await coordinator.reconcile();
    final secondId =
        (await database.select(database.reminderRegistrations).get())
            .single
            .notificationId;
    expect((await coordinator.setEnabled(false)).enabled, isFalse);
    expect(
      await database.select(database.reminderRegistrations).get(),
      isEmpty,
    );
    expect(platform.canceled, contains(secondId));
    expect(await tasks.get(second.id), isNotNull);
  });

  test('failed cancellation remains pending and is retried', () async {
    await _createTask(tasks, due: _futureDue());
    await coordinator.setEnabled(true);
    final id = (await database.select(database.reminderRegistrations).get())
        .single
        .notificationId;
    platform.failCancel = true;
    await coordinator.setEnabled(false);
    var registration =
        (await database.select(database.reminderRegistrations).get()).single;
    expect(registration.notificationId, id);
    expect(registration.state, 'pendingCancel');

    platform.failCancel = false;
    await coordinator.reconcile();
    expect(
      await database.select(database.reminderRegistrations).get(),
      isEmpty,
    );
    expect(
      platform.canceled.where((value) => value == id).length,
      greaterThan(1),
    );
  });

  test('permission denial keeps reminders disabled', () async {
    platform.permission = false;
    final result = await coordinator.setEnabled(true);
    expect(result.enabled, isFalse);
    expect((await settings.get()).notificationsEnabled, isFalse);
    expect(
      await database.select(database.reminderRegistrations).get(),
      isEmpty,
    );
  });

  test(
    'failed schedules remain pending and retry without duplicate ids',
    () async {
      await _createTask(tasks, due: _futureDue());
      platform.failSchedule = true;
      final result = await coordinator.setEnabled(true);
      expect(result.enabled, isTrue);
      expect(result.message, contains('could not be scheduled'));
      expect((await settings.get()).notificationsEnabled, isTrue);
      var registration =
          (await database.select(database.reminderRegistrations).get()).single;
      expect(registration.state, 'pendingSchedule');
      final id = registration.notificationId;

      platform.failSchedule = false;
      await coordinator.reconcile();
      registration =
          (await database.select(database.reminderRegistrations).get()).single;
      expect(registration.state, 'scheduled');
      expect(registration.notificationId, id);
      expect(platform.scheduled.keys, {id});
    },
  );

  test('reconcile errors roll back the enabled setting', () async {
    platform.failPermissionCheck = true;

    final result = await coordinator.setEnabled(true);

    expect(result.enabled, isFalse);
    expect((await settings.get()).notificationsEnabled, isFalse);
    expect(
      await database.select(database.reminderRegistrations).get(),
      isEmpty,
    );
  });

  test('deletion cancels a scheduled notification', () async {
    final task = await _createTask(tasks, due: _futureDue());
    await coordinator.setEnabled(true);
    final id = (await database.select(database.reminderRegistrations).get())
        .single
        .notificationId;
    await tasks.delete(task.id);
    expect(
      await database.select(database.reminderRegistrations).get(),
      isEmpty,
    );
    expect(platform.canceled, contains(id));
  });

  test(
    'unsupported platform refuses enable without changing settings',
    () async {
      platform.supported = false;
      final result = await coordinator.setEnabled(true);
      expect(result.enabled, isFalse);
      expect(result.message, reminderUnsupportedMessage);
      expect((await settings.get()).notificationsEnabled, isFalse);
    },
  );
}

Future<Task> _createTask(TaskRepository repository, {LocalDue? due}) =>
    repository.create(title: 'Reminder task').then((task) async {
      if (due == null) return task;
      return repository.edit(
        task.id,
        title: task.title.value,
        notes: null,
        due: due,
        repeat: task.repeat,
      );
    });

LocalDue _futureDue({int minute = 10 * 60}) {
  final day = DateTime.now().add(const Duration(days: 2));
  return LocalDue(
    year: day.year,
    month: day.month,
    day: day.day,
    minute: minute,
  );
}

final class _FakeReminderPlatform implements ReminderPlatform {
  @override
  bool supported = true;
  bool permission = true;
  bool failCancel = false;
  bool failSchedule = false;
  bool failPermissionCheck = false;
  final Map<int, ({String title, String payload, DateTime dueAt})> scheduled =
      {};
  final List<int> canceled = [];

  @override
  String? get notice => null;

  @override
  Future<bool> hasPermission() async {
    if (failPermissionCheck) throw StateError('permission check failed');
    return permission;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String payload,
    required DateTime dueAt,
  }) async {
    if (failSchedule) throw StateError('schedule failed');
    scheduled[id] = (title: title, payload: payload, dueAt: dueAt);
  }

  @override
  Future<void> cancel(int id) async {
    canceled.add(id);
    if (failCancel) throw StateError('cancel failed');
    scheduled.remove(id);
  }
}
