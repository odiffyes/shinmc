import 'package:sqflite/sqflite.dart';

import '../db/schema.dart';

/// Key/value app settings.
class SettingsRepository {
  const SettingsRepository();

  static const kDefaultCycleLength = 'default_cycle_length';
  static const kDefaultPeriodLength = 'default_period_length';
  static const kDataVersion = 'data_version';

  /// Set when local data changed and external calendars are not yet
  /// updated. Survives app kill so the next launch re-runs sync (§9.4).
  static const kSyncPendingSince = 'sync_pending_since';

  static const defaultCycleLength = 28;
  static const defaultPeriodLength = 5;

  Future<String?> get(DatabaseExecutor db, String key) async {
    final rows = await db.query(tSettings, where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(DatabaseExecutor db, String key, String? value) => db.insert(
    tSettings,
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<int> getInt(DatabaseExecutor db, String key, int fallback) async =>
      int.tryParse(await get(db, key) ?? '') ?? fallback;

  Future<int> defaultCycle(DatabaseExecutor db) =>
      getInt(db, kDefaultCycleLength, defaultCycleLength);

  Future<int> defaultPeriod(DatabaseExecutor db) =>
      getInt(db, kDefaultPeriodLength, defaultPeriodLength);

  Future<int> dataVersion(DatabaseExecutor db) => getInt(db, kDataVersion, 0);

  /// Bumps the data version and marks external calendars as stale.
  /// Call inside the same transaction as the data change.
  Future<int> markDataChanged(DatabaseExecutor db, DateTime now) async {
    final next = await dataVersion(db) + 1;
    await set(db, kDataVersion, '$next');
    if (await get(db, kSyncPendingSince) == null) {
      await set(db, kSyncPendingSince, now.toUtc().toIso8601String());
    }
    return next;
  }
}
