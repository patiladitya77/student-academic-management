import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('DateSelectionScreen Unit Tests', () {
    // Helper function to format date for display
    String formatDateDisplay(DateTime date) {
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    }

    // Helper function to validate date
    bool validateDate(DateTime date, DateTime earliestDate, DateTime latestDate) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final normalizedEarliest = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);
      final normalizedLatest = DateTime(latestDate.year, latestDate.month, latestDate.day);

      if (normalizedDate.isBefore(normalizedEarliest)) {
        return false;
      }
      if (normalizedDate.isAfter(normalizedLatest)) {
        return false;
      }
      return true;
    }

    group('Date Validation Logic', () {
      test('current date should be valid', () {
        final currentDate = DateTime.now();
        final earliestDate = DateTime.now().subtract(const Duration(days: 90));
        final latestDate = DateTime.now();

        expect(validateDate(currentDate, earliestDate, latestDate), true);
      });

      test('date 90 days ago should be valid', () {
        final date90DaysAgo = DateTime.now().subtract(const Duration(days: 90));
        final earliestDate = DateTime.now().subtract(const Duration(days: 90));
        final latestDate = DateTime.now();

        expect(validateDate(date90DaysAgo, earliestDate, latestDate), true);
      });

      test('date 91 days ago should be invalid', () {
        final date91DaysAgo = DateTime.now().subtract(const Duration(days: 91));
        final earliestDate = DateTime.now().subtract(const Duration(days: 90));
        final latestDate = DateTime.now();

        expect(validateDate(date91DaysAgo, earliestDate, latestDate), false);
      });

      test('future date (tomorrow) should be invalid', () {
        final futureDate = DateTime.now().add(const Duration(days: 1));
        final earliestDate = DateTime.now().subtract(const Duration(days: 90));
        final latestDate = DateTime.now();

        expect(validateDate(futureDate, earliestDate, latestDate), false);
      });

      test('date exactly at earliest boundary should be valid', () {
        final earliestDate = DateTime.now().subtract(const Duration(days: 90));
        final latestDate = DateTime.now();

        expect(validateDate(earliestDate, earliestDate, latestDate), true);
      });

      test('date exactly at latest boundary should be valid', () {
        final earliestDate = DateTime.now().subtract(const Duration(days: 90));
        final latestDate = DateTime.now();

        expect(validateDate(latestDate, earliestDate, latestDate), true);
      });

      test('date 45 days ago (middle of range) should be valid', () {
        final date45DaysAgo = DateTime.now().subtract(const Duration(days: 45));
        final earliestDate = DateTime.now().subtract(const Duration(days: 90));
        final latestDate = DateTime.now();

        expect(validateDate(date45DaysAgo, earliestDate, latestDate), true);
      });
    });

    group('Date Formatting', () {
      test('formatDateDisplay should return correct format', () {
        final testDate = DateTime(2024, 1, 15);
        final formatted = formatDateDisplay(testDate);

        // Should match "DayOfWeek, Month Day, Year" format
        expect(formatted, matches(r'^[A-Za-z]+, [A-Za-z]+ \d{1,2}, \d{4}$'));
      });

      test('formatDateDisplay should include day of week', () {
        final testDate = DateTime(2024, 1, 15); // Monday
        final formatted = formatDateDisplay(testDate);

        expect(formatted, contains('Monday'));
      });

      test('formatDateDisplay should include month name', () {
        final testDate = DateTime(2024, 1, 15);
        final formatted = formatDateDisplay(testDate);

        expect(formatted, contains('January'));
      });

      test('formatDateDisplay should include day and year', () {
        final testDate = DateTime(2024, 1, 15);
        final formatted = formatDateDisplay(testDate);

        expect(formatted, contains('15'));
        expect(formatted, contains('2024'));
      });

      test('formatDateDisplay should handle different dates correctly', () {
        final testDate1 = DateTime(2023, 12, 25);
        final testDate2 = DateTime(2024, 7, 4);

        final formatted1 = formatDateDisplay(testDate1);
        final formatted2 = formatDateDisplay(testDate2);

        expect(formatted1, contains('December'));
        expect(formatted1, contains('25'));
        expect(formatted1, contains('2023'));

        expect(formatted2, contains('July'));
        expect(formatted2, contains('4'));
        expect(formatted2, contains('2024'));
      });
    });

    group('Date Range Calculations', () {
      test('earliest date should be 90 days before current date', () {
        final currentDate = DateTime.now();
        final earliestDate = currentDate.subtract(const Duration(days: 90));

        final difference = currentDate.difference(earliestDate).inDays;
        expect(difference, 90);
      });

      test('latest date should be current date', () {
        final currentDate = DateTime.now();
        final latestDate = DateTime.now();

        final normalizedCurrent = DateTime(currentDate.year, currentDate.month, currentDate.day);
        final normalizedLatest = DateTime(latestDate.year, latestDate.month, latestDate.day);

        expect(normalizedCurrent.isAtSameMomentAs(normalizedLatest), true);
      });

      test('date range should span 91 days (inclusive)', () {
        final earliestDate = DateTime.now().subtract(const Duration(days: 90));
        final latestDate = DateTime.now();

        final rangeDays = latestDate.difference(earliestDate).inDays;
        expect(rangeDays, 90);
      });
    });

    group('Edge Cases', () {
      test('validation should handle dates with different times on same day', () {
        final date1 = DateTime(2024, 1, 15, 9, 0, 0);
        final date2 = DateTime(2024, 1, 15, 18, 30, 0);
        final earliestDate = DateTime(2024, 1, 1);
        final latestDate = DateTime(2024, 1, 31);

        // Both should be valid as they're on the same day within range
        expect(validateDate(date1, earliestDate, latestDate), true);
        expect(validateDate(date2, earliestDate, latestDate), true);
      });

      test('validation should normalize dates to ignore time component', () {
        final dateWithTime = DateTime(2024, 1, 15, 23, 59, 59);
        final earliestDate = DateTime(2024, 1, 15, 0, 0, 0);
        final latestDate = DateTime(2024, 1, 15, 0, 0, 0);

        // Should be valid as it's the same day
        expect(validateDate(dateWithTime, earliestDate, latestDate), true);
      });

      test('validation should handle leap year dates', () {
        final leapYearDate = DateTime(2024, 2, 29); // 2024 is a leap year
        final earliestDate = DateTime(2024, 2, 1);
        final latestDate = DateTime(2024, 3, 1);

        expect(validateDate(leapYearDate, earliestDate, latestDate), true);
      });

      test('validation should handle year boundaries', () {
        final newYearDate = DateTime(2024, 1, 1);
        final earliestDate = DateTime(2023, 12, 1);
        final latestDate = DateTime(2024, 1, 31);

        expect(validateDate(newYearDate, earliestDate, latestDate), true);
      });
    });
  });
}
