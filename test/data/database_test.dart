import 'package:flutter_test/flutter_test.dart';
import 'package:shinmc/data/db/schema.dart';
import 'package:shinmc/data/repositories/calendar_sync_repository.dart';
import 'package:shinmc/domain/models/calendar_sync.dart';

import '../helpers.dart';

void main() {
  test('creates schema with foreign keys on and both sync targets', () async {
    final db = await openTestDb();
    final fk = await db.db.rawQuery('PRAGMA foreign_keys');
    expect(fk.first.values.first, 1);
    final targets = await db.db.query(tSyncTargets, orderBy: 'target');
    expect(targets.map((r) => r['target']), ['device', 'google']);
    expect(targets.every((r) => r['enabled'] == 0), isTrue);
    await db.close();
  });

  test('rejects end before start at the DB level', () async {
    final db = await openTestDb();
    expect(
      () => db.db.insert(tPeriods, {
        'id': 'x',
        'start_date': '2026-06-10',
        'end_date': '2026-06-09',
        'created_at': '',
        'updated_at': '',
      }),
      throwsA(anything),
    );
    await db.close();
  });

  test('duplicate-calendar detection across Google API and device', () async {
    final db = await openTestDb();
    const repo = CalendarSyncRepository();
    await repo.setTarget(
      db.db,
      SyncTarget.google,
      enabled: true,
      calendarId: 'primary',
      dedupeKey: 'google:acct1',
    );
    expect(
      await repo.wouldDuplicate(
        db.db,
        SyncTarget.deviceCalendar,
        'google:acct1',
      ),
      isTrue,
    );
    expect(
      await repo.wouldDuplicate(db.db, SyncTarget.deviceCalendar, 'icloud:x'),
      isFalse,
    );
    await db.close();
  });

  test('sync entry is unique per target/calendar/kind/record', () async {
    final db = await openTestDb();
    const repo = CalendarSyncRepository();
    CalendarSyncEntry e(String id) => CalendarSyncEntry(
      id: id,
      target: SyncTarget.google,
      calendarId: 'primary',
      localRefId: 'pred:1',
      kind: SyncEventKind.predicted,
      status: SyncStatus.pending,
    );
    await repo.upsert(db.db, e('a'));
    await repo.upsert(db.db, e('b')); // replaces, never duplicates
    expect(await repo.entriesFor(db.db, SyncTarget.google), hasLength(1));
    await db.close();
  });

  test('wipeAllData removes all health data', () async {
    final db = await openTestDb();
    final svc = testService(db);
    await svc.markStart(d('2026-06-01'));
    await db.wipeAllData();
    expect(await svc.periods(), isEmpty);
    expect(await svc.cycles(), isEmpty);
    await db.close();
  });
}
