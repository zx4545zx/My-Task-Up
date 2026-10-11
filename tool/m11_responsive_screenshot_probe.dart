import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:my_task_up/app/app.dart';
import 'package:my_task_up/core/database/app_database.dart';
import 'package:my_task_up/core/database/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(390, 900),
      minimumSize: Size(320, 600),
      center: true,
      title: 'My Task Up',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(
          AppDatabase.forTesting(NativeDatabase.memory()),
        ),
      ],
      child: const MyTaskUpApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_resizeForScreenshots());
  });
}

Future<void> _resizeForScreenshots() async {
  for (final width in [390.0, 900.0, 1400.0]) {
    await windowManager.setSize(Size(width, 900));
    await windowManager.center();
    debugPrint('M11_SCREENSHOT_WIDTH=${width.toInt()}');
    await Future<void>.delayed(const Duration(seconds: 4));
  }
}
