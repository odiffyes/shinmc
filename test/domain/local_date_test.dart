import 'package:flutter_test/flutter_test.dart';
import 'package:shinmc/core/local_date.dart';

void main() {
  test('day differences match the spec examples (§5.1)', () {
    expect(LocalDate(2026, 5, 4).daysUntil(LocalDate(2026, 6, 1)), 28);
    expect(LocalDate(2026, 6, 1).daysUntil(LocalDate(2026, 6, 30)), 29);
    expect(LocalDate(2026, 6, 17).addDays(28), LocalDate(2026, 7, 15));
  });

  test('arithmetic is unaffected by DST and crosses months/years', () {
    expect(LocalDate(2026, 3, 1).daysUntil(LocalDate(2026, 4, 1)), 31);
    expect(LocalDate(2026, 12, 20).addDays(15), LocalDate(2027, 1, 4));
    expect(LocalDate(2028, 2, 28).addDays(1), LocalDate(2028, 2, 29));
  });

  test('parse/format round-trip and validation', () {
    expect(LocalDate.parse('2026-06-01').toIso(), '2026-06-01');
    expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
    expect(() => LocalDate.parse('2026-6-1'), throwsFormatException);
    expect(() => LocalDate(2026, 13, 1), throwsArgumentError);
  });
}
