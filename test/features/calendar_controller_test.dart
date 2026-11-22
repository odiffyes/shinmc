import 'package:flutter_test/flutter_test.dart';
import 'package:shinmc/data/db/app_database.dart';
import 'package:shinmc/domain/services/period_service.dart';
import 'package:shinmc/features/calendar/calendar_controller.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late PeriodService svc;
  late CalendarController c;

  setUp(() async {
    db = await openTestDb();
    svc = testService(db);
    c = CalendarController(svc, today: () => d('2026-11-22'));
    await c.reload();
  });
  tearDown(() async {
    c.dispose();
    // Let reloads triggered by the last change finish before closing.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.close();
  });

  test('month navigation wraps years', () {
    expect((c.year, c.month), (2026, 11));
    c.nextMonth();
    c.nextMonth();
    expect((c.year, c.month), (2027, 1));
    c.previousMonth();
    c.previousMonth();
    c.previousMonth();
    expect((c.year, c.month), (2026, 10));
    c.goToToday();
    expect((c.year, c.month), (2026, 11));
  });

  test('next predicted start uses the 28-day default (option A)', () async {
    expect(c.nextPredictedStart, isNull);
    await svc.markStart(d('2026-11-01'));
    await c.reload();
    expect(c.nextPredictedStart, d('2026-11-29'));
  });

  test('drag previews without saving, saves only on drop', () async {
    await svc.markStart(d('2026-11-01'));
    await svc.markEnd(d('2026-11-05'));
    await c.reload();

    expect(c.beginDrag(d('2026-11-03')), isFalse, reason: 'middle day');
    expect(c.beginDrag(d('2026-11-05')), isTrue);
    c.updateDrag(d('2026-11-06'));
    c.updateDrag(d('2026-11-07'));
    expect(c.displayPeriods.single.endDate, d('2026-11-07'));
    expect(
      (await svc.periods()).single.endDate,
      d('2026-11-05'),
      reason: 'nothing saved during drag',
    );

    final token = await c.endDrag();
    expect(token, isNotNull);
    expect(c.drag, isNull);
    expect((await svc.periods()).single.endDate, d('2026-11-07'));

    await c.undo(token!);
    expect((await svc.periods()).single.endDate, d('2026-11-05'));
  });

  test('dropping a start past its end is rejected and reverted', () async {
    await svc.markStart(d('2026-11-01'));
    await svc.markEnd(d('2026-11-05'));
    await c.reload();
    c.beginDrag(d('2026-11-01'));
    c.updateDrag(d('2026-11-08'));
    await expectLater(c.endDrag(), throwsA(isA<PeriodConflict>()));
    expect(c.drag, isNull);
    expect(c.displayPeriods.single.startDate, d('2026-11-01'));
  });

  test('drop on the original date saves nothing', () async {
    await svc.markStart(d('2026-11-01'));
    await c.reload();
    c.beginDrag(d('2026-11-01'));
    c.updateDrag(d('2026-11-03'));
    c.updateDrag(d('2026-11-01'));
    expect(await c.endDrag(), isNull);
  });
}
