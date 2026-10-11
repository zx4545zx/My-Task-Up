import 'ids.dart';

final class TaskTitle {
  TaskTitle(String value) : value = value.trim() {
    if (this.value.isEmpty) throw ArgumentError.value(value, 'value');
  }

  final String value;
}

final class LocalDue {
  LocalDue({
    required this.year,
    required this.month,
    required this.day,
    this.minute,
  }) {
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError.value('$year-$month-$day', 'date');
    }
    if (minute != null && (minute! < 0 || minute! > 1439)) {
      throw ArgumentError.value(minute, 'minute');
    }
  }

  final int year;
  final int month;
  final int day;
  final int? minute;

  factory LocalDue.fromDayKey(int dayKey) => LocalDue(
    year: dayKey ~/ 10000,
    month: (dayKey ~/ 100) % 100,
    day: dayKey % 100,
  );

  int get dayKey => year * 10000 + month * 100 + day;
}

enum RepeatInterval { days, weeks }

enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

sealed class RepeatRule {
  const RepeatRule();
}

final class NeverRepeat extends RepeatRule {
  const NeverRepeat();
}

final class DailyRepeat extends RepeatRule {
  const DailyRepeat();
}

final class WeekdaysRepeat extends RepeatRule {
  const WeekdaysRepeat();
}

final class WeeklyRepeat extends RepeatRule {
  const WeeklyRepeat();
}

final class MonthlyRepeat extends RepeatRule {
  const MonthlyRepeat({this.anchorDayKey});

  final int? anchorDayKey;
}

final class YearlyRepeat extends RepeatRule {
  const YearlyRepeat({this.anchorDayKey});

  final int? anchorDayKey;
}

final class CustomRepeat extends RepeatRule {
  CustomRepeat({
    required this.interval,
    required this.every,
    this.weekdays = const {},
    this.anchorDayKey,
  }) {
    if (every < 1 || every > 9999) {
      throw ArgumentError.value(every, 'every');
    }
    if (weekdays.isNotEmpty && interval != RepeatInterval.weeks) {
      throw ArgumentError.value(weekdays, 'weekdays');
    }
    if (anchorDayKey case final dayKey?) {
      if (interval != RepeatInterval.weeks || weekdays.isEmpty) {
        throw ArgumentError.value(dayKey, 'anchorDayKey');
      }
      LocalDue.fromDayKey(dayKey);
    }
  }

  final RepeatInterval interval;
  final int every;
  final Set<Weekday> weekdays;
  final int? anchorDayKey;
}

final class Task {
  Task({
    required this.id,
    required this.listId,
    required this.title,
    required this.repeat,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.recurrenceSeriesId,
    this.nextOccurrenceId,
    this.notes,
    this.due,
    this.completedAt,
  }) {
    if (position < 0) throw ArgumentError.value(position, 'position');
  }

  final TaskId id;
  final ListId listId;
  final TaskId? parentId;
  final TaskId? recurrenceSeriesId;
  final TaskId? nextOccurrenceId;
  final TaskTitle title;
  final String? notes;
  final LocalDue? due;
  final RepeatRule repeat;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;
}
