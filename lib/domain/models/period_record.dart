import '../../core/local_date.dart';

/// One actual (user-entered) period. Never created from a prediction.
class PeriodRecord {
  const PeriodRecord({
    required this.id,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final LocalDate startDate;

  /// Null means the actual end has not been entered yet (spec §8).
  final LocalDate? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasEnd => endDate != null;

  /// Inclusive length in days, or null if the end is not recorded.
  int? get lengthDays =>
      endDate == null ? null : startDate.daysUntil(endDate!) + 1;

  bool containsDate(LocalDate date) {
    if (date.isBefore(startDate)) return false;
    final end = endDate ?? startDate;
    return !date.isAfter(end);
  }

  PeriodRecord copyWith({
    LocalDate? startDate,
    LocalDate? endDate,
    bool clearEndDate = false,
    DateTime? updatedAt,
  }) => PeriodRecord(
    id: id,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'start_date': startDate.toIso(),
    'end_date': endDate?.toIso(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory PeriodRecord.fromRow(Map<String, Object?> row) => PeriodRecord(
    id: row['id']! as String,
    startDate: LocalDate.parse(row['start_date']! as String),
    endDate: row['end_date'] == null
        ? null
        : LocalDate.parse(row['end_date']! as String),
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  @override
  bool operator ==(Object other) =>
      other is PeriodRecord &&
      other.id == id &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(id, startDate, endDate);

  @override
  String toString() => 'PeriodRecord($id, $startDate..${endDate ?? '?'})';
}
