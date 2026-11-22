import 'package:flutter_test/flutter_test.dart';
import 'package:shinmc/domain/models/period_record.dart';
import 'package:shinmc/domain/services/interim_predictor.dart';
import 'package:shinmc/features/calendar/calendar_month.dart';

import '../helpers.dart';

final _t = DateTime.utc(2026);

void main() {
  test('grid starts on Sunday and always has 42 cells', () {
    // 2026-11-01 is a Sunday; 2026-12-01 is a Tuesday.
    expect(gridStart(2026, 11), d('2026-11-01'));
    expect(gridStart(2026, 12), d('2026-11-29'));
    final cells = buildMonthGrid(
      year: 2026,
      month: 12,
      periods: const [],
      prediction: InterimPrediction.empty,
      today: d('2026-12-15'),
    );
    expect(cells, hasLength(42));
    expect(cells.first.inMonth, isFalse);
    expect(cells.where((c) => c.isToday).single.date, d('2026-12-15'));
  });

  test('#3 period across months marks start, middle and end', () {
    final period = PeriodRecord(
      id: 'a',
      startDate: d('2026-11-29'),
      endDate: d('2026-12-02'),
      createdAt: _t,
      updatedAt: _t,
    );
    final cells = buildMonthGrid(
      year: 2026,
      month: 12,
      periods: [period],
      prediction: InterimPrediction.empty,
      today: d('2026-12-15'),
    );
    DayCellData at(String iso) => cells.firstWhere((c) => c.date == d(iso));
    expect(at('2026-11-29').isStart, isTrue);
    expect(at('2026-11-29').inMonth, isFalse);
    expect(at('2026-12-01').kind, DayKind.actual);
    expect(at('2026-12-01').isStart, isFalse);
    expect(at('2026-12-02').isEnd, isTrue);
    expect(at('2026-12-03').kind, DayKind.none);
  });

  test('actual always wins over predicted on the same day', () {
    final period = PeriodRecord(
      id: 'a',
      startDate: d('2026-12-10'),
      createdAt: _t,
      updatedAt: _t,
    );
    final cells = buildMonthGrid(
      year: 2026,
      month: 12,
      periods: [period],
      prediction: InterimPrediction(
        upcoming: [PredictedRange(d('2026-12-08'), d('2026-12-12'))],
      ),
      today: d('2026-12-01'),
    );
    DayCellData at(String iso) => cells.firstWhere((c) => c.date == d(iso));
    expect(at('2026-12-08').kind, DayKind.predicted);
    expect(at('2026-12-08').isPredictedStart, isTrue);
    expect(at('2026-12-10').kind, DayKind.actual);
    expect(at('2026-12-11').kind, DayKind.predicted);
  });
}
