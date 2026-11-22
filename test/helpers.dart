import 'package:shinmc/core/local_date.dart';
import 'package:shinmc/data/db/app_database.dart';
import 'package:shinmc/domain/services/period_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

Future<AppDatabase> openTestDb() {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
}

/// Service with deterministic IDs and clock.
PeriodService testService(AppDatabase db) {
  var n = 0;
  return PeriodService(
    db.db,
    newId: () => 'id${++n}',
    now: () => DateTime.utc(2026, 11, 22, 12),
  );
}
