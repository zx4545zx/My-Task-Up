import 'dart:convert';

import '../domain/task.dart';

String encodeRepeatRule(RepeatRule rule) => jsonEncode(switch (rule) {
  NeverRepeat() => {'type': 'never'},
  DailyRepeat() => {'type': 'daily'},
  WeekdaysRepeat() => {'type': 'weekdays'},
  WeeklyRepeat() => {'type': 'weekly'},
  MonthlyRepeat() => {'type': 'monthly'},
  YearlyRepeat() => {'type': 'yearly'},
  CustomRepeat(:final interval, :final every, :final weekdays) => {
    'type': 'custom',
    'interval': interval.name,
    'every': every,
    'weekdays': weekdays.map((day) => day.name).toList()..sort(),
  },
});

RepeatRule decodeRepeatRule(String encoded) {
  final value = jsonDecode(encoded);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid stored repeat rule.');
  }
  return switch (value['type']) {
    'never' => const NeverRepeat(),
    'daily' => const DailyRepeat(),
    'weekdays' => const WeekdaysRepeat(),
    'weekly' => const WeeklyRepeat(),
    'monthly' => const MonthlyRepeat(),
    'yearly' => const YearlyRepeat(),
    'custom' => CustomRepeat(
      interval: RepeatInterval.values.byName(value['interval'] as String),
      every: value['every'] as int,
      weekdays: (value['weekdays'] as List<dynamic>)
          .map((day) => Weekday.values.byName(day as String))
          .toSet(),
    ),
    _ => throw const FormatException('Unknown stored repeat rule.'),
  };
}
