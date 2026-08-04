import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/core/daily_utc_date.dart';

void main() {
  test('Daily date changes exactly at the UTC boundary', () {
    expect(
      dailyUtcDateKey(DateTime.parse('2026-07-21T23:59:59.999Z')),
      '2026-07-21',
    );
    expect(
      dailyUtcDateKey(DateTime.parse('2026-07-22T00:00:00.000Z')),
      '2026-07-22',
    );
    expect(
      dailyUtcDateKey(DateTime.parse('2026-07-22T01:15:00+02:00')),
      '2026-07-21',
    );
  });

  test('legacy local today is conservatively migrated to UTC today', () {
    final migration = migrateLegacyDailyDate(
      storedDate: '2026-07-22',
      alreadyUtc: false,
      utcToday: '2026-07-21',
      localToday: '2026-07-22',
    );

    expect(migration.date, '2026-07-21');
    expect(migration.shouldMarkUtc, isTrue);
  });

  test('legacy history is preserved and marked without reinterpretation', () {
    final migration = migrateLegacyDailyDate(
      storedDate: '2026-07-18',
      alreadyUtc: false,
      utcToday: '2026-07-21',
      localToday: '2026-07-22',
    );

    expect(migration.date, '2026-07-18');
    expect(migration.shouldMarkUtc, isTrue);
    expect(
      migrateLegacyDailyDate(
        storedDate: '2026-07-18',
        alreadyUtc: true,
        utcToday: '2026-07-21',
        localToday: '2026-07-22',
      ).date,
      '2026-07-18',
    );
  });

  test('calendar keys reject impossible dates', () {
    expect(isCalendarDateKey('2026-02-28'), isTrue);
    expect(isCalendarDateKey('2026-02-29'), isFalse);
    expect(isCalendarDateKey('2026-13-01'), isFalse);
    expect(isCalendarDateKey('21-07-2026'), isFalse);
  });
}
