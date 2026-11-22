import 'package:sqflite/sqflite.dart';

import '../../domain/models/prediction.dart';
import '../db/schema.dart';

class PredictionRepository {
  const PredictionRepository();

  Future<List<Prediction>> all(DatabaseExecutor db) async {
    final rows = await db.query(tPredictions, orderBy: 'sequence ASC');
    return rows.map(Prediction.fromRow).toList();
  }

  /// Replaces the stored prediction set atomically.
  Future<void> replaceAll(DatabaseExecutor db, List<Prediction> items) async {
    await db.delete(tPredictions);
    for (final p in items) {
      await db.insert(tPredictions, p.toRow());
    }
  }
}
