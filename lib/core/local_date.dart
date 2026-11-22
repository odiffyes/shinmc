/// A calendar date with no time or time zone.
///
/// Period data is date-based ("the period started on June 1"), so using
/// [DateTime] directly invites daylight-saving and time-zone bugs. All date
/// math in the app goes through this type. Stored as `YYYY-MM-DD` text.
class LocalDate implements Comparable<LocalDate> {
  LocalDate(int year, int month, int day)
    : _utc = DateTime.utc(year, month, day) {
    if (_utc.year != year || _utc.month != month || _utc.day != day) {
      throw ArgumentError('Invalid date: $year-$month-$day');
    }
  }

  LocalDate._(this._utc);

  /// Today's date on the device clock.
  factory LocalDate.today() => LocalDate.fromDateTime(DateTime.now());

  factory LocalDate.fromDateTime(DateTime dt) =>
      LocalDate._(DateTime.utc(dt.year, dt.month, dt.day));

  /// Parses `YYYY-MM-DD`. Throws [FormatException] on anything else.
  factory LocalDate.parse(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (m == null) throw FormatException('Expected YYYY-MM-DD', iso);
    try {
      return LocalDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    } on ArgumentError {
      throw FormatException('Invalid calendar date', iso);
    }
  }

  final DateTime _utc;

  int get year => _utc.year;
  int get month => _utc.month;
  int get day => _utc.day;

  /// 1 = Monday ... 7 = Sunday.
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) =>
      LocalDate._(DateTime.utc(year, month, day + days));

  /// Whole days from this date to [other] (positive if [other] is later).
  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => _utc.compareTo(other._utc);

  @override
  bool operator ==(Object other) => other is LocalDate && other._utc == _utc;

  @override
  int get hashCode => _utc.hashCode;

  @override
  String toString() => toIso();
}
