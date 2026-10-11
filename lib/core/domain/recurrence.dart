import 'task.dart';

LocalDue? nextDue(LocalDue due, RepeatRule repeat, {int? anchorDayKey}) {
  final current = DateTime.utc(due.year, due.month, due.day);
  final next = switch (repeat) {
    NeverRepeat() => null,
    DailyRepeat() => current.add(const Duration(days: 1)),
    WeekdaysRepeat() => _nextWeekday(current),
    WeeklyRepeat() => current.add(const Duration(days: 7)),
    MonthlyRepeat(:final anchorDayKey) => _nextMonth(
      current,
      LocalDue.fromDayKey(anchorDayKey ?? due.dayKey).day,
    ),
    YearlyRepeat(:final anchorDayKey) => _nextYear(
      current,
      LocalDue.fromDayKey(anchorDayKey ?? due.dayKey),
    ),
    CustomRepeat(interval: RepeatInterval.days, :final every) => current.add(
      Duration(days: every),
    ),
    CustomRepeat(
      interval: RepeatInterval.weeks,
      :final every,
      weekdays: final weekdays,
    ) =>
      weekdays.isEmpty
          ? current.add(Duration(days: every * 7))
          : _nextCustomWeekday(
              current,
              weekdays,
              every,
              repeat.anchorDayKey ?? anchorDayKey ?? due.dayKey,
            ),
  };
  if (next == null) return null;
  return LocalDue(
    year: next.year,
    month: next.month,
    day: next.day,
    minute: due.minute,
  );
}

DateTime _nextWeekday(DateTime current) {
  var next = current.add(const Duration(days: 1));
  while (next.weekday == DateTime.saturday || next.weekday == DateTime.sunday) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}

DateTime _nextMonth(DateTime current, int anchorDay) {
  var year = current.year;
  var month = current.month;
  var candidate = _clampedDate(year, month, anchorDay);
  if (!candidate.isAfter(current)) {
    if (month == 12) {
      year++;
      month = 1;
    } else {
      month++;
    }
    candidate = _clampedDate(year, month, anchorDay);
  }
  return candidate;
}

DateTime _nextYear(DateTime current, LocalDue anchor) {
  var year = current.year;
  var candidate = _clampedDate(year, anchor.month, anchor.day);
  if (!candidate.isAfter(current)) {
    year++;
    candidate = _clampedDate(year, anchor.month, anchor.day);
  }
  return candidate;
}

DateTime _clampedDate(int year, int month, int day) => DateTime.utc(
  year,
  month,
  day.clamp(1, DateTime.utc(year, month + 1, 0).day).toInt(),
);

DateTime _nextCustomWeekday(
  DateTime current,
  Set<Weekday> weekdays,
  int every,
  int anchorDayKey,
) {
  final anchor = LocalDue.fromDayKey(anchorDayKey);
  final anchorDate = DateTime.utc(anchor.year, anchor.month, anchor.day);
  final anchorWeek = anchorDate.subtract(
    Duration(days: anchorDate.weekday - 1),
  );
  final currentWeek = current.subtract(Duration(days: current.weekday - 1));
  final weekIndex = currentWeek.difference(anchorWeek).inDays ~/ 7;
  final selectedDays = weekdays.map((day) => day.index + 1).toList()..sort();

  if (weekIndex >= 0 && weekIndex % every == 0) {
    for (final day in selectedDays) {
      final candidate = currentWeek.add(Duration(days: day - 1));
      if (candidate.isAfter(current)) return candidate;
    }
  }

  final nextWeekIndex = weekIndex < 0
      ? 0
      : weekIndex + (every - weekIndex % every);
  final nextWeek = anchorWeek.add(Duration(days: nextWeekIndex * 7));
  return nextWeek.add(Duration(days: selectedDays.first - 1));
}
