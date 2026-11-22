import 'package:flutter_test/flutter_test.dart';
import 'package:shinmc/data/db/app_database.dart';
import 'package:shinmc/data/repositories/settings_repository.dart';
import 'package:shinmc/domain/models/cycle_record.dart';
import 'package:shinmc/domain/models/stress_level.dart';
import 'package:shinmc/domain/services/period_service.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late PeriodService svc;

  setUp(() async {
    db = await openTestDb();
    svc = testService(db);
  });
  tearDown(() => db.close());

  Future<String> idAt(String start) async =>
      (await svc.periods()).firstWhere((p) => p.startDate == d(start)).id;

  Future<CycleRecord> cycleAt(String start) async =>
      (await svc.cycleFor(await idAt(start)))!;

  Matcher conflict(ConflictReason r) =>
      throwsA(isA<PeriodConflict>().having((e) => e.reason, 'reason', r));

  test('#1 regular 28-day cycle', () async {
    await svc.markStart(d('2026-05-04'));
    await svc.markStart(d('2026-06-01'));
    expect((await cycleAt('2026-06-01')).lengthDays, 28);
    expect((await cycleAt('2026-05-04')).hasInterval, isFalse);
  });

  test('#2 two starts in one month are separate cycles', () async {
    await svc.markStart(d('2026-05-04'));
    await svc.markStart(d('2026-06-01'));
    await svc.markStart(d('2026-06-30'));
    expect((await cycleAt('2026-06-01')).lengthDays, 28);
    expect((await cycleAt('2026-06-30')).lengthDays, 29);
  });

  test('#3 period spanning months, #4 end optional', () async {
    await svc.markStart(d('2026-06-28'));
    expect((await svc.periods()).single.endDate, isNull);
    await svc.markEnd(d('2026-07-03'));
    final p = (await svc.periods()).single;
    expect(p.endDate, d('2026-07-03'));
    expect(p.lengthDays, 6);
    expect(p.containsDate(d('2026-07-01')), isTrue);
  });

  test('end attaches to the latest start on/before the date', () async {
    await svc.markStart(d('2026-05-04'));
    await svc.markStart(d('2026-06-01'));
    await svc.markEnd(d('2026-06-05'));
    final ps = await svc.periods();
    expect(ps[0].endDate, isNull);
    expect(ps[1].endDate, d('2026-06-05'));
    expect(
      () => svc.markEnd(d('2026-04-01')),
      conflict(ConflictReason.noStartBeforeDate),
    );
  });

  test('conflicts: duplicate start, overlap, end before start', () async {
    await svc.markStart(d('2026-06-01'));
    await svc.markEnd(d('2026-06-05'));
    expect(
      () => svc.markStart(d('2026-06-01')),
      conflict(ConflictReason.duplicateStart),
    );
    expect(
      () => svc.markStart(d('2026-06-03')),
      conflict(ConflictReason.overlapsExisting),
    );
    final id = await idAt('2026-06-01');
    expect(
      () => svc.moveStart(id, d('2026-06-06')),
      conflict(ConflictReason.endBeforeStart),
    );
    expect(
      () => svc.moveEnd(id, d('2026-05-30')),
      conflict(ConflictReason.endBeforeStart),
    );
    await svc.markStart(d('2026-06-29'));
    expect(
      () => svc.moveEnd(id, d('2026-06-29')),
      conflict(ConflictReason.overlapsExisting),
    );
    // Nothing was written by the failed attempts.
    expect((await svc.periods()).first.endDate, d('2026-06-05'));
  });

  test('#5 consecutive drags keep the record and its settings', () async {
    await svc.markStart(d('2026-05-04'));
    await svc.markStart(d('2026-06-01'));
    final id = await idAt('2026-06-01');
    await svc.setStress(id, StressLevel.high);
    await svc.setIncludeInPrediction(id, false);
    for (final day in [
      '2026-06-02',
      '2026-06-04',
      '2026-05-30',
      '2026-06-03',
    ]) {
      await svc.moveStart(id, d(day));
    }
    final c = (await svc.cycleFor(id))!;
    expect(c.lengthDays, 30);
    expect(c.stress, StressLevel.high);
    expect(c.includeInPrediction, isFalse);
  });

  test(
    '#6 editing a past start changes only that record and neighbours',
    () async {
      await svc.markStart(d('2026-05-20'));
      await svc.markStart(d('2026-06-17'));
      await svc.markStart(d('2026-07-18'));
      await svc.moveStart(await idAt('2026-06-17'), d('2026-06-19'));
      final starts = (await svc.periods()).map((p) => p.startDate.toIso());
      expect(starts, ['2026-05-20', '2026-06-19', '2026-07-18']);
      expect((await cycleAt('2026-06-19')).lengthDays, 30);
      expect((await cycleAt('2026-07-18')).lengthDays, 29);
    },
  );

  test('#7 delete re-links the next cycle; undo restores everything', () async {
    await svc.markStart(d('2026-05-04'));
    await svc.markStart(d('2026-06-01'));
    await svc.markStart(d('2026-06-30'));
    final c30 = await idAt('2026-06-30');
    await svc.setIncludeInPrediction(c30, false);
    await svc.setStress(c30, StressLevel.calm);

    final token = await svc.deletePeriod(await idAt('2026-06-01'));
    var c = (await svc.cycleFor(c30))!;
    expect(c.lengthDays, 57);
    expect(c.includeInPrediction, isTrue, reason: 'different interval now');
    expect(c.needsReview, isTrue);
    expect(c.stress, StressLevel.calm);

    await svc.undo(token);
    expect((await svc.periods()), hasLength(3));
    c = (await svc.cycleFor(c30))!;
    expect(c.lengthDays, 29);
    expect(c.includeInPrediction, isFalse);
    expect(c.needsReview, isFalse);
    expect((await cycleAt('2026-06-01')).lengthDays, 28);
  });

  test('undo of a move and of an add; redo works', () async {
    await svc.markStart(d('2026-05-04'));
    final addToken = await svc.markStart(d('2026-06-01'));
    final id = await idAt('2026-06-01');
    final moveToken = await svc.moveStart(id, d('2026-06-05'));
    final redo = await svc.undo(moveToken);
    expect((await svc.cycleFor(id))!.lengthDays, 28);
    await svc.undo(redo);
    expect((await svc.cycleFor(id))!.lengthDays, 32);
    await svc.undo(addToken);
    expect(await svc.periods(), hasLength(1));
    expect(await svc.cycles(), hasLength(1));
  });

  test('#8 toggle on/off; disabled without a previous start', () async {
    await svc.markStart(d('2026-05-04'));
    expect(
      () async => svc.setIncludeInPrediction(await idAt('2026-05-04'), false),
      conflict(ConflictReason.noInterval),
    );
    await svc.markStart(d('2026-06-01'));
    final id = await idAt('2026-06-01');
    await svc.setIncludeInPrediction(id, false);
    expect((await svc.cycleFor(id))!.countsForPrediction, isFalse);
    await svc.setIncludeInPrediction(id, true);
    expect((await svc.cycleFor(id))!.countsForPrediction, isTrue);
  });

  test('#9 #10 stress is independent of the prediction toggle', () async {
    await svc.markStart(d('2026-05-04'));
    await svc.markStart(d('2026-06-01'));
    final id = await idAt('2026-06-01');
    expect((await svc.cycleFor(id))!.stress, StressLevel.unrecorded);
    for (final s in [StressLevel.high, StressLevel.neutral, StressLevel.calm]) {
      await svc.setStress(id, s);
      final c = (await svc.cycleFor(id))!;
      expect(c.stress, s);
      expect(c.includeInPrediction, isTrue);
    }
    await svc.setIncludeInPrediction(id, false);
    expect((await svc.cycleFor(id))!.stress, StressLevel.calm);
  });

  test(
    'data version and pending-sync flag; stress does not trigger sync',
    () async {
      const settings = SettingsRepository();
      final events = <bool>[];
      final sub = svc.changes.listen((e) => events.add(e.affectsPredictions));
      await svc.markStart(d('2026-05-04'));
      await svc.markStart(d('2026-06-01'));
      expect(await settings.dataVersion(db.db), 2);
      expect(
        await settings.get(db.db, SettingsRepository.kSyncPendingSince),
        isNotNull,
      );
      await svc.setStress(await idAt('2026-06-01'), StressLevel.high);
      expect(await settings.dataVersion(db.db), 2);
      await Future<void>.delayed(Duration.zero);
      expect(events, [true, true, false]);
      await sub.cancel();
    },
  );

  test('a start can move past a neighbour (re-link) if no overlap', () async {
    await svc.markStart(d('2026-05-04'));
    await svc.markStart(d('2026-06-01'));
    await svc.markStart(d('2026-06-30'));
    final id = await idAt('2026-05-04');
    await svc.moveStart(id, d('2026-07-28'));
    final starts = (await svc.periods()).map((p) => p.startDate.toIso());
    expect(starts, ['2026-06-01', '2026-06-30', '2026-07-28']);
    final moved = (await svc.cycleFor(id))!;
    expect(moved.lengthDays, 28);
    expect((await cycleAt('2026-06-01')).hasInterval, isFalse);
  });
}
