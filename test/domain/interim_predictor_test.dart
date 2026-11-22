import 'package:flutter_test/flutter_test.dart';
import 'package:shinmc/domain/models/period_record.dart';
import 'package:shinmc/domain/services/interim_predictor.dart';

import '../helpers.dart';

final _t = DateTime.utc(2026);
PeriodRecord p(String start, [String? end]) => PeriodRecord(
  id: start,
  startDate: d(start),
  endDate: end == null ? null : d(end),
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  const predictor = InterimPredictor();

  test('no records -> no prediction', () {
    final r = predictor.predict(
      periods: [],
      cycleLength: 28,
      periodLength: 5,
      today: d('2026-11-22'),
    );
    expect(r.upcoming, isEmpty);
    expect(r.openPeriodTail, isNull);
  });

  test('next start = latest actual start + 28 (§7.2), ~3 months ahead', () {
    final r = predictor.predict(
      periods: [p('2026-05-20', '2026-05-24'), p('2026-06-17', '2026-06-21')],
      cycleLength: 28,
      periodLength: 5,
      today: d('2026-06-22'),
    );
    expect(r.upcoming.first, PredictedRange(d('2026-07-15'), d('2026-07-19')));
    expect(r.upcoming.map((x) => x.start.toIso()), [
      '2026-07-15',
      '2026-08-12',
      '2026-09-09',
    ]);
    expect(r.openPeriodTail, isNull);
  });

  test('open period gets a predicted tail until the end is entered', () {
    final r = predictor.predict(
      periods: [p('2026-11-20')],
      cycleLength: 28,
      periodLength: 5,
      today: d('2026-11-22'),
    );
    expect(r.openPeriodTail, PredictedRange(d('2026-11-21'), d('2026-11-24')));
  });

  test('overdue next start is still shown', () {
    final r = predictor.predict(
      periods: [p('2026-09-01', '2026-09-05')],
      cycleLength: 28,
      periodLength: 5,
      today: d('2026-11-22'),
    );
    expect(r.upcoming.first.start, d('2026-09-29'));
  });
}
