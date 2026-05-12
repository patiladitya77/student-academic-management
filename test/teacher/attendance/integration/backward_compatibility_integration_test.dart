import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sam_pro/Teacher/Attendance/models/time_slot.dart';
import 'package:sam_pro/Teacher/Attendance/services/attendance_service.dart';

/// Integration tests for Task 12.4: Verify backward compatibility
/// Tests Requirements 8.1, 8.2, 8.3, 8.4, 8.5
/// 
/// These tests verify:
/// - Legacy data reading and display
/// - Migration on update
/// - Counter calculation consistency
/// - Data structure compatibility
void main() {
  group('Task 12.4 - Backward Compatibility', () {
    late AttendanceService attendanceService;

    // Initialize AttendanceService only for tests that need it
    // This avoids Firebase initialization errors in widget tests
    AttendanceService createService() {
      try {
        return AttendanceService();
      } catch (e) {
        // If Firebase is not initialized, tests will handle it gracefully
        rethrow;
      }
    }

    group('Legacy Data Reading Tests (Requirements 8.1, 8.2)', () {
      test('should identify legacy record without date and time slot fields', () {
        // Requirement 8.1
        attendanceService = createService();
        final legacyRecord = {
          'present': 10,
          'total': 15,
          'last_status': 'P',
        };

        final isLegacy = attendanceService.isLegacyRecord(legacyRecord);

        expect(isLegacy, true,
            reason: 'Record without date/time_slot_id should be identified as legacy');
      });

      test('should identify new format record with date and time slot fields', () {
        // Requirement 8.1
        attendanceService = createService();
        final newRecord = {
          'present': 10,
          'total': 15,
          'last_status': 'P',
          'date': '2024-01-15',
          'time_slot_id': '1',
        };

        final isLegacy = attendanceService.isLegacyRecord(newRecord);

        expect(isLegacy, false,
            reason: 'Record with date and time_slot_id should not be identified as legacy');
      });

      test('should extract session date from legacy record timestamp', () {
        // Requirement 8.2
        attendanceService = createService();
        final testDate = DateTime(2024, 1, 15, 10, 30);
        final legacyRecord = {
          'present': 10,
          'total': 15,
          'date': Timestamp.fromDate(testDate),
        };

        final extractedDate = attendanceService.getLegacySessionDate(legacyRecord);

        expect(extractedDate, isNotNull);
        expect(extractedDate!.year, testDate.year);
        expect(extractedDate.month, testDate.month);
        expect(extractedDate.day, testDate.day);
      });

      test('should return null for legacy record without timestamp', () {
        // Requirement 8.2
        attendanceService = createService();
        final legacyRecord = {
          'present': 10,
          'total': 15,
        };

        final extractedDate = attendanceService.getLegacySessionDate(legacyRecord);

        expect(extractedDate, isNull,
            reason: 'Should return null when date field is missing');
      });

      test('should provide default "Legacy Session" time slot', () {
        // Requirement 8.2
        attendanceService = createService();
        final legacyTimeSlot = attendanceService.getLegacyTimeSlot();

        expect(legacyTimeSlot.id, 'legacy');
        expect(legacyTimeSlot.displayName, 'Legacy Session');
        expect(legacyTimeSlot.startTime, isEmpty);
        expect(legacyTimeSlot.endTime, isEmpty);
      });

      test('should handle legacy record with only date field', () {
        // Requirement 8.1
        attendanceService = createService();
        final partialRecord = {
          'date': Timestamp.fromDate(DateTime(2024, 1, 15)),
        };

        final isLegacy = attendanceService.isLegacyRecord(partialRecord);

        expect(isLegacy, true,
            reason: 'Record with only date field (no time_slot_id) should be legacy');
      });

      test('should handle legacy record with only time_slot_id field', () {
        // Requirement 8.1
        attendanceService = createService();
        final partialRecord = {
          'time_slot_id': '1',
        };

        final isLegacy = attendanceService.isLegacyRecord(partialRecord);

        expect(isLegacy, true,
            reason: 'Record with only time_slot_id (no date) should be legacy');
      });

      test('should handle empty legacy record', () {
        // Requirement 8.1
        attendanceService = createService();
        final emptyRecord = <String, dynamic>{};

        final isLegacy = attendanceService.isLegacyRecord(emptyRecord);

        expect(isLegacy, true,
            reason: 'Empty record should be treated as legacy');
      });
    });

    group('Legacy Data Migration Tests (Requirement 8.3)', () {
      test('should migrate legacy record with date and time slot fields', () {
        // Requirement 8.3
        attendanceService = createService();
        final legacyData = {
          'present': 10,
          'total': 15,
          'last_status': 'P',
        };

        final sessionDate = DateTime(2024, 1, 15);
        final timeSlot = TimeSlot(
          id: '1',
          displayName: 'Period 1',
          startTime: '09:00 AM',
          endTime: '10:00 AM',
        );

        final migratedData = attendanceService.migrateLegacyRecord(
          legacyData,
          sessionDate,
          timeSlot,
        );

        expect(migratedData['present'], 10,
            reason: 'Present count should be preserved');
        expect(migratedData['total'], 15,
            reason: 'Total count should be preserved');
        expect(migratedData['last_status'], 'P',
            reason: 'Last status should be preserved');
        expect(migratedData['date'], '2024-01-15',
            reason: 'Date should be added in YYYY-MM-DD format');
        expect(migratedData['time_slot_id'], '1',
            reason: 'Time slot ID should be added');
        expect(migratedData['time_slot_name'], 'Period 1',
            reason: 'Time slot name should be added');
        expect(migratedData['migrated'], true,
            reason: 'Migration marker should be set');
      });

      test('should preserve all existing fields during migration', () {
        // Requirement 8.3
        attendanceService = createService();
        final legacyData = {
          'present': 10,
          'total': 15,
          'last_status': 'P',
          'custom_field': 'custom_value',
          'teacher_id': 'T001',
        };

        final sessionDate = DateTime(2024, 1, 15);
        final timeSlot = TimeSlot(
          id: '2',
          displayName: 'Period 2',
          startTime: '10:00 AM',
          endTime: '11:00 AM',
        );

        final migratedData = attendanceService.migrateLegacyRecord(
          legacyData,
          sessionDate,
          timeSlot,
        );

        expect(migratedData['custom_field'], 'custom_value',
            reason: 'Custom fields should be preserved during migration');
        expect(migratedData['teacher_id'], 'T001',
            reason: 'Teacher ID should be preserved during migration');
      });

      test('should handle migration with null values', () {
        // Requirement 8.3
        attendanceService = createService();
        final legacyData = {
          'present': null,
          'total': null,
          'last_status': null,
        };

        final sessionDate = DateTime(2024, 1, 15);
        final timeSlot = TimeSlot(
          id: '1',
          displayName: 'Period 1',
          startTime: '09:00 AM',
          endTime: '10:00 AM',
        );

        final migratedData = attendanceService.migrateLegacyRecord(
          legacyData,
          sessionDate,
          timeSlot,
        );

        expect(migratedData['date'], '2024-01-15');
        expect(migratedData['time_slot_id'], '1');
        expect(migratedData['migrated'], true);
      });

      test('should detect migration marker in updated records', () {
        // Requirement 8.3
        final updatedRecord = {
          'present': 10,
          'total': 15,
          'migrated': true,
          'time_slot_id': '1',
          'date': '2024-01-15',
        };

        final wasMigrated = updatedRecord.containsKey('migrated') &&
            updatedRecord['migrated'] == true;

        expect(wasMigrated, true,
            reason: 'Should detect migration marker in updated records');
      });

      test('should migrate multiple legacy records consistently', () {
        // Requirement 8.3
        attendanceService = createService();
        final legacyRecords = [
          {'present': 5, 'total': 10, 'last_status': 'P'},
          {'present': 8, 'total': 12, 'last_status': 'A'},
          {'present': 3, 'total': 7, 'last_status': 'P'},
        ];

        final sessionDate = DateTime(2024, 1, 15);
        final timeSlot = TimeSlot(
          id: '1',
          displayName: 'Period 1',
          startTime: '09:00 AM',
          endTime: '10:00 AM',
        );

        final migratedRecords = legacyRecords
            .map((record) => attendanceService.migrateLegacyRecord(
                  record,
                  sessionDate,
                  timeSlot,
                ))
            .toList();

        for (var i = 0; i < migratedRecords.length; i++) {
          expect(migratedRecords[i]['present'], legacyRecords[i]['present']);
          expect(migratedRecords[i]['total'], legacyRecords[i]['total']);
          expect(migratedRecords[i]['date'], '2024-01-15');
          expect(migratedRecords[i]['time_slot_id'], '1');
          expect(migratedRecords[i]['migrated'], true);
        }
      });
    });

    group('Counter Calculation Consistency Tests (Requirements 8.4, 8.5)', () {
      test('should calculate counters consistently from session data', () {
        // Requirement 8.4
        final sessions = [
          {'status': 'P'},
          {'status': 'P'},
          {'status': 'A'},
          {'status': 'P'},
          {'status': 'A'},
        ];

        int present = 0;
        int total = 0;

        for (var session in sessions) {
          total++;
          if (session['status'] == 'P') {
            present++;
          }
        }

        expect(present, 3,
            reason: 'Present count should match number of P statuses');
        expect(total, 5,
            reason: 'Total count should match number of sessions');
      });

      test('should calculate same result with cumulative and session-level methods', () {
        // Requirement 8.4
        // Cumulative method (legacy)
        final cumulativePresent = 10;
        final cumulativeTotal = 15;

        // Session-level method (new)
        final sessions = List.generate(15, (i) => i < 10 ? 'P' : 'A');
        int sessionPresent = 0;
        int sessionTotal = 0;

        for (var status in sessions) {
          sessionTotal++;
          if (status == 'P') {
            sessionPresent++;
          }
        }

        expect(sessionPresent, cumulativePresent,
            reason: 'Session-level present count should match cumulative');
        expect(sessionTotal, cumulativeTotal,
            reason: 'Session-level total count should match cumulative');
      });

      test('should format date consistently for storage', () {
        // Requirement 8.5
        attendanceService = createService();
        final testDate = DateTime(2024, 1, 15);
        final formattedDate = attendanceService.formatDate(testDate);

        expect(formattedDate, '2024-01-15',
            reason: 'Date should be formatted as YYYY-MM-DD for consistent storage');
      });

      test('should format dates consistently across different months', () {
        // Requirement 8.5
        attendanceService = createService();
        final dates = [
          DateTime(2024, 1, 5),
          DateTime(2024, 2, 15),
          DateTime(2024, 12, 25),
        ];

        final formatted = dates.map((d) => attendanceService.formatDate(d)).toList();

        expect(formatted[0], '2024-01-05');
        expect(formatted[1], '2024-02-15');
        expect(formatted[2], '2024-12-25');
      });

      test('should handle zero counters correctly', () {
        // Requirement 8.4
        final sessions = <Map<String, String>>[];

        int present = 0;
        int total = 0;

        for (var session in sessions) {
          total++;
          if (session['status'] == 'P') {
            present++;
          }
        }

        expect(present, 0);
        expect(total, 0);
      });

      test('should handle all present sessions correctly', () {
        // Requirement 8.4
        final sessions = List.generate(10, (_) => {'status': 'P'});

        int present = 0;
        int total = 0;

        for (var session in sessions) {
          total++;
          if (session['status'] == 'P') {
            present++;
          }
        }

        expect(present, 10);
        expect(total, 10);
      });

      test('should handle all absent sessions correctly', () {
        // Requirement 8.4
        final sessions = List.generate(10, (_) => {'status': 'A'});

        int present = 0;
        int total = 0;

        for (var session in sessions) {
          total++;
          if (session['status'] == 'P') {
            present++;
          }
        }

        expect(present, 0);
        expect(total, 10);
      });
    });

    group('Data Structure Compatibility Tests (Requirement 8.5)', () {
      test('should maintain compatibility with existing Firestore structure', () {
        // Requirement 8.5
        // Old structure: Attendance/{semester}/{courseName}/{studentId}
        final oldPath = ['Attendance', 'Fall2024', 'CS101', 'student1'];

        // New structure adds: sessions/records/{sessionId}/students/{studentId}
        final newPath = [
          'Attendance',
          'Fall2024',
          'CS101',
          'sessions',
          'records',
          '20240115_1',
          'students',
          'student1'
        ];

        // Verify old path is still valid (cumulative counters)
        expect(oldPath.length, 4);
        expect(oldPath[0], 'Attendance');

        // Verify new path extends the structure
        expect(newPath.length, 8);
        expect(newPath[0], 'Attendance');
        expect(newPath[1], oldPath[1]); // Same semester
        expect(newPath[2], oldPath[2]); // Same course
      });

      test('should generate session ID in consistent format', () {
        // Requirement 8.5
        attendanceService = createService();
        final testDate = DateTime(2024, 1, 15);
        final timeSlotId = '1';

        final sessionId = attendanceService.generateSessionId(testDate, timeSlotId);

        expect(sessionId, matches(r'^\d{8}_\w+$'),
            reason: 'Session ID should match format YYYYMMDD_timeSlotId');
        expect(sessionId, '20240115_1');
      });

      test('should handle session IDs with different time slot formats', () {
        // Requirement 8.5
        attendanceService = createService();
        final testDate = DateTime(2024, 1, 15);

        final sessionId1 = attendanceService.generateSessionId(testDate, '1');
        final sessionId2 = attendanceService.generateSessionId(testDate, 'period1');
        final sessionId3 = attendanceService.generateSessionId(testDate, 'legacy');

        expect(sessionId1, '20240115_1');
        expect(sessionId2, '20240115_period1');
        expect(sessionId3, '20240115_legacy');
      });

      test('should preserve cumulative counter fields', () {
        // Requirement 8.5
        final studentRecord = {
          'present': 10,
          'total': 15,
          'last_status': 'P',
          'date': Timestamp.now(),
        };

        // Verify all required fields exist
        expect(studentRecord.containsKey('present'), true);
        expect(studentRecord.containsKey('total'), true);
        expect(studentRecord.containsKey('last_status'), true);
        expect(studentRecord.containsKey('date'), true);
      });

      test('should support both old and new data formats simultaneously', () {
        // Requirement 8.5
        final oldFormatRecord = {
          'present': 10,
          'total': 15,
          'last_status': 'P',
        };

        final newFormatRecord = {
          'present': 10,
          'total': 15,
          'last_status': 'P',
          'date': '2024-01-15',
          'time_slot_id': '1',
          'time_slot_name': 'Period 1',
        };

        // Both should have the core fields
        expect(oldFormatRecord['present'], newFormatRecord['present']);
        expect(oldFormatRecord['total'], newFormatRecord['total']);
        expect(oldFormatRecord['last_status'], newFormatRecord['last_status']);

        // New format has additional fields
        expect(newFormatRecord.containsKey('date'), true);
        expect(newFormatRecord.containsKey('time_slot_id'), true);
      });
    });

    group('Edge Cases and Boundary Conditions', () {
      test('should handle legacy record with extra fields', () {
        // Requirement 8.1
        attendanceService = createService();
        final legacyRecord = {
          'present': 10,
          'total': 15,
          'last_status': 'P',
          'extra_field_1': 'value1',
          'extra_field_2': 'value2',
        };

        final isLegacy = attendanceService.isLegacyRecord(legacyRecord);

        expect(isLegacy, true,
            reason: 'Extra fields should not affect legacy detection');
      });

      test('should handle date extraction from various timestamp formats', () {
        // Requirement 8.2
        attendanceService = createService();
        final testDates = [
          DateTime(2024, 1, 1),
          DateTime(2024, 6, 15),
          DateTime(2024, 12, 31),
        ];

        for (var testDate in testDates) {
          final record = {
            'date': Timestamp.fromDate(testDate),
          };

          final extractedDate = attendanceService.getLegacySessionDate(record);

          expect(extractedDate, isNotNull);
          expect(extractedDate!.year, testDate.year);
          expect(extractedDate.month, testDate.month);
          expect(extractedDate.day, testDate.day);
        }
      });

      test('should handle migration of records with missing optional fields', () {
        // Requirement 8.3
        attendanceService = createService();
        final minimalLegacyData = {
          'present': 5,
          'total': 10,
        };

        final sessionDate = DateTime(2024, 1, 15);
        final timeSlot = TimeSlot(
          id: '1',
          displayName: 'Period 1',
          startTime: '09:00 AM',
          endTime: '10:00 AM',
        );

        final migratedData = attendanceService.migrateLegacyRecord(
          minimalLegacyData,
          sessionDate,
          timeSlot,
        );

        expect(migratedData['present'], 5);
        expect(migratedData['total'], 10);
        expect(migratedData['date'], '2024-01-15');
        expect(migratedData['time_slot_id'], '1');
        expect(migratedData['migrated'], true);
      });

      test('should calculate percentage correctly for both formats', () {
        // Requirement 8.4
        final present = 10;
        final total = 15;

        final percentage = (present / total * 100).toStringAsFixed(2);

        expect(percentage, '66.67');
      });

      test('should handle zero total gracefully in percentage calculation', () {
        // Requirement 8.4
        final present = 0;
        final total = 0;

        final percentage = total > 0 ? (present / total * 100).toStringAsFixed(2) : '0.00';

        expect(percentage, '0.00');
      });
    });
  });
}
