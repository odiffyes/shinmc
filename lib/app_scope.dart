import 'package:material_ui/material_ui.dart';

import 'data/db/app_database.dart';
import 'domain/services/period_service.dart';

/// Makes app-wide services available to the widget tree without a
/// third-party DI/state package.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.database,
    required this.periodService,
    required super.child,
  });

  final AppDatabase database;
  final PeriodService periodService;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      database != oldWidget.database ||
      periodService != oldWidget.periodService;
}
