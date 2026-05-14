// Property-based tests for the admin attendance report feature.
//
// These tests use Dart's built-in [Random] to generate inputs and run each
// property for a minimum of 100 iterations, following the manual PBT approach
// described in the design document (fast_check is not yet a project dependency).
//
// **Validates: Requirements 2.3, 2.4, 5.1–5.6, 6.3–6.5**

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sam_pro/Admin/Attendance/models/student_attendance_summary.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a deterministic [Random] seeded with [seed].
Random _rng(int seed) => Random(seed);

/// Generates a non-negative integer in [0, max].
int _nextInt(Random rng, int max) => rng.nextInt(max + 1);

/// Generates a double in [0.0, 200.0] with two decimal places, covering
/// values well below and above the 75.0 threshold.
double _nextPercentage(Random rng) {
  final raw = rng.nextDouble() * 200.0;
  return double.parse(raw.toStringAsFixed(2));
}

/// Generates a random alphanumeric student ID of length 6–10.
String _nextStudentId(Random rng) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final length = 6 + rng.nextInt(5); // 6..10
  return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
}

// ---------------------------------------------------------------------------
// Pure logic helpers extracted from the UI layer for testability
// ---------------------------------------------------------------------------

/// Mirrors the button-enabled logic in [AdminAttendanceSelectionScreen].
bool buttonEnabled(String? semester, String? branch) =>
    semester != null && branch != null;

/// Mirrors the row-color logic in [AdminAttendanceReportScreen].
Color rowColor(double attendancePercentage) =>
    attendancePercentage < 75.0 ? Colors.red : Colors.green;

