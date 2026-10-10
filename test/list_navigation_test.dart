import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/app/app.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/database/database_provider.dart';
import 'package:my_task_up/core/domain/ids.dart';
import 'package:my_task_up/features/lists/list_repository.dart';

void main() {
  testWidgets('creates, renames, reorders, and deletes a custom list', (
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

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Errands');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Errands'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('List actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Personal');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsNWidgets(2));
    expect(find.text('Errands'), findsNothing);

    await tester.tap(find.text('Add list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Work');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final customLists = (await ListRepository(
      database,
    ).all()).where((list) => !list.isInbox).toList();
    expect(customLists.map((list) => list.name), ['Personal', 'Work']);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('List actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await _pumpAsync(tester);
    expect(
      (await ListRepository(
        database,
      ).all()).where((list) => !list.isInbox).map((list) => list.name),
      ['Work', 'Personal'],
    );

    await tester.tap(find.byTooltip('List actions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move tasks to Inbox'));
    await _pumpAsync(tester);
    expect(
      await ListRepository(
        database,
      ).get(ListId.parse(customLists.first.id.value)),
      isNull,
    );
  });
}

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
}
