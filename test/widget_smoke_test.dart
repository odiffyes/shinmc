import 'package:flutter_test/flutter_test.dart';
import 'package:shinmc/app.dart';
import 'package:shinmc/app_scope.dart';
import 'package:shinmc/domain/services/period_service.dart';

import 'helpers.dart';

void main() {
  testWidgets('app boots with an empty database', (tester) async {
    final db = (await tester.runAsync(openTestDb))!;
    await tester.pumpWidget(
      AppScope(
        database: db,
        periodService: PeriodService(db.db),
        child: const ShinmcApp(),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('주기'), findsOneWidget);
    expect(find.text('저장된 실제 기록 0건'), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
