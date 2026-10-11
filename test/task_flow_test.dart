import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/app/app.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/database/database_provider.dart';
import 'package:my_task_up/core/domain/ids.dart';
import 'package:my_task_up/core/domain/task.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';

void main() {
  testWidgets(
    'quick add, edit details, create a subtask, complete and restore',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MyTaskUpApp(),
        ),
      );
      await _pumpAsync(tester);
      expect(tester.testTextInput.isVisible, isTrue);

      final quickAdd = find.byType(TextField).first;
      await tester.enterText(quickAdd, 'Buy milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pumpAsync(tester);
      expect(find.text('Buy milk'), findsOneWidget);

      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();
      expect(find.text('Task details'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(2), 'Buy oat milk');
      await tester.enterText(fields.at(3), 'For breakfast');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await _pumpAsync(tester);
      expect(find.text('Buy oat milk'), findsNWidgets(2));
      expect(find.text('For breakfast'), findsNWidgets(2));

      final addSubtask = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Add a subtask',
      );
      await tester.ensureVisible(addSubtask);
      await tester.enterText(addSubtask, 'Pick up package');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pumpAsync(tester);
      expect(find.text('Pick up package'), findsOneWidget);

      await tester.tap(find.text('Complete task'));
      await _pumpAsync(tester);
      expect(find.text('Restore task'), findsOneWidget);
      await tester.tap(find.text('Restore task'));
      await _pumpAsync(tester);
      expect(find.text('Complete task'), findsOneWidget);
    },
  );

  testWidgets('edits a local due date and recurrence', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyTaskUpApp(),
      ),
    );
    await _pumpAsync(tester);
    await tester.enterText(find.byType(TextField).first, 'Pay rent');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _pumpAsync(tester);
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

    await tester.ensureVisible(find.byTooltip('Choose due time'));
    await tester.tap(find.byTooltip('Choose due time'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == '9',
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

    final repeatField = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(repeatField);
    await tester.tap(repeatField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await _pumpAsync(tester);

    final task = (await TaskRepository(database).forList(ListId.inbox)).single;
    expect(
      task.due?.dayKey,
      tomorrow.year * 10000 + tomorrow.month * 100 + tomorrow.day,
    );
    expect(task.due?.minute, 637);
    expect(task.repeat, isA<DailyRepeat>());
  });
}

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
}
