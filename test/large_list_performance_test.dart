import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/app/app.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/database/database_provider.dart';
import 'package:my_task_up/core/domain/ids.dart';

void main() {
  testWidgets('5,000-task list builds only visible rows', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.resetPhysicalSize);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.batch((batch) {
      batch.insertAll(database.tasks, [
        for (var index = 0; index < 5000; index++)
          TasksCompanion.insert(
            id: TaskId.newId().value,
            listId: ListId.inbox.value,
            title: 'Large task $index',
            createdAt: now,
            updatedAt: now,
            position: index,
          ),
      ]);
    });

    final watch = Stopwatch()..start();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyTaskUpApp(),
      ),
    );
    await tester.pumpAndSettle();
    watch.stop();

    final builtTiles = find.byType(ListTile).evaluate().length;
    expect(find.text('Large task 0'), findsOneWidget);
    expect(find.text('Large task 4999'), findsNothing);
    expect(builtTiles, lessThan(60));
    // Ignore the one-time database fixture setup; this times the UI load and first paint.
    // ignore: avoid_print
    print(
      'M11 large-list probe: tasks=5000, initialLoadMs=${watch.elapsedMilliseconds}, builtTiles=$builtTiles',
    );
  });
}
