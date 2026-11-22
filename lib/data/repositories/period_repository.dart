import 'package:sqflite/sqflite.dart';

import '../../domain/models/period_record.dart';
import '../db/schema.dart';

/// Raw access to `period_records`. Business rules live in PeriodService;
/// call mutations only from there so cycles stay linked.
class PeriodRepository {
  const PeriodRepository();

  Future<List<PeriodRecord>> all(DatabaseExecutor db) async {
    final rows = await db.query(tPeriods, orderBy: 'start_date ASC');
    return rows.map(PeriodRecord.fromRow).toList();
  }

  Future<PeriodRecord?> byId(DatabaseExecutor db, String id) async {
    final rows = await db.query(tPeriods, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : PeriodRecord.fromRow(rows.first);
  }

  /// Update-then-insert. Never uses `INSERT OR REPLACE`, which deletes the
  /// row first and would cascade-delete the period's cycle settings.
  Future<void> upsert(DatabaseExecutor db, PeriodRecord record) async {
    final updated = await db.update(
      tPeriods,
      record.toRow(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    if (updated == 0) await insert(db, record);
  }

  Future<void> insert(DatabaseExecutor db, PeriodRecord record) => db.insert(
    tPeriods,
    record.toRow(),
    conflictAlgorithm: ConflictAlgorithm.abort,
  );

  Future<void> delete(DatabaseExecutor db, String id) =>
      db.delete(tPeriods, where: 'id = ?', whereArgs: [id]);
}
