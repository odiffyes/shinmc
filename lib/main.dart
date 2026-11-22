import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'app_scope.dart';
import 'data/db/app_database.dart';
import 'domain/services/period_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final periodService = PeriodService(database.db);
  runApp(
    AppScope(
      database: database,
      periodService: periodService,
      child: const ShinmcApp(),
    ),
  );
}
