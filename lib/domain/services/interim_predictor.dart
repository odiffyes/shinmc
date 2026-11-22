import '../../core/local_date.dart';
import '../models/period_record.dart';

/// A predicted date range (inclusive). Display-only; never stored as or
/// mixed with actual records (spec §7.4).
class PredictedRange {
  const PredictedRange(this.start, this.end);
  final LocalDate start;
  final LocalDate end;

  bool contains(LocalDate d) => !d.isBefore(start) && !d.isAfter(end);

  @override
  bool operator ==(Object other) =>
      other is PredictedRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PredictedRange($start..$end)';
}

class InterimPrediction {
  const InterimPrediction({required this.upcoming, this.openPeriodTail});

  /// Future predicted periods, earliest first. upcoming.first is the
  /// "다음 예상 시작일".
  final List<PredictedRange> upcoming;

  /// For the latest actual period with no end yet: the remaining days
  /// expected until it ends (shown as predicted, replaced by the actual end
  /// once entered — spec §8).
  final PredictedRange? openPeriodTail;

  static const empty = InterimPrediction(upcoming: []);
}

/// TEMPORARY stage-2 predictor (user-approved option A): uses the user's
/// default cycle length (28 by default) and default period length, based on
/// the latest actual start (§7.2). Replaced by the stage-4 engine, which
/// averages all cycles that are included in prediction (§7.1).
class InterimPredictor {
  const InterimPredictor();

  InterimPrediction predict({
    required List<PeriodRecord> periods,
    required int cycleLength,
    required int periodLength,
    required LocalDate today,
    int horizonDays = 92, // ~3 months (§9.3)
  }) {
    if (periods.isEmpty || cycleLength < 1) return InterimPrediction.empty;
    final latest = periods.reduce(
      (a, b) => a.startDate.isAfter(b.startDate) ? a : b,
    );
    final len = periodLength < 1 ? 1 : periodLength;

    PredictedRange? tail;
    if (latest.endDate == null && len > 1) {
      tail = PredictedRange(
        latest.startDate.addDays(1),
        latest.startDate.addDays(len - 1),
      );
    }

    final horizon = today.addDays(horizonDays);
    final upcoming = <PredictedRange>[];
    var start = latest.startDate.addDays(cycleLength);
    // Always include the next one, even if it is already overdue.
    do {
      upcoming.add(PredictedRange(start, start.addDays(len - 1)));
      start = start.addDays(cycleLength);
    } while (!start.isAfter(horizon));

    return InterimPrediction(upcoming: upcoming, openPeriodTail: tail);
  }
}
