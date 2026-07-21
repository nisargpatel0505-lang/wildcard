/// Marker retained inside [AccountState.unknownFields] after the one-time
/// conversion from the legacy client's device-local Daily date.
const String dailyRunDateUtcMarkerKey = '_flutterDailyRunDateUtcV1';

String calendarDateKey(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

/// The authoritative day used by the Daily Challenge, Firebase callable and
/// Pi board.
String dailyUtcDateKey([DateTime? now]) =>
    calendarDateKey((now ?? DateTime.now()).toUtc());

String localCalendarDateKey([DateTime? now]) =>
    calendarDateKey((now ?? DateTime.now()).toLocal());

bool isCalendarDateKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

class LegacyDailyDateMigration {
  const LegacyDailyDateMigration({
    required this.date,
    required this.shouldMarkUtc,
  });

  final String date;
  final bool shouldMarkUtc;
}

/// Converts only a legacy date that represents "today" on the device.
///
/// Historical dates are deliberately preserved verbatim. Near a UTC boundary,
/// a legacy local "today" is mapped to the current UTC day so an existing
/// attempt cannot accidentally gain a second play during the migration.
LegacyDailyDateMigration migrateLegacyDailyDate({
  required String storedDate,
  required bool alreadyUtc,
  required String utcToday,
  required String localToday,
}) {
  if (alreadyUtc) {
    return LegacyDailyDateMigration(date: storedDate, shouldMarkUtc: false);
  }
  final normalized = isCalendarDateKey(storedDate) && storedDate == localToday
      ? utcToday
      : storedDate;
  return LegacyDailyDateMigration(date: normalized, shouldMarkUtc: true);
}

/// Safe before and after the one-time migration. The legacy local comparison
/// closes the brief window where a screen can be built from an old save before
/// that save has been normalized and persisted.
bool dailyAttemptUsedToday({
  required String storedDate,
  required bool utcMigrationComplete,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  if (storedDate == dailyUtcDateKey(current)) return true;
  return !utcMigrationComplete &&
      storedDate == localCalendarDateKey(current) &&
      isCalendarDateKey(storedDate);
}
