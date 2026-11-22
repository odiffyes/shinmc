import 'package:sqflite/sqflite.dart';

import '../../domain/models/calendar_sync.dart';
import '../db/schema.dart';

/// Bookkeeping for external events the app owns. Calendar API calls
/// themselves are implemented in stage 5.
class CalendarSyncRepository {
  const CalendarSyncRepository();

  Future<List<CalendarSyncEntry>> entriesFor(
    DatabaseExecutor db,
    SyncTarget target,
  ) async {
    final rows = await db.query(
      tSyncEntries,
      where: 'target = ?',
      whereArgs: [target.dbValue],
    );
    return rows.map(CalendarSyncEntry.fromRow).toList();
  }

  Future<void> upsert(DatabaseExecutor db, CalendarSyncEntry e) => db.insert(
    tSyncEntries,
    e.toRow(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> delete(DatabaseExecutor db, String id) =>
      db.delete(tSyncEntries, where: 'id = ?', whereArgs: [id]);

  Future<bool> isEnabled(DatabaseExecutor db, SyncTarget target) async {
    final rows = await db.query(
      tSyncTargets,
      columns: ['enabled'],
      where: 'target = ?',
      whereArgs: [target.dbValue],
    );
    return rows.isNotEmpty && rows.first['enabled'] == 1;
  }

  Future<void> setTarget(
    DatabaseExecutor db,
    SyncTarget target, {
    required bool enabled,
    String? calendarId,
    String? dedupeKey,
  }) => db.update(
    tSyncTargets,
    {
      'enabled': enabled ? 1 : 0,
      'calendar_id': calendarId,
      'dedupe_key': dedupeKey,
    },
    where: 'target = ?',
    whereArgs: [target.dbValue],
  );

  /// True if another enabled target already writes to the same real
  /// calendar (e.g. the device calendar *is* the user's Google calendar).
  Future<bool> wouldDuplicate(
    DatabaseExecutor db,
    SyncTarget target,
    String dedupeKey,
  ) async {
    final rows = await db.query(
      tSyncTargets,
      where: 'target != ? AND enabled = 1 AND dedupe_key = ?',
      whereArgs: [target.dbValue, dedupeKey],
    );
    return rows.isNotEmpty;
  }
}
