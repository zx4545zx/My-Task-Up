import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Theme mode: ${_label(mode)}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final option in ThemeMode.values)
                  ChoiceChip(
                    label: Text(_label(option)),
                    selected: mode == option,
                    onSelected: (_) =>
                        ref.read(themeModeProvider.notifier).select(option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}
