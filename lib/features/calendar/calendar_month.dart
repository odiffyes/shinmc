import '../../core/local_date.dart';
import '../../domain/models/period_record.dart';
import '../../domain/services/interim_predictor.dart';

enum DayKind { none, actual, predicted }

/// Everything a day cell needs to render. Pure data, built by
/// [buildMonthGrid] so the layout rules are unit-testable.
class DayCellData {
  const DayCellData({
    required this.date,
    required this.inMonth,
    required this.isToday,
    this.kind = DayKind.none,
    this.isStart = false,
    this.isEnd = false,
    this.periodId,
    this.isPredictedStart = false,
  });

  final LocalDate date;
  final bool inMonth;
  final bool isToday;
  final DayKind kind;

  /// Actual start date (full pink cell + × button).
  final bool isStart;

  /// Actual recorded end date (× button clears the end).
  final bool isEnd;

  /// Actual period this day belongs to (for actual days only).
  final String? periodId;
  final bool isPredictedStart;
}

/// First day shown in the grid: the Sunday on or before the 1st.
LocalDate gridStart(int year, int month) {
  final first = LocalDate(year, month, 1);
  return first.addDays(-(first.weekday % 7)); // Sunday = 7 -> 0
}

/// Always 6 weeks (42 cells) so the grid never changes height (§11.1).
List<DayCellData> buildMonthGrid({
  required int year,
  required int month,
  required List<PeriodRecord> periods,
  required InterimPrediction prediction,
  required LocalDate today,
}) {
  final start = gridStart(year, month);
  return List.generate(42, (i) {
    final date = start.addDays(i);
    final inMonth = date.month == month;
    final isToday = date == today;

    for (final p in periods) {
      if (p.containsDate(date)) {
        return DayCellData(
          date: date,
          inMonth: inMonth,
          isToday: isToday,
          kind: DayKind.actual,
          isStart: date == p.startDate,
          isEnd: p.endDate != null && date == p.endDate,
          periodId: p.id,
        );
      }
    }
    final tail = prediction.openPeriodTail;
    if (tail != null && tail.contains(date)) {
      return DayCellData(
        date: date,
        inMonth: inMonth,
        isToday: isToday,
        kind: DayKind.predicted,
      );
    }
    for (final r in prediction.upcoming) {
      if (r.contains(date)) {
        return DayCellData(
          date: date,
          inMonth: inMonth,
          isToday: isToday,
          kind: DayKind.predicted,
          isPredictedStart: date == r.start,
        );
      }
    }
    return DayCellData(date: date, inMonth: inMonth, isToday: isToday);
  });
}
