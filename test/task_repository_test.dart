import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/ids.dart';
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
    'creates, edits, completes, restores, duplicates and deletes tasks',
    () async {
      final task = await tasks.create(title: '  Draft release notes  ');
      expect(task.title.value, 'Draft release notes');
      expect(task.listId, ListId.inbox);
      expect(task.position, 0);

      final edited = await tasks.edit(
        task.id,
        title: 'Release notes',
        notes: 'Summarize changes',
      );
      expect(edited.title.value, 'Release notes');
      expect(edited.notes, 'Summarize changes');

      final completedAt = DateTime.utc(2026, 10, 10, 9);
      final completed = await tasks.complete(task.id, at: completedAt);
      expect(completed.completedAt!.isAtSameMomentAs(completedAt), isTrue);
      expect(
        (await tasks.complete(
          task.id,
          at: completedAt.add(const Duration(days: 1)),
        )).completedAt!.isAtSameMomentAs(completedAt),
        isTrue,
      );

      final duplicate = await tasks.duplicate(task.id);
      expect(duplicate.id, isNot(task.id));
      expect(duplicate.title.value, 'Release notes');
      expect(duplicate.notes, 'Summarize changes');
      expect(duplicate.position, 1);
      expect(duplicate.isCompleted, isFalse);

      final restoredAt = DateTime.utc(2026, 10, 11, 9);
      final restored = await tasks.restore(task.id, at: restoredAt);
      expect(restored.isCompleted, isFalse);
      expect(restored.updatedAt.isAtSameMomentAs(restoredAt), isTrue);

      await tasks.delete(task.id);
      expect(await tasks.get(task.id), isNull);
      expect(await tasks.get(duplicate.id), isNotNull);
    },
  );
}
