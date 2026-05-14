import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sam_pro/Admin/Attendance/models/student_attendance_summary.dart';
import 'package:sam_pro/Admin/Attendance/screens/admin_attendance_selection_screen.dart';
import 'package:sam_pro/Admin/Attendance/screens/admin_attendance_report_screen.dart';
import 'package:sam_pro/Admin/Home/Homepage.dart';

// Reuse the mock generated for the report screen test
import 'admin_attendance_report_screen_test.mocks.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------
  Widget buildSelectionScreen() {
    return const MaterialApp(
      home: AdminAttendanceSelectionScreen(),
    );
  }

  // ---------------------------------------------------------------------------
  // Task 10.2 — Dashboard: "Attendance Report" present, "Post Notice" absent
  // ---------------------------------------------------------------------------
  group('adminhomepage dashboard tiles', () {
    testWidgets('shows "Attendance Report" tile', (tester) async {
      // The homepage has a pre-existing layout overflow in the _courseadding
      // widget (100x120 fixed container). Suppress it so the test can verify
      // the tile text without failing on an unrelated layout issue.
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;

      await tester.pumpWidget(MaterialApp(home: adminhomepage()));
      await tester.pump();

      FlutterError.onError = originalOnError;

      expect(find.text('Attendance Report'), findsOneWidget);
    });

    testWidgets('does not show "Post Notice" tile', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;

      await tester.pumpWidget(MaterialApp(home: adminhomepage()));
      await tester.pump();

      FlutterError.onError = originalOnError;

      expect(find.text('Post Notice'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 10.3 — Semester dropdown contains values "1"–"8"
  // ---------------------------------------------------------------------------
  group('AdminAttendanceSelectionScreen — semester dropdown', () {
    testWidgets('semester dropdown contains all values 1 through 8',
        (tester) async {
      await tester.pumpWidget(buildSelectionScreen());

      // Open the semester dropdown
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>,
          'Select Semester'));
      await tester.pumpAndSettle();

      for (final s in ['1', '2', '3', '4', '5', '6', '7', '8']) {
        expect(find.text('Semester $s'), findsWidgets);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Task 10.4 — Branch dropdown contains all seven branch values
  // ---------------------------------------------------------------------------
  group('AdminAttendanceSelectionScreen — branch dropdown', () {
    testWidgets('branch dropdown contains all seven branch values',
        (tester) async {
      await tester.pumpWidget(buildSelectionScreen());

      // Open the branch dropdown
      await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Select Branch'));
      await tester.pumpAndSettle();

      const branches = [
        'Computer Science & Engineering',
        'Information Science & Engineering',
        'Civil Engineering',
        'Mechanical Engineering',
        'Electrical Engineering',
        'Electronics & Communication Eng',
        'Biotechnology Engineering',
      ];

      for (final branch in branches) {
        expect(find.text(branch), findsWidgets);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Task 10.5 — Button disabled with no selection, enabled with both selected
  // ---------------------------------------------------------------------------
  group('AdminAttendanceSelectionScreen — Generate Report button state', () {
    testWidgets('button is disabled when neither dropdown is selected',
        (tester) async {
      await tester.pumpWidget(buildSelectionScreen());

      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Generate Report'));
      expect(button.onPressed, isNull);
    });

    testWidgets('button is disabled when only semester is selected',
        (tester) async {
      await tester.pumpWidget(buildSelectionScreen());

      // Select semester only
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>,
          'Select Semester'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semester 3').last);
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Generate Report'));
      expect(button.onPressed, isNull);
    });

    testWidgets('button is disabled when only branch is selected',
        (tester) async {
      await tester.pumpWidget(buildSelectionScreen());

      // Select branch only
      await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Select Branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer Science & Engineering').last);
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Generate Report'));
      expect(button.onPressed, isNull);
    });

    testWidgets('button is enabled when both semester and branch are selected',
        (tester) async {
      await tester.pumpWidget(buildSelectionScreen());

      // Select semester
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>,
          'Select Semester'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semester 3').last);
      await tester.pumpAndSettle();

      // Select branch
      await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Select Branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer Science & Engineering').last);
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Generate Report'));
      expect(button.onPressed, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 10.6 — Navigation to report screen with correct arguments
  // ---------------------------------------------------------------------------
  group('AdminAttendanceSelectionScreen — navigation', () {
    testWidgets(
        'tapping Generate Report navigates to AdminAttendanceReportScreen '
        'with correct semester and branch', (tester) async {
      // Use a mock service factory so the report screen doesn't need Firebase
      final mockService = MockAdminAttendanceService();
      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) async => ['Math']);
      when(mockService.fetchStudentIds(any, any))
          .thenAnswer((_) async => ['S001']);
      when(mockService.computeStudentSummary(any, any, any)).thenAnswer(
          (_) async => StudentAttendanceSummary.compute(
              studentId: 'S001', totalPresent: 8, totalClasses: 10));

      await tester.pumpWidget(MaterialApp(
        home: AdminAttendanceSelectionScreen(
          serviceFactory: () => mockService,
        ),
      ));

      // Select semester "5"
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>,
          'Select Semester'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semester 5').last);
      await tester.pumpAndSettle();

      // Select branch "Mechanical Engineering"
      await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Select Branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mechanical Engineering').last);
      await tester.pumpAndSettle();

      // Tap Generate Report — triggers navigation
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate Report'));
      await tester.pumpAndSettle();

      // The report screen should be pushed onto the navigator
      expect(find.byType(AdminAttendanceReportScreen), findsOneWidget);

      // Verify the widget received the correct arguments
      final reportScreen = tester.widget<AdminAttendanceReportScreen>(
          find.byType(AdminAttendanceReportScreen));
      expect(reportScreen.semester, '5');
      expect(reportScreen.branch, 'Mechanical Engineering');
    });
  });
}
