import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sam_pro/Admin/Attendance/models/student_attendance_summary.dart';
import 'package:sam_pro/Admin/Attendance/screens/admin_attendance_report_screen.dart';
import 'package:sam_pro/Admin/Attendance/services/admin_attendance_service.dart';

import 'admin_attendance_report_screen_test.mocks.dart';

@GenerateMocks([AdminAttendanceService])
void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget buildReportScreen({
    required AdminAttendanceService service,
    String semester = '3',
    String branch = 'Computer Science & Engineering',
  }) {
    return MaterialApp(
      home: AdminAttendanceReportScreen(
        semester: semester,
        branch: branch,
        service: service,
      ),
    );
  }

  StudentAttendanceSummary makeSummary(
    String id, {
    int present = 8,
    int total = 10,
  }) =>
      StudentAttendanceSummary.compute(
        studentId: id,
        totalPresent: present,
        totalClasses: total,
      );

  // ---------------------------------------------------------------------------
  // Task 10.8 — Loading indicator shown during data fetch
  // ---------------------------------------------------------------------------
  group('AdminAttendanceReportScreen — loading state', () {
    testWidgets('shows CircularProgressIndicator while data is loading',
        (tester) async {
      final mockService = MockAdminAttendanceService();

      // Never completes during the test — keeps the screen in loading state
      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) => Completer<List<String>>().future);

      await tester.pumpWidget(buildReportScreen(service: mockService));
      // pump once to trigger initState / setState(_isLoading = true)
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 10.9 — Error message and Retry button on service failure
  // ---------------------------------------------------------------------------
  group('AdminAttendanceReportScreen — error state', () {
    testWidgets('shows error message and Retry button when fetchCourseNames throws',
        (tester) async {
      final mockService = MockAdminAttendanceService();

      when(mockService.fetchCourseNames(any, any))
          .thenThrow(Exception('network error'));

      await tester.pumpWidget(buildReportScreen(service: mockService));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('shows error message and Retry button when fetchStudentIds throws',
        (tester) async {
      final mockService = MockAdminAttendanceService();

      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) async => ['Math']);
      when(mockService.fetchStudentIds(any, any))
          .thenThrow(Exception('db error'));

      await tester.pumpWidget(buildReportScreen(service: mockService));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('Retry button re-invokes load and shows data on success',
        (tester) async {
      final mockService = MockAdminAttendanceService();
      var callCount = 0;

      when(mockService.fetchCourseNames(any, any)).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('first call fails');
        return ['Math'];
      });
      when(mockService.fetchStudentIds(any, any))
          .thenAnswer((_) async => ['S001']);
      when(mockService.computeStudentSummary(any, any, any))
          .thenAnswer((_) async => makeSummary('S001'));

      await tester.pumpWidget(buildReportScreen(service: mockService));
      await tester.pumpAndSettle();

      // First load fails — Retry button visible
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();

      // Second load succeeds — student row visible
      expect(find.text('S001'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 10.10 — "No courses" and "No students" messages for empty results
  // ---------------------------------------------------------------------------
  group('AdminAttendanceReportScreen — empty result messages', () {
    testWidgets('shows "No courses" message when course list is empty',
        (tester) async {
      final mockService = MockAdminAttendanceService();

      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(buildReportScreen(service: mockService));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No courses found'),
        findsOneWidget,
      );
    });

    testWidgets('shows "No students" message when student list is empty',
        (tester) async {
      final mockService = MockAdminAttendanceService();

      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) async => ['Math']);
      when(mockService.fetchStudentIds(any, any))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(buildReportScreen(service: mockService));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No students enrolled'),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Task 10.11 — Header displays semester and branch
  // ---------------------------------------------------------------------------
  group('AdminAttendanceReportScreen — header', () {
    testWidgets('displays semester and branch in the header', (tester) async {
      final mockService = MockAdminAttendanceService();

      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) async => ['Math']);
      when(mockService.fetchStudentIds(any, any))
          .thenAnswer((_) async => ['S001']);
      when(mockService.computeStudentSummary(any, any, any))
          .thenAnswer((_) async => makeSummary('S001'));

      await tester.pumpWidget(buildReportScreen(
        service: mockService,
        semester: '5',
        branch: 'Mechanical Engineering',
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Semester: 5'), findsOneWidget);
      expect(find.textContaining('Branch: Mechanical Engineering'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Additional: data display — student rows, percentage colour
  // ---------------------------------------------------------------------------
  group('AdminAttendanceReportScreen — data display', () {
    testWidgets('renders one ListTile per student with formatted percentage',
        (tester) async {
      final mockService = MockAdminAttendanceService();

      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) async => ['Math']);
      when(mockService.fetchStudentIds(any, any))
          .thenAnswer((_) async => ['S001', 'S002']);
      when(mockService.computeStudentSummary('S001', any, any))
          .thenAnswer((_) async => makeSummary('S001', present: 8, total: 10));
      when(mockService.computeStudentSummary('S002', any, any))
          .thenAnswer((_) async => makeSummary('S002', present: 5, total: 10));

      await tester.pumpWidget(buildReportScreen(service: mockService));
      await tester.pumpAndSettle();

      expect(find.text('S001'), findsOneWidget);
      expect(find.text('S002'), findsOneWidget);
      expect(find.text('80.00%'), findsOneWidget);
      expect(find.text('50.00%'), findsOneWidget);
    });

    testWidgets('percentage text is green when >= 75%', (tester) async {
      final mockService = MockAdminAttendanceService();

      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) async => ['Math']);
      when(mockService.fetchStudentIds(any, any))
          .thenAnswer((_) async => ['S001']);
      when(mockService.computeStudentSummary(any, any, any))
          .thenAnswer((_) async => makeSummary('S001', present: 8, total: 10)); // 80%

      await tester.pumpWidget(buildReportScreen(service: mockService));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('80.00%'));
      expect(text.style?.color, Colors.green);
    });

    testWidgets('percentage text is red when < 75%', (tester) async {
      final mockService = MockAdminAttendanceService();

      when(mockService.fetchCourseNames(any, any))
          .thenAnswer((_) async => ['Math']);
      when(mockService.fetchStudentIds(any, any))
          .thenAnswer((_) async => ['S001']);
      when(mockService.computeStudentSummary(any, any, any))
          .thenAnswer((_) async =>
              makeSummary('S001', present: 7, total: 10)); // 70%

      await tester.pumpWidget(buildReportScreen(service: mockService));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('70.00%'));
      expect(text.style?.color, Colors.red);
    });
  });
}
