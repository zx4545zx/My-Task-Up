import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/app/app.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/domain/app_settings.dart';
import 'package:my_task_up/core/domain/ids.dart';
import 'package:my_task_up/core/domain/task.dart';
import 'package:my_task_up/core/database/database_provider.dart';
import 'package:my_task_up/features/lists/list_repository.dart';
import 'package:my_task_up/features/settings/settings_repository.dart';
import 'package:my_task_up/features/tasks/task_repository.dart';

void main() {
  testWidgets('navigation labels open their matching routes', (tester) async {
    await _pumpApp(tester, 390);

    expect(find.text('Inbox'), findsWidgets);
    await tester.tap(find.text('Today').first);
    await tester.pumpAndSettle();
    expect(find.text('No tasks due here.'), findsOneWidget);

    await tester.tap(find.text('Upcoming').first);
    await tester.pumpAndSettle();
    expect(find.text('No tasks due here.'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);

    await tester.tap(find.text('Inbox').first);
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsWidgets);
  });

  testWidgets('theme controls update the rendered theme mode', (tester) async {
    await _pumpApp(tester, 900);
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    for (final (label, brightness) in [
      ('Light', Brightness.light),
      ('Dark', Brightness.dark),
      ('System', null),
    ]) {
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, label),
      );
      expect(chip.selected, isTrue);
      if (brightness != null) {
        expect(
          Theme.of(
            tester.element(find.widgetWithText(ChoiceChip, label)),
          ).brightness,
          brightness,
        );
      }
    }
  });

  testWidgets('search finds task titles and notes across lists', (
    tester,
  ) async {
    final database = await _pumpApp(tester, 1400);
    final repository = TaskRepository(database);
    final task = await repository.create(title: 'Quarterly plan');
    await repository.edit(
      task.id,
      title: task.title.value,
      notes: 'needle in the notes',
      due: null,
      repeat: const NeverRepeat(),
    );
    final completed = await repository.create(title: 'Completed needle');
    await repository.complete(completed.id, at: DateTime.now());
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show completed tasks'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'needle');
    await tester.pumpAndSettle();

    expect(find.text('Quarterly plan'), findsOneWidget);
    expect(find.text('Completed needle'), findsNothing);

    await tester.tap(find.text('Quarterly plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Updated plan');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Updated plan'), findsOneWidget);
    expect(await repository.get(task.id), isNotNull);
  });

  testWidgets('settings persist default list, theme and completed visibility', (
    tester,
  ) async {
    final database = await _pumpApp(tester, 900);
    final work = await ListRepository(database).create('Work');
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ListId>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dark'));
    await tester.tap(find.text('Show completed tasks'));
    await tester.pumpAndSettle();

    final settings = await SettingsRepository(database).get();
    expect(settings.defaultListId, work.id);
    expect(settings.themeMode, AppThemeMode.dark);
    expect(settings.showCompleted, isFalse);

    await tester.tap(find.text('Inbox').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Default-list task');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Default-list task'), findsOneWidget);
    expect(
      (await TaskRepository(database).all()).any(
        (task) =>
            task.title.value == 'Default-list task' && task.listId == work.id,
      ),
      isTrue,
    );
  });

  for (final (width, layoutName) in [
    (390.0, 'mobile'),
    (900.0, 'compact'),
    (1400.0, 'desktop'),
  ]) {
    testWidgets('$layoutName navigation renders at $width pixels', (
      tester,
    ) async {
      await _pumpApp(tester, width);

      expect(find.text('My Task Up'), findsOneWidget);
      expect(find.text('Inbox'), findsWidgets);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Upcoming'), findsWidgets);
      if (width < 700) {
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.text('Task details'), findsNothing);
      } else if (width <= 1100) {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('Task details'), findsNothing);
      } else {
        expect(find.text('Task details'), findsOneWidget);
        expect(find.text('Select a task to see its details.'), findsOneWidget);
      }
    });
  }
}

Future<AppDatabase> _pumpApp(WidgetTester tester, double width) async {
  _setWidth(tester, width);
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const MyTaskUpApp(),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return database;
}

void _setWidth(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
}
