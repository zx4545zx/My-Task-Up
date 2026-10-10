import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/app/app.dart';

void main() {
  testWidgets('navigation labels open their matching routes', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(const ProviderScope(child: MyTaskUpApp()));

    expect(find.text('Your inbox is ready.'), findsOneWidget);
    await tester.tap(find.text('Today').first);
    await tester.pumpAndSettle();
    expect(find.text('Tasks due today will appear here.'), findsOneWidget);

    await tester.tap(find.text('Upcoming').first);
    await tester.pumpAndSettle();
    expect(find.text('Upcoming tasks will appear here.'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Theme mode: System'), findsOneWidget);

    await tester.tap(find.text('Inbox').first);
    await tester.pumpAndSettle();
    expect(find.text('Your inbox is ready.'), findsOneWidget);
  });

  testWidgets('theme controls update the rendered theme mode', (tester) async {
    _setWidth(tester, 900);
    await tester.pumpWidget(const ProviderScope(child: MyTaskUpApp()));
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    for (final (label, brightness) in [
      ('Light', Brightness.light),
      ('Dark', Brightness.dark),
      ('System', null),
    ]) {
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
      expect(find.text('Theme mode: $label'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, label),
      );
      expect(chip.selected, isTrue);
      if (brightness != null) {
        expect(
          Theme.of(tester.element(find.text('Theme mode: $label'))).brightness,
          brightness,
        );
      }
    }
  });

  for (final (width, layoutName) in [
    (390.0, 'mobile'),
    (900.0, 'compact'),
    (1400.0, 'desktop'),
  ]) {
    testWidgets('$layoutName navigation renders at $width pixels', (
      tester,
    ) async {
      _setWidth(tester, width);
      await tester.pumpWidget(const ProviderScope(child: MyTaskUpApp()));

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

void _setWidth(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
}
