import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shinmc/app_scope.dart';
import 'package:shinmc/core/theme.dart';
import 'package:shinmc/data/db/app_database.dart';
import 'package:shinmc/domain/services/period_service.dart';
import 'package:shinmc/features/calendar/calendar_screen.dart';

import '../helpers.dart';

/// sqflite_common_ffi does real async I/O, so let it run outside the
/// fake test clock, then pump the resulting frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  late AppDatabase db;
  late PeriodService svc;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = (await tester.runAsync(openTestDb))!;
    svc = PeriodService(db.db);
    await tester.pumpWidget(
      AppScope(
        database: db,
        periodService: svc,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CalendarScreen(today: () => d('2026-11-22')),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> closeDb(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  Finder day(String iso) => find.byKey(ValueKey('day-${d(iso)}'));

  testWidgets('shows month header and empty-state hint', (tester) async {
    await pumpApp(tester);
    expect(find.text('2026년 11월'), findsOneWidget);
    expect(find.text('시작일을 기록하면 예상일이 표시돼요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('next-month')));
    await tester.pump();
    expect(find.text('2026년 12월'), findsOneWidget);
    await closeDb(tester);
  });

  testWidgets('tap date -> 시작 records a start and shows next prediction', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(day('2026-11-03'));
    await tester.pumpAndSettle();
    expect(find.text('시작'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('popup-start')));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(
      (await tester.runAsync(svc.periods))!.single.startDate,
      d('2026-11-03'),
    );
    expect(
      find.byKey(ValueKey('delete-start-${d('2026-11-03')}')),
      findsOneWidget,
    );
    expect(find.text('12월 1일 (화)'), findsOneWidget);
    await closeDb(tester);
  });

  testWidgets('tap date -> 종료 sets the end', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() => svc.markStart(d('2026-11-03')));
    await settle(tester);
    await tester.tap(day('2026-11-07'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('popup-end')));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(
      (await tester.runAsync(svc.periods))!.single.endDate,
      d('2026-11-07'),
    );
    expect(
      find.byKey(ValueKey('clear-end-${d('2026-11-07')}')),
      findsOneWidget,
    );
    await closeDb(tester);
  });

  testWidgets('× deletes the record, 되돌리기 restores it', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() => svc.markStart(d('2026-11-03')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('delete-start-${d('2026-11-03')}')));
    await settle(tester);
    expect(await tester.runAsync(svc.periods), isEmpty);
    expect(find.text('기록을 삭제했어요'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await settle(tester);
    expect(
      (await tester.runAsync(svc.periods))!.single.startDate,
      d('2026-11-03'),
    );
    await closeDb(tester);
  });

  testWidgets('long-press drag moves the end date on release', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() async {
      await svc.markStart(d('2026-11-03'));
      await svc.markEnd(d('2026-11-06'));
    });
    await settle(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(day('2026-11-06')),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(day('2026-11-07')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(day('2026-11-08')));
    await tester.pump();
    // Still the saved value while dragging.
    expect(
      (await tester.runAsync(svc.periods))!.single.endDate,
      d('2026-11-06'),
    );
    await gesture.up();
    await settle(tester);

    expect(
      (await tester.runAsync(svc.periods))!.single.endDate,
      d('2026-11-08'),
    );
    expect(find.text('날짜를 옮겼어요'), findsOneWidget);
    await closeDb(tester);
  });

  testWidgets('conflicting input explains instead of saving', (tester) async {
    await pumpApp(tester);
    await tester.tap(day('2026-11-03'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('popup-end')));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('이 날짜 이전에 시작일이 없어요.'), findsOneWidget);
    await closeDb(tester);
  });

  testWidgets('calendar settings button opens the settings screen', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('calendar-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Google Calendar'), findsOneWidget);
    await closeDb(tester);
  });
}
