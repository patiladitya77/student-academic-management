import 'package:flutter_test/flutter_test.dart';
import 'package:sam_pro/Admin/Attendance/models/student_attendance_summary.dart';

void main() {
  group('StudentAttendanceSummary - percentage calculation', () {
    // Task 7.2: Test percentage calculation with known present/total values

    test('12 out of 15 classes gives 80.00%', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S001',
        totalPresent: 12,
        totalClasses: 15,
      );

      expect(summary.attendancePercentage, 80.00);
      expect(summary.totalPresent, 12);
      expect(summary.totalClasses, 15);
    });

    test('3 out of 4 classes gives 75.00%', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S002',
        totalPresent: 3,
        totalClasses: 4,
      );

      expect(summary.attendancePercentage, 75.00);
    });

    test('10 out of 10 classes gives 100.00%', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S003',
        totalPresent: 10,
        totalClasses: 10,
      );

      expect(summary.attendancePercentage, 100.00);
    });

    test('0 out of 10 classes gives 0.00%', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S004',
        totalPresent: 0,
        totalClasses: 10,
      );

      expect(summary.attendancePercentage, 0.00);
    });

    test('studentId is stored correctly', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'CS21001',
        totalPresent: 8,
        totalClasses: 10,
      );

      expect(summary.studentId, 'CS21001');
    });
  });

  group('StudentAttendanceSummary - zero-class edge case', () {
    // Task 7.3: Test zero-class edge case returns 0.0

    test('zero totalClasses returns attendancePercentage of 0.0', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S005',
        totalPresent: 0,
        totalClasses: 0,
      );

      expect(summary.attendancePercentage, 0.0);
    });

    test('zero totalClasses with non-zero totalPresent still returns 0.0', () {
      // Guard against division by zero — totalPresent is irrelevant when
      // totalClasses is 0.
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S006',
        totalPresent: 5,
        totalClasses: 0,
      );

      expect(summary.attendancePercentage, 0.0);
    });

    test('zero totalClasses stores the raw field values unchanged', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S007',
        totalPresent: 0,
        totalClasses: 0,
      );

      expect(summary.totalPresent, 0);
      expect(summary.totalClasses, 0);
    });
  });

  group('StudentAttendanceSummary - two-decimal rounding', () {
    // Task 7.4: Test two-decimal rounding

    test('1 out of 3 classes rounds to 33.33%', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S008',
        totalPresent: 1,
        totalClasses: 3,
      );

      expect(summary.attendancePercentage, 33.33);
    });

    test('2 out of 3 classes rounds to 66.67%', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S009',
        totalPresent: 2,
        totalClasses: 3,
      );

      expect(summary.attendancePercentage, 66.67);
    });

    test('1 out of 6 classes rounds to 16.67%', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S010',
        totalPresent: 1,
        totalClasses: 6,
      );

      expect(summary.attendancePercentage, 16.67);
    });

    test('5 out of 6 classes rounds to 83.33%', () {
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S011',
        totalPresent: 5,
        totalClasses: 6,
      );

      expect(summary.attendancePercentage, 83.33);
    });

    test('percentage has at most two decimal places', () {
      // 1/7 = 14.285714... should be stored as 14.29
      final summary = StudentAttendanceSummary.compute(
        studentId: 'S012',
        totalPresent: 1,
        totalClasses: 7,
      );

      // Verify the value matches the two-decimal rounded result
      final expected = double.parse(
        (1 / 7 * 100).toStringAsFixed(2),
      );
      expect(summary.attendancePercentage, expected);
    });
  });

  group('StudentAttendanceSummary - const constructor', () {
    test('direct construction stores provided attendancePercentage as-is', () {
      const summary = StudentAttendanceSummary(
        studentId: 'S013',
        totalPresent: 7,
        totalClasses: 10,
        attendancePercentage: 70.00,
      );

      expect(summary.studentId, 'S013');
      expect(summary.totalPresent, 7);
      expect(summary.totalClasses, 10);
      expect(summary.attendancePercentage, 70.00);
    });
  });
}
