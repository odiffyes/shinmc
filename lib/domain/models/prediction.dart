import '../../core/local_date.dart';

/// A predicted future period. Never used as training data (§7.4).
class Prediction {
  const Prediction({
    required this.id,
    required this.sequence,
    required this.startDate,
    required this.endDate,
    required this.dataVersion,
    required this.generatedAt,
  });

  final String id;

  /// 1 = next predicted period, 2 = the one after, ...
  final int sequence;
  final LocalDate startDate;
  final LocalDate endDate;

  /// The `data_version` of the records this prediction was computed from.
  final int dataVersion;
  final DateTime generatedAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'sequence': sequence,
    'start_date': startDate.toIso(),
    'end_date': endDate.toIso(),
    'data_version': dataVersion,
    'generated_at': generatedAt.toUtc().toIso8601String(),
  };

  factory Prediction.fromRow(Map<String, Object?> row) => Prediction(
    id: row['id']! as String,
    sequence: row['sequence']! as int,
    startDate: LocalDate.parse(row['start_date']! as String),
    endDate: LocalDate.parse(row['end_date']! as String),
    dataVersion: row['data_version']! as int,
    generatedAt: DateTime.parse(row['generated_at']! as String),
  );
}
