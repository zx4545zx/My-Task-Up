import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('desktop shortcuts save tasks without changing completion', (
    tester,
  ) async {
    final database = await _pumpApp(tester, 1400);
    final tasks = TaskRepository(database);
    final quickAdd = find.byType(TextField).first;
    await tester.enterText(quickAdd, 'typed normally');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsNothing);
    expect(
      tester.widget<TextField>(quickAdd).controller!.text,
      'typed normally',
    );

    await _sendShortcut(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyN,
    );
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Shortcut task');
    await _sendShortcut(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.enter,
    );
    await tester.pumpAndSettle();
    expect(await tasks.search('Shortcut task'), hasLength(1));

    await _sendShortcut(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyN,
    );
    await tester.pumpAndSettle();
    await _sendShortcut(tester, LogicalKeyboardKey.escape, null);
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsNothing);
    expect(await tasks.all(), hasLength(1));

    var task = (await tasks.all()).singleWhere(
      (item) => item.title.value == 'Shortcut task',
    );
    expect(task.isCompleted, isFalse);

    await tester.tap(find.text('Shortcut task').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'Saved by shortcut',
    );
    await _sendShortcut(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.enter,
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    task = (await tasks.all()).singleWhere((item) => item.id == task.id);
    expect(task.title.value, 'Saved by shortcut');
    expect(task.isCompleted, isFalse);

    await _sendShortcut(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    await tester.pumpAndSettle();
    expect(find.text('Search tasks and notes'), findsOneWidget);
  });

  testWidgets('desktop list actions reorder custom lists', (tester) async {
    final database = await _pumpApp(tester, 1400);
    final repository = ListRepository(database);

    Future<void> addList(String name) async {
      await tester.tap(find.text('Add list').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, name);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    await addList('Alpha');
    await addList('Beta');
    final lists = (await repository.all())
        .where((list) => !list.isInbox)
        .toList();
    expect(lists.map((list) => list.name), ['Alpha', 'Beta']);

    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    await tester.tap(find.byTooltip('List actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();

    expect(
      (await repository.all())
          .where((list) => !list.isInbox)
          .map((list) => list.name),
      ['Beta', 'Alpha'],
    );
  });

  testWidgets('pointer drag moves a root task and its subtasks to a list', (
    tester,
  ) async {
    _setWidth(tester, 1400);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final later = await ListRepository(database).create('Later');
    final tasks = TaskRepository(database);
    final parent = await tasks.create(title: 'Move this group');
    final child = await tasks.createSubtask(parent.id, 'Keep this subtask');
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

    final source = tester.getCenter(find.byTooltip('Move task to list'));
    final target = tester.getCenter(find.text('Later'));
    final gesture = await tester.startGesture(source);
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect((await tasks.get(parent.id))!.listId, later.id);
    expect((await tasks.get(child.id))!.listId, later.id);
    expect((await tasks.get(child.id))!.parentId, parent.id);
  });

  testWidgets('task action menu can duplicate a task', (tester) async {
    final database = await _pumpApp(tester, 1400);
    final tasks = TaskRepository(database);
    await tester.enterText(find.byType(TextField).first, 'Menu task');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Task actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(
      (await tasks.all()).where((task) => task.title.value == 'Menu task'),
      hasLength(2),
    );
  });

  testWidgets('Delete shortcut asks before deleting a selected task', (
    tester,
  ) async {
    final database = await _pumpApp(tester, 1400);
    final tasks = TaskRepository(database);
    await tester.enterText(find.byType(TextField).first, 'Delete by shortcut');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final task = (await tasks.all()).singleWhere(
      (item) => item.title.value == 'Delete by shortcut',
    );
    await tester.tap(find.text('Delete by shortcut').last);
    FocusManager.instance.primaryFocus?.unfocus();
    await _sendShortcut(tester, LogicalKeyboardKey.delete, null);
    await tester.pumpAndSettle();
    expect(find.text('Delete task?'), findsOneWidget);
    expect(await tasks.get(task.id), isNotNull);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(await tasks.get(task.id), isNull);
  });

  testWidgets('delete all data requires confirmation', (tester) async {
    final database = await _pumpApp(tester, 900);
    final tasks = TaskRepository(database);
    final task = await tasks.create(title: 'Keep until confirmed');
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);

    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await tasks.get(task.id), isNotNull);

    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all').last);
    await tester.pumpAndSettle();
    expect(await tasks.all(), isEmpty);
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

Future<void> _sendShortcut(
  WidgetTester tester,
  LogicalKeyboardKey first,
  LogicalKeyboardKey? second,
) async {
  if (second == null) {
    await tester.sendKeyEvent(first);
    return;
  }
  await tester.sendKeyDownEvent(first);
  await tester.sendKeyDownEvent(second);
  await tester.sendKeyUpEvent(second);
  await tester.sendKeyUpEvent(first);
}

void _setWidth(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
}
