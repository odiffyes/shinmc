import 'stress_level.dart';

/// The cycle that *ends* at [periodId]'s start date (spec §5.2).
///
/// There is exactly one CycleRecord per PeriodRecord. For the earliest
/// period there is no previous start, so [previousPeriodId] and
/// [lengthDays] are null and the prediction toggle is disabled (§6.2).
///
/// Links are by record ID, never by date string (§12).
class CycleRecord {
  const CycleRecord({
    required this.id,
    required this.periodId,
    this.previousPeriodId,
    this.lengthDays,
    this.includeInPrediction = true,
    this.stress = StressLevel.unrecorded,
    this.needsReview = false,
    required this.updatedAt,
  });

  final String id;
  final String periodId;
  final String? previousPeriodId;
  final int? lengthDays;
  final bool includeInPrediction;
  final StressLevel stress;

  /// Set when an edit/delete re-linked this cycle to a different previous
  /// period. The old `includeInPrediction` choice described a different
  /// interval, so it was reset to the default and the UI should surface it.
  final bool needsReview;
  final DateTime updatedAt;

  /// Whether the "include in prediction" toggle can be used.
  bool get hasInterval => previousPeriodId != null && lengthDays != null;

  /// Whether this interval feeds the average-cycle calculation (§7.1).
  bool get countsForPrediction => hasInterval && includeInPrediction;

  CycleRecord copyWith({
    String? previousPeriodId,
    bool clearPrevious = false,
    int? lengthDays,
    bool? includeInPrediction,
    StressLevel? stress,
    bool? needsReview,
    DateTime? updatedAt,
  }) => CycleRecord(
    id: id,
    periodId: periodId,
    previousPeriodId: clearPrevious
        ? null
        : (previousPeriodId ?? this.previousPeriodId),
    lengthDays: clearPrevious ? null : (lengthDays ?? this.lengthDays),
    includeInPrediction: includeInPrediction ?? this.includeInPrediction,
    stress: stress ?? this.stress,
    needsReview: needsReview ?? this.needsReview,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'period_id': periodId,
    'previous_period_id': previousPeriodId,
    'length_days': lengthDays,
    'include_in_prediction': includeInPrediction ? 1 : 0,
    'stress': stress.dbValue,
    'needs_review': needsReview ? 1 : 0,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory CycleRecord.fromRow(Map<String, Object?> row) => CycleRecord(
    id: row['id']! as String,
    periodId: row['period_id']! as String,
    previousPeriodId: row['previous_period_id'] as String?,
    lengthDays: row['length_days'] as int?,
    includeInPrediction: (row['include_in_prediction']! as int) == 1,
    stress: StressLevel.fromDb(row['stress'] as String?),
    needsReview: (row['needs_review']! as int) == 1,
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  @override
  bool operator ==(Object other) =>
      other is CycleRecord &&
      other.id == id &&
      other.periodId == periodId &&
      other.previousPeriodId == previousPeriodId &&
      other.lengthDays == lengthDays &&
      other.includeInPrediction == includeInPrediction &&
      other.stress == stress &&
      other.needsReview == needsReview;

  @override
  int get hashCode => Object.hash(
    id,
    periodId,
    previousPeriodId,
    lengthDays,
    includeInPrediction,
    stress,
    needsReview,
  );

  @override
  String toString() =>
      'CycleRecord(period=$periodId prev=$previousPeriodId '
      'len=$lengthDays include=$includeInPrediction stress=${stress.name} '
      'review=$needsReview)';
}
