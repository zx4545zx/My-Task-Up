import 'dart:convert';

import '../domain/task.dart';

String encodeRepeatRule(RepeatRule rule) => jsonEncode(switch (rule) {
  NeverRepeat() => {'type': 'never'},
  DailyRepeat() => {'type': 'daily'},
  WeekdaysRepeat() => {'type': 'weekdays'},
  WeeklyRepeat() => {'type': 'weekly'},
  MonthlyRepeat(:final anchorDayKey) => {
    'type': 'monthly',
    'anchorDayKey': anchorDayKey,
  },
  YearlyRepeat(:final anchorDayKey) => {
    'type': 'yearly',
    'anchorDayKey': anchorDayKey,
  },
  CustomRepeat(
    :final interval,
    :final every,
    :final weekdays,
    :final anchorDayKey,
  ) =>
    {
      'type': 'custom',
      'interval': interval.name,
      'every': every,
      'weekdays': weekdays.map((day) => day.name).toList()..sort(),
      'anchorDayKey': anchorDayKey,
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
    'monthly' => MonthlyRepeat(anchorDayKey: _decodeAnchorDayKey(value)),
    'yearly' => YearlyRepeat(anchorDayKey: _decodeAnchorDayKey(value)),
    'custom' => CustomRepeat(
      interval: RepeatInterval.values.byName(value['interval'] as String),
      every: value['every'] as int,
      weekdays: (value['weekdays'] as List<dynamic>)
          .map((day) => Weekday.values.byName(day as String))
          .toSet(),
      anchorDayKey: _decodeAnchorDayKey(value),
    ),
    _ => throw const FormatException('Unknown stored repeat rule.'),
  };
}

int? _decodeAnchorDayKey(Map<String, dynamic> value) {
  final anchor = value['anchorDayKey'];
  if (anchor == null) return null;
  if (anchor is! int) {
    throw const FormatException('Invalid recurrence anchor.');
  }
  try {
    LocalDue.fromDayKey(anchor);
  } on ArgumentError {
    throw const FormatException('Invalid recurrence anchor.');
  }
  return anchor;
}
