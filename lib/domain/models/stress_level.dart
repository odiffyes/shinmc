/// Per-cycle stress note. Deliberately not a score: three emoji plus
/// "not recorded". Independent from `includeInPrediction` (spec §6.4).
enum StressLevel {
  unrecorded('unrecorded', ''),
  calm('calm', '😊'),
  neutral('neutral', '😐'),
  high('high', '😣');

  const StressLevel(this.dbValue, this.emoji);

  final String dbValue;
  final String emoji;

  static StressLevel fromDb(String? value) => StressLevel.values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => StressLevel.unrecorded,
  );
}
