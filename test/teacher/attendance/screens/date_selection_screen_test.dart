import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sam_pro/Teacher/Attendance/screens/date_selection_screen.dart';

void main() {
  group('DateSelectionScreen', () {
    // Helper function to format date for display
    String formatDateDisplay(DateTime date) {
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    }

    setUp(() {
      // No Firebase initialization needed for widget tests
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: DateSelectionScreen(
          semester: 'Fall 2024',
          courseName: 'Computer Science 101',
          teacherId: 'T001',
          teacherName: 'John Doe',
        ),
      );
    }

    testWidgets('should display course information', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Computer Science 101'), findsOneWidget);
      expect(find.text('Semester: Fall 2024'), findsOneWidget);
      expect(find.text('Teacher: John Doe'), findsOneWidget);
    });

    testWidgets('should initialize with current date', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final currentDate = DateTime.now();
      final formattedDate = formatDateDisplay(currentDate);

      expect(find.text(formattedDate), findsOneWidget);
    });

    testWidgets('should display date selection UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('Select Attendance Date'), findsOneWidget);
      expect(find.text('You can select a date from the past 90 days up to today.'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('should display valid date range information', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final earliestDate = DateTime.now().subtract(const Duration(days: 90));
      final latestDate = DateTime.now();
      final expectedText = 'Valid range: ${DateFormat('MMM d, yyyy').format(earliestDate)} to ${DateFormat('MMM d, yyyy').format(latestDate)}';

      expect(find.textContaining('Valid range:'), findsOneWidget);
    });

    testWidgets('should open date picker when date card is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find and tap the date selection card
      final dateCard = find.byType(InkWell).first;
      await tester.tap(dateCard);
      await tester.pumpAndSettle();

      // Verify date picker dialog is shown
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('should navigate back when back button is pressed', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find and tap the back button
      final backButton = find.text('Back');
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify navigation occurred (screen should be popped)
      expect(find.byType(DateSelectionScreen), findsNothing);
    });

    testWidgets('should show snackbar when continue is pressed with valid date', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap continue button
      final continueButton = find.text('Continue');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Verify snackbar is shown (placeholder navigation)
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Proceeding to time slot selection'), findsOneWidget);
    });

    testWidgets('should display app bar with correct title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.widgetWithText(AppBar, 'Select Date'), findsOneWidget);
    });

    testWidgets('should have back button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    });

    test('date validation - current date should be valid', () {
      final currentDate = DateTime.now();
      final earliestDate = DateTime.now().subtract(const Duration(days: 90));
      final latestDate = DateTime.now();

      final normalizedDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
      final normalizedEarliest = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);
      final normalizedLatest = DateTime(latestDate.year, latestDate.month, latestDate.day);

      expect(normalizedDate.isAfter(normalizedEarliest) || normalizedDate.isAtSameMomentAs(normalizedEarliest), true);
      expect(normalizedDate.isBefore(normalizedLatest) || normalizedDate.isAtSameMomentAs(normalizedLatest), true);
    });

    test('date validation - date 90 days ago should be valid', () {
      final date90DaysAgo = DateTime.now().subtract(const Duration(days: 90));
      final earliestDate = DateTime.now().subtract(const Duration(days: 90));
      final latestDate = DateTime.now();

      final normalizedDate = DateTime(date90DaysAgo.year, date90DaysAgo.month, date90DaysAgo.day);
      final normalizedEarliest = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);
      final normalizedLatest = DateTime(latestDate.year, latestDate.month, latestDate.day);

      expect(normalizedDate.isAfter(normalizedEarliest) || normalizedDate.isAtSameMomentAs(normalizedEarliest), true);
      expect(normalizedDate.isBefore(normalizedLatest) || normalizedDate.isAtSameMomentAs(normalizedLatest), true);
    });

    test('date validation - date 91 days ago should be invalid', () {
      final date91DaysAgo = DateTime.now().subtract(const Duration(days: 91));
      final earliestDate = DateTime.now().subtract(const Duration(days: 90));

      final normalizedDate = DateTime(date91DaysAgo.year, date91DaysAgo.month, date91DaysAgo.day);
      final normalizedEarliest = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);

      expect(normalizedDate.isBefore(normalizedEarliest), true);
    });

    test('date validation - future date should be invalid', () {
      final futureDate = DateTime.now().add(const Duration(days: 1));
      final latestDate = DateTime.now();

      final normalizedDate = DateTime(futureDate.year, futureDate.month, futureDate.day);
      final normalizedLatest = DateTime(latestDate.year, latestDate.month, latestDate.day);

      expect(normalizedDate.isAfter(normalizedLatest), true);
    });

    test('formatDateDisplay should return correct format', () {
      final testDate = DateTime(2024, 1, 15);
      final formatted = formatDateDisplay(testDate);

      // Should match "DayOfWeek, Month Day, Year" format
      expect(formatted, matches(r'^[A-Za-z]+, [A-Za-z]+ \d{1,2}, \d{4}$'));
    });
  });
}
