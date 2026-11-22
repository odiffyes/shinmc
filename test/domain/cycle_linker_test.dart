import 'package:flutter_test/flutter_test.dart';
import 'package:shinmc/domain/models/cycle_record.dart';
import 'package:shinmc/domain/models/period_record.dart';
import 'package:shinmc/domain/models/stress_level.dart';
import 'package:shinmc/domain/services/cycle_linker.dart';

import '../helpers.dart';

final _t = DateTime.utc(2026);

PeriodRecord p(String id, String start) =>
    PeriodRecord(id: id, startDate: d(start), createdAt: _t, updatedAt: _t);

void main() {
  var n = 0;
  final linker = CycleLinker(newId: () => 'c${++n}', now: () => _t);

  Map<String, CycleRecord> apply(
    List<PeriodRecord> periods,
    Map<String, CycleRecord> existing,
  ) {
    final out = {...existing};
    for (final c in linker.relink(periods, existing).upserts) {
      out[c.periodId] = c;
    }
    out.removeWhere((k, _) => !periods.any((p) => p.id == k));
    return out;
  }

  test('links consecutive starts and computes lengths; first has none', () {
    final cycles = apply([
      p('b', '2026-06-01'),
      p('a', '2026-05-04'),
      p('c', '2026-06-30'),
    ], {});
    expect(cycles['a']!.hasInterval, isFalse);
    expect(cycles['b']!.previousPeriodId, 'a');
    expect(cycles['b']!.lengthDays, 28);
    expect(cycles['c']!.previousPeriodId, 'b');
    expect(cycles['c']!.lengthDays, 29);
  });

  test('moving a date without reordering keeps settings', () {
    var cycles = apply([p('a', '2026-05-04'), p('b', '2026-06-01')], {});
    cycles['b'] = cycles['b']!.copyWith(
      includeInPrediction: false,
      stress: StressLevel.high,
    );
    cycles = apply([p('a', '2026-05-04'), p('b', '2026-06-03')], cycles);
    expect(cycles['b']!.lengthDays, 30);
    expect(cycles['b']!.includeInPrediction, isFalse);
    expect(cycles['b']!.stress, StressLevel.high);
    expect(cycles['b']!.needsReview, isFalse);
  });

  test('re-linking to a different previous resets toggle, keeps stress', () {
    final all = [
      p('a', '2026-05-04'),
      p('b', '2026-06-01'),
      p('c', '2026-06-30'),
    ];
    var cycles = apply(all, {});
    cycles['c'] = cycles['c']!.copyWith(
      includeInPrediction: false,
      stress: StressLevel.calm,
    );
    // b deleted -> c now follows a.
    cycles = apply([all[0], all[2]], cycles);
    expect(cycles['c']!.previousPeriodId, 'a');
    expect(cycles['c']!.lengthDays, 57);
    expect(cycles['c']!.includeInPrediction, isTrue);
    expect(cycles['c']!.needsReview, isTrue);
    expect(cycles['c']!.stress, StressLevel.calm);
  });

  test('adding older history gives the first cycle an interval, no review', () {
    var cycles = apply([p('b', '2026-06-01')], {});
    cycles = apply([p('a', '2026-05-04'), p('b', '2026-06-01')], cycles);
    expect(cycles['b']!.previousPeriodId, 'a');
    expect(cycles['b']!.needsReview, isFalse);
  });

  test('no-op relink produces no upserts', () {
    final periods = [p('a', '2026-05-04'), p('b', '2026-06-01')];
    final cycles = apply(periods, {});
    expect(linker.relink(periods, cycles).isEmpty, isTrue);
  });
}