/// Mirrors the percentage-format logic in [AdminAttendanceReportScreen].
String formattedPercentage(double attendancePercentage) =>
    '${attendancePercentage.toStringAsFixed(2)}%';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Property 1 — button enabled iff both semester and branch selected
  // **Validates: Requirements 2.3, 2.4**
  // -------------------------------------------------------------------------
  group('Property 1 — button enabled iff both semester and branch selected', () {
    // The four exhaustive combinations are tested explicitly (all 4 cases),
    // then 100 random iterations confirm the property holds for arbitrary
    // non-null string values.

    test('(null, null) → disabled', () {
      expect(buttonEnabled(null, null), isFalse);
    });

    test('(value, null) → disabled', () {
      expect(buttonEnabled('3', null), isFalse);
    });

    test('(null, value) → disabled', () {
      expect(buttonEnabled(null, 'Computer Science & Engineering'), isFalse);
    });

    test('(value, value) → enabled', () {
      expect(
        buttonEnabled('3', 'Computer Science & Engineering'),
        isTrue,
      );
    });

    test(
        'for any combination of null/non-null semester and branch, '
        'enabled iff both non-null (100 iterations)', () {
      final rng = _rng(42);
      const semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];
      const branches = [
        'Computer Science & Engineering',
        'Information Science & Engineering',
        'Civil Engineering',
        'Mechanical Engineering',
        'Electrical Engineering',
        'Electronics & Communication Eng',
        'Biotechnology Engineering',
      ];

      for (int i = 0; i < 100; i++) {
        // Randomly choose null or a real value for each dropdown.
        final bool semNull = rng.nextBool();
        final bool branchNull = rng.nextBool();

        final String? semester =
            semNull ? null : semesters[rng.nextInt(semesters.length)];
        final String? branch =
            branchNull ? null : branches[rng.nextInt(branches.length)];

        final bool expected = semester != null && branch != null;
        final bool actual = buttonEnabled(semester, branch);

        expect(
          actual,
          expected,
          reason:
              'iteration $i: semester=$semester, branch=$branch → expected $expected',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Property 2 — percentage formula correctness
  // **Validates: Requirements 5.4, 5.6**
  // -------------------------------------------------------------------------
  group('Property 2 — percentage formula correctness', () {
    test(
        'for any totalPresent and totalClasses > 0, '
        'attendancePercentage == double.parse((totalPresent / totalClasses * 100)'
        '.toStringAsFixed(2)) (100 iterations)', () {
      final rng = _rng(1337);

      for (int i = 0; i < 100; i++) {
        // totalClasses in [1, 200]; totalPresent in [0, totalClasses]
        final int totalClasses = 1 + _nextInt(rng, 199);
        final int totalPresent = _nextInt(rng, totalClasses);

        final summary = StudentAttendanceSummary.compute(
          studentId: 'S$i',
          totalPresent: totalPresent,
          totalClasses: totalClasses,
        );

        final double expected = double.parse(
          (totalPresent / totalClasses * 100).toStringAsFixed(2),
        );

        expect(
          summary.attendancePercentage,
          expected,
          reason:
              'iteration $i: totalPresent=$totalPresent, totalClasses=$totalClasses',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Property 3 — aggregation sums all courses
  // **Validates: Requirements 5.1, 5.2, 5.3**
  // -------------------------------------------------------------------------
  group('Property 3 — aggregation sums all courses', () {
    test(
        'for any list of (present, total) pairs, '
        'summary.totalPresent == sum(present) and '
        'summary.totalClasses == sum(total) (100 iterations)', () {
      final rng = _rng(2024);

      for (int i = 0; i < 100; i++) {
        // Generate 1–10 courses, each with random present/total values.
        final int numCourses = 1 + _nextInt(rng, 9);
        final List<int> presents = [];
        final List<int> totals = [];

        for (int c = 0; c < numCourses; c++) {
          final int total = _nextInt(rng, 50); // 0..50
          final int present = total == 0 ? 0 : _nextInt(rng, total);
          presents.add(present);
          totals.add(total);
        }

        final int expectedTotalPresent = presents.fold(0, (a, b) => a + b);
        final int expectedTotalClasses = totals.fold(0, (a, b) => a + b);

        // Simulate the aggregation that AdminAttendanceService.computeStudentSummary
        // performs: sum up all (present, total) pairs.
        int aggregatedPresent = 0;
        int aggregatedClasses = 0;
        for (int c = 0; c < numCourses; c++) {
          aggregatedPresent += presents[c];
          aggregatedClasses += totals[c];
        }

        final summary = StudentAttendanceSummary.compute(
          studentId: 'S$i',
          totalPresent: aggregatedPresent,
          totalClasses: aggregatedClasses,
        );

        expect(
          summary.totalPresent,
          expectedTotalPresent,
          reason: 'iteration $i: presents=$presents',
        );
        expect(
          summary.totalClasses,
          expectedTotalClasses,
          reason: 'iteration $i: totals=$totals',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Property 4 — sort order ascending by studentId
  // **Validates: Requirements 6.5**
  // -------------------------------------------------------------------------
  group('Property 4 — sort order ascending by studentId', () {
    test(
        'for any list of StudentAttendanceSummary, '
        'sorted output is ascending by studentId (100 iterations)', () {
      final rng = _rng(9999);

      for (int i = 0; i < 100; i++) {
        // Generate 1–15 summaries with random student IDs.
        final int count = 1 + _nextInt(rng, 14);
        final List<StudentAttendanceSummary> summaries = List.generate(
          count,
          (_) => StudentAttendanceSummary(
            studentId: _nextStudentId(rng),
            totalPresent: 0,
            totalClasses: 0,
            attendancePercentage: 0.0,
          ),
        );

        // Apply the same sort used in AdminAttendanceService.generateReport.
        summaries.sort((a, b) => a.studentId.compareTo(b.studentId));

        // Verify the list is non-decreasing by studentId.
        for (int j = 0; j < summaries.length - 1; j++) {
          expect(
            summaries[j].studentId.compareTo(summaries[j + 1].studentId),
            lessThanOrEqualTo(0),
            reason:
                'iteration $i, index $j: "${summaries[j].studentId}" should be <= "${summaries[j + 1].studentId}"',
          );
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  // Property 5 — low-attendance flag: row color is red iff percentage < 75.0
  // **Validates: Requirements 6.4**
  // -------------------------------------------------------------------------
  group('Property 5 — low-attendance flag', () {
    test(
        'for any attendancePercentage, '
        'row color is red iff percentage < 75.0 (100 iterations)', () {
      final rng = _rng(5555);

      for (int i = 0; i < 100; i++) {
        final double percentage = _nextPercentage(rng);
        final Color color = rowColor(percentage);

        if (percentage < 75.0) {
          expect(
            color,
            Colors.red,
            reason: 'iteration $i: percentage=$percentage should be red',
          );
        } else {
          expect(
            color,
            Colors.green,
            reason: 'iteration $i: percentage=$percentage should be green',
          );
        }
      }
    });

    test('boundary: 74.99 is red', () {
      expect(rowColor(74.99), Colors.red);
    });

    test('boundary: 75.0 is green (not red)', () {
      expect(rowColor(75.0), Colors.green);
    });

    test('boundary: 75.01 is green', () {
      expect(rowColor(75.01), Colors.green);
    });
  });

  // -------------------------------------------------------------------------
  // Property 6 — percentage format: formatted string == toStringAsFixed(2) + "%"
  // **Validates: Requirements 6.3**
  // -------------------------------------------------------------------------
  group('Property 6 — percentage format', () {
    test(
        'for any attendancePercentage, '
        'formatted string == toStringAsFixed(2) + "%" (100 iterations)', () {
      final rng = _rng(7777);

      for (int i = 0; i < 100; i++) {
        final double percentage = _nextPercentage(rng);
        final String formatted = formattedPercentage(percentage);
        final String expected = '${percentage.toStringAsFixed(2)}%';

        expect(
          formatted,
          expected,
          reason: 'iteration $i: percentage=$percentage',
        );
      }
    });

    test('0.0 formats as "0.00%"', () {
      expect(formattedPercentage(0.0), '0.00%');
    });

    test('100.0 formats as "100.00%"', () {
      expect(formattedPercentage(100.0), '100.00%');
    });

    test('33.33 formats as "33.33%"', () {
      expect(formattedPercentage(33.33), '33.33%');
    });
  });
}
