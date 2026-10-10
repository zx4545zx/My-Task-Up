import 'package:flutter_test/flutter_test.dart';
import 'package:my_task_up/core/database/repeat_rule_codec.dart';
import 'package:my_task_up/core/domain/recurrence.dart';
import 'package:my_task_up/core/domain/task.dart';

void main() {
  test('calculates built-in recurrence across calendar boundaries', () {
    final cases = <(LocalDue, RepeatRule, LocalDue)>[
      (
        LocalDue(year: 2026, month: 12, day: 31, minute: 1439),
        const DailyRepeat(),
        LocalDue(year: 2027, month: 1, day: 1, minute: 1439),
      ),
      (
        LocalDue(year: 2026, month: 10, day: 9),
        const WeekdaysRepeat(),
        LocalDue(year: 2026, month: 10, day: 12),
      ),
      (
        LocalDue(year: 2026, month: 12, day: 29),
        const WeeklyRepeat(),
        LocalDue(year: 2027, month: 1, day: 5),
      ),
      (
        LocalDue(year: 2026, month: 1, day: 31),
        const MonthlyRepeat(),
        LocalDue(year: 2026, month: 2, day: 28),
      ),
      (
        LocalDue(year: 2024, month: 2, day: 29),
        const YearlyRepeat(),
        LocalDue(year: 2025, month: 2, day: 28),
      ),
      (
        LocalDue(year: 2026, month: 12, day: 30),
        CustomRepeat(interval: RepeatInterval.days, every: 3),
        LocalDue(year: 2027, month: 1, day: 2),
      ),
      (
        LocalDue(year: 2026, month: 12, day: 28),
        CustomRepeat(interval: RepeatInterval.weeks, every: 2),
        LocalDue(year: 2027, month: 1, day: 11),
      ),
    ];

    for (final (due, repeat, expected) in cases) {
      final next = nextDue(due, repeat);
      expect(next?.dayKey, expected.dayKey, reason: '$repeat from $due');
      expect(next?.minute, expected.minute);
    }
    expect(nextDue(cases.first.$1, const NeverRepeat()), isNull);
  });

  test('month-end and leap-day recurrences keep their original anchors', () {
    expect(
      nextDue(
        LocalDue(year: 2026, month: 2, day: 28),
        const MonthlyRepeat(anchorDayKey: 20260131),
      )?.dayKey,
      20260331,
    );
    expect(
      nextDue(
        LocalDue(year: 2025, month: 2, day: 28),
        const YearlyRepeat(anchorDayKey: 20240229),
      )?.dayKey,
      20260228,
    );
    expect(
      nextDue(
        LocalDue(year: 2027, month: 2, day: 28),
        const YearlyRepeat(anchorDayKey: 20240229),
      )?.dayKey,
      20280229,
    );
  });

  test('custom weekly weekdays stay anchored to their original interval', () {
    final repeat = CustomRepeat(
      interval: RepeatInterval.weeks,
      every: 2,
      weekdays: {Weekday.monday, Weekday.wednesday},
      anchorDayKey: 20261005,
    );

    final first = nextDue(LocalDue(year: 2026, month: 10, day: 5), repeat);
    expect(first?.dayKey, 20261007);
    expect(nextDue(first!, repeat)?.dayKey, 20261019);
    expect(
      nextDue(LocalDue(year: 2026, month: 10, day: 19), repeat)?.dayKey,
      20261021,
    );
  });

  test('repeat codec retains calendar recurrence anchors', () {
    expect(
      (decodeRepeatRule(
                encodeRepeatRule(const MonthlyRepeat(anchorDayKey: 20260131)),
              )
              as MonthlyRepeat)
          .anchorDayKey,
      20260131,
    );
    expect(
      (decodeRepeatRule(
                encodeRepeatRule(const YearlyRepeat(anchorDayKey: 20240229)),
              )
              as YearlyRepeat)
          .anchorDayKey,
      20240229,
    );
  });

  test('custom repeat intervals stay within the supported calendar range', () {
    expect(
      () => CustomRepeat(interval: RepeatInterval.days, every: 0),
      throwsArgumentError,
    );
    expect(
      () => CustomRepeat(interval: RepeatInterval.weeks, every: 10000),
      throwsArgumentError,
    );
  });

  test('repeat codec retains custom interval anchors', () {
    final repeat = CustomRepeat(
      interval: RepeatInterval.weeks,
      every: 2,
      weekdays: {Weekday.monday, Weekday.friday},
      anchorDayKey: 20261005,
    );
    final decoded = decodeRepeatRule(encodeRepeatRule(repeat)) as CustomRepeat;

    expect(decoded.interval, RepeatInterval.weeks);
    expect(decoded.every, 2);
    expect(decoded.weekdays, {Weekday.monday, Weekday.friday});
    expect(decoded.anchorDayKey, 20261005);
  });
}
