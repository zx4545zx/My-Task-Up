import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_task_up/app/app.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/database/database_provider.dart';
import 'package:my_task_up/features/lists/list_repository.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';
import 'package:my_task_up/main.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop drag and due-time save', (tester) async {
    await configureDesktopWindow();
    await windowManager.setSize(const Size(1200, 800));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final lists = ListRepository(database);
    final alpha = await lists.create('Alpha');
    await lists.create('Beta');
    final later = await lists.create('Later');
    final tasks = TaskRepository(database);
    final parent = await tasks.create(title: 'Move this group');
    final child = await tasks.createSubtask(parent.id, 'Keep this subtask');
    final rent = await tasks.create(title: 'Pay rent', listId: alpha.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyTaskUpApp(),
      ),
    );
    await tester.pumpAndSettle();

    final listHandle = tester.getCenter(find.byTooltip('Reorder list').first);
    final betaPosition = tester.getCenter(find.text('Beta'));
    final listDrag = await tester.startGesture(listHandle);
    await listDrag.moveTo(listHandle + const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 100));
    await listDrag.moveTo(betaPosition);
    await tester.pump(const Duration(milliseconds: 500));
    await listDrag.up();
    await tester.pumpAndSettle();
    expect(
      (await lists.all())
          .where((item) => !item.isInbox)
          .map((item) => item.name),
      ['Beta', 'Alpha', 'Later'],
    );

    final taskHandle = tester.getCenter(find.byTooltip('Move task to list'));
    final laterPosition = tester.getCenter(find.text('Later'));
    final taskDrag = await tester.startGesture(taskHandle);
    await taskDrag.moveTo(laterPosition);
    await tester.pump(const Duration(milliseconds: 500));
    await taskDrag.up();
    await tester.pumpAndSettle();
    expect((await tasks.get(parent.id))!.listId, later.id);
    expect((await tasks.get(child.id))!.listId, later.id);
    expect((await tasks.get(child.id))!.parentId, parent.id);

    await tester.tap(find.text('Alpha').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay rent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.byTooltip('Choose due date'));
    await tester.pumpAndSettle();
    if (tomorrow.month != DateTime.now().month) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${tomorrow.day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose due time'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == '09',
      ),
      '10',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == '00',
      ),
      '37',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await tasks.get(rent.id))!.due?.minute, 637);
  });
}
