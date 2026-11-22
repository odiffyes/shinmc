import 'package:sqflite/sqflite.dart';

import '../../domain/models/cycle_record.dart';
import '../db/schema.dart';

class CycleRepository {
  const CycleRepository();

  Future<List<CycleRecord>> all(DatabaseExecutor db) async {
    final rows = await db.query(tCycles);
    return rows.map(CycleRecord.fromRow).toList();
  }

  Future<Map<String, CycleRecord>> allByPeriodId(DatabaseExecutor db) async {
    final list = await all(db);
    return {for (final c in list) c.periodId: c};
  }

  Future<CycleRecord?> byPeriodId(DatabaseExecutor db, String periodId) async {
    final rows = await db.query(
      tCycles,
      where: 'period_id = ?',
      whereArgs: [periodId],
    );
    return rows.isEmpty ? null : CycleRecord.fromRow(rows.first);
  }

  Future<void> upsert(DatabaseExecutor db, CycleRecord cycle) async {
    final updated = await db.update(
      tCycles,
      cycle.toRow(),
      where: 'id = ?',
      whereArgs: [cycle.id],
    );
    if (updated == 0) {
      await db.insert(tCycles, cycle.toRow());
    }
  }

  Future<void> deleteById(DatabaseExecutor db, String id) =>
      db.delete(tCycles, where: 'id = ?', whereArgs: [id]);
}
