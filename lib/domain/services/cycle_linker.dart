import '../models/cycle_record.dart';
import '../models/period_record.dart';

/// Result of re-deriving cycle links from the current period list.
class CycleLinkResult {
  const CycleLinkResult({required this.upserts});

  /// Cycle rows that are new or whose fields changed.
  final List<CycleRecord> upserts;

  bool get isEmpty => upserts.isEmpty;
}

/// Derives the cycle (interval) structure from actual period records.
///
/// Rules (spec §5, §7.3, §7.4, §12):
/// * A cycle is the gap between two *consecutive* actual start dates.
/// * Each period owns the cycle that ends at its start date; settings
///   (`includeInPrediction`, `stress`) live on that cycle, keyed by period ID.
/// * Moving a start date without changing neighbour order only updates
///   lengths; all settings are kept.
/// * If a period's previous neighbour changes (because a record was
///   added, deleted, or moved past another), the interval is a different
///   one. `includeInPrediction` is reset to its default (ON) and
///   `needsReview` is set so the UI can tell the user. Stress is kept,
///   since it is a user observation and is never auto-changed (§6.4).
/// * Excluding a cycle never merges neighbouring records (§7.4); this
///   class only ever links actually-consecutive records.
class CycleLinker {
  const CycleLinker({required this.newId, required this.now});

  final String Function() newId;
  final DateTime Function() now;

  CycleLinkResult relink(
    List<PeriodRecord> periods,
    Map<String, CycleRecord> existingByPeriodId,
  ) {
    final sorted = [...periods]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final upserts = <CycleRecord>[];
    final timestamp = now();

    for (var i = 0; i < sorted.length; i++) {
      final period = sorted[i];
      final prev = i > 0 ? sorted[i - 1] : null;
      final length = prev?.startDate.daysUntil(period.startDate);
      final existing = existingByPeriodId[period.id];

      if (existing == null) {
        upserts.add(
          CycleRecord(
            id: newId(),
            periodId: period.id,
            previousPeriodId: prev?.id,
            lengthDays: length,
            updatedAt: timestamp,
          ),
        );
        continue;
      }

      CycleRecord next;
      if (existing.previousPeriodId == prev?.id) {
        // Same interval, possibly with moved dates.
        next = existing.copyWith(lengthDays: length);
      } else if (prev == null) {
        // Became the earliest record: no interval any more.
        next = existing.copyWith(
          clearPrevious: true,
          includeInPrediction: true,
          needsReview: false,
        );
      } else if (existing.previousPeriodId == null) {
        // Gained an interval (e.g. older history was added). There was no
        // user choice on the toggle before, so nothing to review.
        next = existing.copyWith(
          previousPeriodId: prev.id,
          lengthDays: length,
          includeInPrediction: true,
          needsReview: false,
        );
      } else {
        // Re-linked to a different previous period: different interval.
        next = existing.copyWith(
          previousPeriodId: prev.id,
          lengthDays: length,
          includeInPrediction: true,
          needsReview: true,
        );
      }

      if (next != existing) {
        upserts.add(next.copyWith(updatedAt: timestamp));
      }
    }
    return CycleLinkResult(upserts: upserts);
  }
}
