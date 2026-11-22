import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Opens the local SQLite database. All health data stays on the device
/// by default (spec §10).
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const fileName = 'shinmc.db';

  /// Opens the app database in the platform's private app directory.
  ///
  /// [factory] and [path] are injectable for tests (sqflite_common_ffi,
  /// in-memory databases).
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from; v < to; v++) {
      final batch = db.batch();
      for (final sql in migrations[v]) {
        batch.execute(sql);
      }
      await batch.commit(noResult: true);
    }
  }

  /// Deletes every record the app holds (spec §10 "앱 기록 전체 삭제").
  /// External calendar events must be removed by the sync layer *before*
  /// calling this, because this also forgets which events the app owns.
  Future<void> wipeAllData() => db.transaction((txn) async {
    await txn.delete(tSyncEntries);
    await txn.delete(tPredictions);
    await txn.delete(tCycles);
    await txn.delete(tPeriods);
    await txn.delete(tSettings);
    await txn.update(tSyncTargets, {
      'enabled': 0,
      'calendar_id': null,
      'dedupe_key': null,
      'state': 'idle',
      'last_error': null,
      'last_synced_at': null,
    });
  });

  Future<void> close() => db.close();
}
