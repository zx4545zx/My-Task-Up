import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/task.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';

void main() {
  late AppDatabase database;
  late TaskRepository tasks;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    tasks = TaskRepository(database);
  });

  tearDown(() => database.close());

  test(
    'today filters by local calendar day and keeps completed tasks',
    () async {
      final before = await _withDue(
        tasks,
        await tasks.create(title: 'Yesterday'),
        LocalDue(year: 2026, month: 10, day: 9),
      );
      final allDay = await _withDue(
        tasks,
        await tasks.create(title: 'All day'),
        LocalDue(year: 2026, month: 10, day: 10),
      );
      final timed = await _withDue(
        tasks,
        await tasks.create(title: 'Timed'),
        LocalDue(year: 2026, month: 10, day: 10, minute: 0),
      );
      final completed = await _withDue(
        tasks,
        await tasks.create(title: 'Completed today'),
        LocalDue(year: 2026, month: 10, day: 10),
      );
      await tasks.complete(completed.id, at: DateTime(2026, 10, 10, 8));

      final today = await tasks.dueOn(DateTime(2026, 10, 10, 23, 59));
      expect(today.map((task) => task.id), [allDay.id, completed.id, timed.id]);
      expect(today.every((task) => task.due?.dayKey == 20261010), isTrue);
      expect(await tasks.get(before.id), isNotNull);
    },
  );

  test('upcoming excludes today and orders future calendar days', () async {
    final today = await _withDue(
      tasks,
      await tasks.create(title: 'Today'),
      LocalDue(year: 2026, month: 10, day: 10, minute: 1439),
    );
    final later = await _withDue(
      tasks,
      await tasks.create(title: 'Later'),
      LocalDue(year: 2026, month: 10, day: 12),
    );
    final tomorrow = await _withDue(
      tasks,
      await tasks.create(title: 'Tomorrow'),
      LocalDue(year: 2026, month: 10, day: 11),
    );

    final upcoming = await tasks.upcomingAfter(DateTime(2026, 10, 10, 23, 59));
    expect(upcoming.map((task) => task.id), [tomorrow.id, later.id]);
    expect(await tasks.get(today.id), isNotNull);
  });
}

Future<Task> _withDue(
  TaskRepository repository,
  Task task,
  LocalDue due,
) async {
  final updated = Task(
    id: task.id,
    listId: task.listId,
    parentId: task.parentId,
    title: task.title,
    notes: task.notes,
    due: due,
    repeat: task.repeat,
    position: task.position,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    completedAt: task.completedAt,
  );
  await repository.save(updated);
  return updated;
}
