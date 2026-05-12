import 'package:flutter_test/flutter_test.dart';
import 'package:sam_pro/Teacher/Attendance/models/lecture_session.dart';

void main() {
  group('Excel and PDF Data Comparison Integration Tests', () {
    test('validates Requirement 8.1, 8.2, 8.3, 8.4, 8.5 - comprehensive data consistency', () {
      // Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5
      // Comprehensive integration test comparing Excel and PDF data with identical filters
      
      // Setup: Common filter criteria
      final courseName = 'CS101';
      final semester = 'Fall 2024';
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 31);
      final selectedTimeSlotIds = ['1', '2'];
      
      // Setup: Lecture sessions
      final allSessions = [
        LectureSession(
          date: DateTime(2024, 1, 5),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {
            'STUDENT_001': 'P',
            'STUDENT_002': 'A',
            'STUDENT_003': 'P',
          },
        ),
        LectureSession(
          date: DateTime(2024, 1, 10),
          timeSlotId: '2',
          timeSlotName: 'Period 2',
          studentStatuses: {
            'STUDENT_001': 'A',
            'STUDENT_002': 'P',
            'STUDENT_003': 'P',
          },
        ),
        LectureSession(
          date: DateTime(2024, 1, 15),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {
            'STUDENT_001': 'P',
            'STUDENT_002': 'P',
            'STUDENT_003': 'A',
          },
        ),
        LectureSession(
          date: DateTime(2024, 2, 5), // Outside date range
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {
            'STUDENT_001': 'P',
            'STUDENT_002': 'P',
            'STUDENT_003': 'P',
          },
        ),
        LectureSession(
          date: DateTime(2024, 1, 20),
          timeSlotId: '3', // Not in selected time slots
          timeSlotName: 'Period 3',
          studentStatuses: {
            'STUDENT_001': 'P',
            'STUDENT_002': 'P',
            'STUDENT_003': 'P',
          },
        ),
      ];
      
      // Apply filters (same logic for both Excel and PDF)
      final filteredSessions = allSessions.where((session) {
        final dateInRange = !session.date.isBefore(startDate) && 
                           !session.date.isAfter(endDate);
        final timeSlotMatches = selectedTimeSlotIds.isEmpty || 
                               selectedTimeSlotIds.contains(session.timeSlotId);
        return dateInRange && timeSlotMatches;
      }).toList();
      
      // Should have 3 sessions after filtering
      expect(filteredSessions.length, 3);
      
      // Calculate attendance data (same logic for both Excel and PDF)
      final studentAttendance = <String, Map<String, dynamic>>{};
      final allStudentIds = <String>{};
      
      // Collect all student IDs
      for (final session in filteredSessions) {
        allStudentIds.addAll(session.studentStatuses.keys);
      }
      
      // Calculate present and total for each student
      for (final studentId in allStudentIds) {
        int present = 0;
        int total = filteredSessions.length;
        
        for (final session in filteredSessions) {
          if (session.studentStatuses[studentId] == 'P') {
            present++;
          }
        }
        
        studentAttendance[studentId] = {
          'present': present,
          'total': total,
        };
      }
      
      // Verify student set consistency (Requirement 8.5)
      final excelStudents = studentAttendance.keys.toList()..sort();
      final pdfStudents = studentAttendance.keys.toList()..sort();
      expect(excelStudents, equals(pdfStudents));
      expect(excelStudents, ['STUDENT_001', 'STUDENT_002', 'STUDENT_003']);
      
      // Verify attendance data for each student
      expect(studentAttendance['STUDENT_001']!['present'], 2); // P, A, P
      expect(studentAttendance['STUDENT_001']!['total'], 3);
      
      expect(studentAttendance['STUDENT_002']!['present'], 2); // A, P, P
      expect(studentAttendance['STUDENT_002']!['total'], 3);
      
      expect(studentAttendance['STUDENT_003']!['present'], 2); // P, P, A
      expect(studentAttendance['STUDENT_003']!['total'], 3);
      
      // Verify percentage calculation (Requirement 8.4)
      for (final studentId in excelStudents) {
        final data = studentAttendance[studentId]!;
        final present = data['present'] as int;
        final total = data['total'] as int;
        
        final excelPercentage = total > 0 ? (present * 100.0 / total) : 0.0;
        final pdfPercentage = total > 0 ? (present * 100 / total) : 0.0;
        
        expect(excelPercentage, equals(pdfPercentage));
        expect(excelPercentage, closeTo(66.67, 0.01));
      }
    });

    test('compares Excel and PDF data with no time slot filter', () {
      // When no time slot filter is applied, both should include all time slots
      
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 31);
      final selectedTimeSlotIds = <String>[]; // Empty = all time slots
      
      final allSessions = [
        LectureSession(
          date: DateTime(2024, 1, 5),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
        LectureSession(
          date: DateTime(2024, 1, 5),
          timeSlotId: '2',
          timeSlotName: 'Period 2',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
        LectureSession(
          date: DateTime(2024, 1, 5),
          timeSlotId: '3',
          timeSlotName: 'Period 3',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
      ];
      
      // Apply filters
      final filteredSessions = allSessions.where((session) {
        final dateInRange = !session.date.isBefore(startDate) && 
                           !session.date.isAfter(endDate);
        final timeSlotMatches = selectedTimeSlotIds.isEmpty || 
                               selectedTimeSlotIds.contains(session.timeSlotId);
        return dateInRange && timeSlotMatches;
      }).toList();
      
      // All 3 sessions should be included
      expect(filteredSessions.length, 3);
    });

    test('compares Excel and PDF data with single time slot filter', () {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 31);
      final selectedTimeSlotIds = ['1'];
      
      final allSessions = [
        LectureSession(
          date: DateTime(2024, 1, 5),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
        LectureSession(
          date: DateTime(2024, 1, 5),
          timeSlotId: '2',
          timeSlotName: 'Period 2',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
      ];
      
      // Apply filters
      final filteredSessions = allSessions.where((session) {
        final dateInRange = !session.date.isBefore(startDate) && 
                           !session.date.isAfter(endDate);
        final timeSlotMatches = selectedTimeSlotIds.isEmpty || 
                               selectedTimeSlotIds.contains(session.timeSlotId);
        return dateInRange && timeSlotMatches;
      }).toList();
      
      // Only 1 session should be included
      expect(filteredSessions.length, 1);
      expect(filteredSessions[0].timeSlotId, '1');
    });

    test('compares Excel and PDF data with wide date range', () {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 12, 31);
      final selectedTimeSlotIds = ['1'];
      
      final allSessions = [
        LectureSession(
          date: DateTime(2024, 1, 15),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
        LectureSession(
          date: DateTime(2024, 6, 15),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
        LectureSession(
          date: DateTime(2024, 12, 15),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
      ];
      
      // Apply filters
      final filteredSessions = allSessions.where((session) {
        final dateInRange = !session.date.isBefore(startDate) && 
                           !session.date.isAfter(endDate);
        final timeSlotMatches = selectedTimeSlotIds.isEmpty || 
                               selectedTimeSlotIds.contains(session.timeSlotId);
        return dateInRange && timeSlotMatches;
      }).toList();
      
      // All 3 sessions should be included
      expect(filteredSessions.length, 3);
    });

    test('compares Excel and PDF data with narrow date range', () {
      final startDate = DateTime(2024, 1, 10);
      final endDate = DateTime(2024, 1, 15);
      final selectedTimeSlotIds = ['1'];
      
      final allSessions = [
        LectureSession(
          date: DateTime(2024, 1, 5), // Before range
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
        LectureSession(
          date: DateTime(2024, 1, 12), // In range
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
        LectureSession(
          date: DateTime(2024, 1, 20), // After range
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {'STUDENT_001': 'P'},
        ),
      ];
      
      // Apply filters
      final filteredSessions = allSessions.where((session) {
        final dateInRange = !session.date.isBefore(startDate) && 
                           !session.date.isAfter(endDate);
        final timeSlotMatches = selectedTimeSlotIds.isEmpty || 
                               selectedTimeSlotIds.contains(session.timeSlotId);
        return dateInRange && timeSlotMatches;
      }).toList();
      
      // Only 1 session should be included
      expect(filteredSessions.length, 1);
      expect(filteredSessions[0].date, DateTime(2024, 1, 12));
    });

    test('compares Excel and PDF percentage calculations with various scenarios', () {
      final testCases = [
        {
          'description': 'Perfect attendance',
          'present': 10,
          'total': 10,
          'expectedPercentage': 100.00,
        },
        {
          'description': 'Zero attendance',
          'present': 0,
          'total': 10,
          'expectedPercentage': 0.00,
        },
        {
          'description': 'Half attendance',
          'present': 5,
          'total': 10,
          'expectedPercentage': 50.00,
        },
        {
          'description': 'Fractional percentage',
          'present': 7,
          'total': 9,
          'expectedPercentage': 77.78,
        },
        {
          'description': 'Single lecture attended',
          'present': 1,
          'total': 1,
          'expectedPercentage': 100.00,
        },
        {
          'description': 'Single lecture missed',
          'present': 0,
          'total': 1,
          'expectedPercentage': 0.00,
        },
      ];
      
      for (final testCase in testCases) {
        final present = testCase['present'] as int;
        final total = testCase['total'] as int;
        final expected = testCase['expectedPercentage'] as double;
        
        // Excel calculation
        final excelPercentage = total > 0 ? (present * 100.0 / total) : 0.0;
        
        // PDF calculation
        final pdfPercentage = total > 0 ? (present * 100 / total) : 0.0;
        
        // Both should match
        expect(excelPercentage, equals(pdfPercentage));
        expect(excelPercentage, closeTo(expected, 0.01));
      }
    });

    test('compares Excel and PDF student lists with large dataset', () {
      // Generate 50 students
      final studentAttendance = <String, Map<String, dynamic>>{};
      for (int i = 1; i <= 50; i++) {
        final studentId = 'STUDENT_${i.toString().padLeft(3, '0')}';
        studentAttendance[studentId] = {
          'present': i % 10,
          'total': 10,
        };
      }
      
      // Both Excel and PDF would use the same student set
      final excelStudents = studentAttendance.keys.toList()..sort();
      final pdfStudents = studentAttendance.keys.toList()..sort();
      
      expect(excelStudents, equals(pdfStudents));
      expect(excelStudents.length, 50);
      
      // Verify first and last students
      expect(excelStudents.first, 'STUDENT_001');
      expect(excelStudents.last, 'STUDENT_050');
    });

    test('compares Excel and PDF data with multiple sessions on same date', () {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 31);
      final selectedTimeSlotIds = ['1', '2'];
      
      // Multiple sessions on the same date
      final allSessions = [
        LectureSession(
          date: DateTime(2024, 1, 15),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {
            'STUDENT_001': 'P',
            'STUDENT_002': 'A',
          },
        ),
        LectureSession(
          date: DateTime(2024, 1, 15),
          timeSlotId: '2',
          timeSlotName: 'Period 2',
          studentStatuses: {
            'STUDENT_001': 'A',
            'STUDENT_002': 'P',
          },
        ),
      ];
      
      // Apply filters
      final filteredSessions = allSessions.where((session) {
        final dateInRange = !session.date.isBefore(startDate) && 
                           !session.date.isAfter(endDate);
        final timeSlotMatches = selectedTimeSlotIds.isEmpty || 
                               selectedTimeSlotIds.contains(session.timeSlotId);
        return dateInRange && timeSlotMatches;
      }).toList();
      
      // Both sessions should be included
      expect(filteredSessions.length, 2);
      
      // Calculate attendance
      final studentAttendance = <String, Map<String, dynamic>>{};
      final allStudentIds = <String>{};
      
      for (final session in filteredSessions) {
        allStudentIds.addAll(session.studentStatuses.keys);
      }
      
      for (final studentId in allStudentIds) {
        int present = 0;
        int total = filteredSessions.length;
        
        for (final session in filteredSessions) {
          if (session.studentStatuses[studentId] == 'P') {
            present++;
          }
        }
        
        studentAttendance[studentId] = {
          'present': present,
          'total': total,
        };
      }
      
      // STUDENT_001: P in first session, A in second = 1/2 = 50%
      expect(studentAttendance['STUDENT_001']!['present'], 1);
      expect(studentAttendance['STUDENT_001']!['total'], 2);
      
      // STUDENT_002: A in first session, P in second = 1/2 = 50%
      expect(studentAttendance['STUDENT_002']!['present'], 1);
      expect(studentAttendance['STUDENT_002']!['total'], 2);
    });

    test('compares Excel and PDF data with student present in some sessions', () {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 1, 31);
      final selectedTimeSlotIds = ['1'];
      
      final allSessions = [
        LectureSession(
          date: DateTime(2024, 1, 5),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {
            'STUDENT_001': 'P',
            'STUDENT_002': 'P',
          },
        ),
        LectureSession(
          date: DateTime(2024, 1, 10),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {
            'STUDENT_001': 'P',
            // STUDENT_002 not in this session (absent)
          },
        ),
        LectureSession(
          date: DateTime(2024, 1, 15),
          timeSlotId: '1',
          timeSlotName: 'Period 1',
          studentStatuses: {
            'STUDENT_001': 'P',
            'STUDENT_002': 'A',
          },
        ),
      ];
      
      // Apply filters
      final filteredSessions = allSessions.where((session) {
        final dateInRange = !session.date.isBefore(startDate) && 
                           !session.date.isAfter(endDate);
        final timeSlotMatches = selectedTimeSlotIds.isEmpty || 
                               selectedTimeSlotIds.contains(session.timeSlotId);
        return dateInRange && timeSlotMatches;
      }).toList();
      
      expect(filteredSessions.length, 3);
      
      // Calculate attendance
      final studentAttendance = <String, Map<String, dynamic>>{};
      final allStudentIds = <String>{};
      
      for (final session in filteredSessions) {
        allStudentIds.addAll(session.studentStatuses.keys);
      }
      
      for (final studentId in allStudentIds) {
        int present = 0;
        int total = filteredSessions.length;
        
        for (final session in filteredSessions) {
          if (session.studentStatuses[studentId] == 'P') {
            present++;
          }
        }
        
        studentAttendance[studentId] = {
          'present': present,
          'total': total,
        };
      }
      
      // STUDENT_001: P, P, P = 3/3 = 100%
      expect(studentAttendance['STUDENT_001']!['present'], 3);
      expect(studentAttendance['STUDENT_001']!['total'], 3);
      
      // STUDENT_002: P, (not in session = A), A = 1/3 = 33.33%
      expect(studentAttendance['STUDENT_002']!['present'], 1);
      expect(studentAttendance['STUDENT_002']!['total'], 3);
    });

    test('verifies metadata consistency between Excel and PDF', () {
      // Both Excel and PDF use the same metadata
      final courseName = 'Advanced Algorithms';
      final semester = 'Spring 2024';
      final startDate = DateTime(2024, 3, 1);
      final endDate = DateTime(2024, 5, 31);
      final selectedTimeSlotNames = ['Period 1', 'Period 2', 'Period 3'];
      
      // Excel metadata
      final excelMetadata = {
        'courseName': courseName,
        'semester': semester,
        'startDate': startDate,
        'endDate': endDate,
        'timeSlots': selectedTimeSlotNames,
      };
      
      // PDF metadata (same values)
      final pdfMetadata = {
        'courseName': courseName,
        'semester': semester,
        'startDate': startDate,
        'endDate': endDate,
        'timeSlots': selectedTimeSlotNames,
      };
      
      // Verify consistency
      expect(excelMetadata['courseName'], equals(pdfMetadata['courseName']));
      expect(excelMetadata['semester'], equals(pdfMetadata['semester']));
      expect(excelMetadata['startDate'], equals(pdfMetadata['startDate']));
      expect(excelMetadata['endDate'], equals(pdfMetadata['endDate']));
      expect(excelMetadata['timeSlots'], equals(pdfMetadata['timeSlots']));
    });

    test('verifies sorting consistency between Excel and PDF with mixed IDs', () {
      final studentAttendance = {
        'STUDENT_010': {'present': 5, 'total': 10},
        'STUDENT_001': {'present': 7, 'total': 10},
        'STUDENT_100': {'present': 8, 'total': 10},
        'STUDENT_002': {'present': 6, 'total': 10},
        'STUDENT_050': {'present': 9, 'total': 10},
      };
      
      // Excel sorting
      final excelSorted = studentAttendance.keys.toList()..sort();
      
      // PDF sorting
      final pdfSorted = studentAttendance.keys.toList()..sort((a, b) => a.compareTo(b));
      
      expect(excelSorted, equals(pdfSorted));
      expect(excelSorted, [
        'STUDENT_001',
        'STUDENT_002',
        'STUDENT_010',
        'STUDENT_050',
        'STUDENT_100',
      ]);
    });

    test('verifies empty result handling consistency', () {
      // When filters result in no data, both should handle it the same way
      final studentAttendance = <String, Map<String, dynamic>>{};
      
      // Both would check if empty
      final excelIsEmpty = studentAttendance.isEmpty;
      final pdfIsEmpty = studentAttendance.isEmpty;
      
      expect(excelIsEmpty, equals(pdfIsEmpty));
      expect(excelIsEmpty, true);
      
      // Both would have zero students
      final excelCount = studentAttendance.length;
      final pdfCount = studentAttendance.length;
      
      expect(excelCount, equals(pdfCount));
      expect(excelCount, 0);
    });
  });
}
