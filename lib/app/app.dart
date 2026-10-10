import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/app_settings.dart';
import '../features/settings/settings_providers.dart';
import 'router.dart';

class MyTaskUpApp extends ConsumerWidget {
  const MyTaskUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final themeMode = switch (settings?.themeMode ?? AppThemeMode.system) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
    return MaterialApp.router(
      title: 'My Task Up',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF445D9C),
      brightness: brightness,
    ),
  );
}
