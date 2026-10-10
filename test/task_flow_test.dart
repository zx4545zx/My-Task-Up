import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/app/app.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/database/database_provider.dart';

void main() {
  testWidgets('quick add, edit details, complete and restore a task', (
    tester,
  ) async {
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
    await tester.enterText(fields.at(1), 'Buy oat milk');
    await tester.enterText(fields.at(2), 'For breakfast');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await _pumpAsync(tester);
    expect(find.text('Buy oat milk'), findsNWidgets(2));
    expect(find.text('For breakfast'), findsNWidgets(2));

    await tester.tap(find.text('Complete task'));
    await _pumpAsync(tester);
    expect(find.text('Restore task'), findsOneWidget);
    await tester.tap(find.text('Restore task'));
    await _pumpAsync(tester);
    expect(find.text('Complete task'), findsOneWidget);
  });
}

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
}
