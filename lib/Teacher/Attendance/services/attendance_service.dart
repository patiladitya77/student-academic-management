import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/time_slot.dart';

/// Service class for attendance-related operations
class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch time slots for a course from Firestore
  /// Returns a list of TimeSlot objects
  Future<List<TimeSlot>> getTimeSlots(String semester, String courseName) async {
    try {
      // Try to fetch time slots from Firestore configuration
      final timeSlotSnapshot = await _firestore
          .collection('TimeSlots')
          .doc(semester)
          .collection('slots')
          .orderBy('order')
          .get();

      if (timeSlotSnapshot.docs.isNotEmpty) {
        return timeSlotSnapshot.docs
            .map((doc) => TimeSlot.fromFirestore(doc.data(), doc.id))
            .toList();
      }

      // Fallback to default time slots if none configured
      return _getDefaultTimeSlots();
    } catch (e) {
      print('Error fetching time slots: $e');
      // Return default time slots on error
      return _getDefaultTimeSlots();
    }
  }

  /// Get default time slots as fallback
  List<TimeSlot> _getDefaultTimeSlots() {
    return [
      TimeSlot(
        id: '1',
        displayName: 'Period 1',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
      ),
      TimeSlot(
        id: '2',
        displayName: 'Period 2',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
      ),
      TimeSlot(
        id: '3',
        displayName: 'Period 3',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
      ),
      TimeSlot(
        id: '4',
        displayName: 'Period 4',
        startTime: '12:00 PM',
        endTime: '01:00 PM',
      ),
      TimeSlot(
        id: '5',
        displayName: 'Period 5',
        startTime: '02:00 PM',
        endTime: '03:00 PM',
      ),
      TimeSlot(
        id: '6',
        displayName: 'Period 6',
        startTime: '03:00 PM',
        endTime: '04:00 PM',
      ),
    ];
  }

  /// Check if attendance already exists for a specific date and time slot
  /// Returns true if records exist, false otherwise
  Future<bool> hasExistingAttendance(
    String semester,
    String courseName,
    DateTime date,
    String timeSlotId,
  ) async {
    try {
      final sessionId = generateSessionId(date, timeSlotId);
      final sessionDoc = await _firestore
          .collection('Attendance')
          .doc(semester)
          .collection(courseName)
          .doc('sessions')
          .collection('records')
          .doc(sessionId)
          .get();

      return sessionDoc.exists;
    } catch (e) {
      print('Error checking existing attendance: $e');
      return false;
    }
  }

  /// Get existing attendance session details
  /// Returns session data map if exists, null otherwise
  Future<Map<String, dynamic>?> getExistingSession(
    String semester,
    String courseName,
    DateTime date,
    String timeSlotId,
  ) async {
    try {
      final sessionId = generateSessionId(date, timeSlotId);
      final sessionDoc = await _firestore
          .collection('Attendance')
          .doc(semester)
          .collection(courseName)
          .doc('sessions')
          .collection('records')
          .doc(sessionId)
          .get();

      if (sessionDoc.exists) {
        return sessionDoc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching existing session: $e');
      return null;
    }
  }

  /// Generate unique session ID from date and time slot
  /// Format: YYYYMMDD_timeSlotId
  String generateSessionId(DateTime date, String timeSlotId) {
    final dateStr = DateFormat('yyyyMMdd').format(date);
    return '${dateStr}_$timeSlotId';
  }

  /// Format date for storage in Firestore
  /// Format: YYYY-MM-DD
  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format date for display to users
  /// Format: DayOfWeek, Month Day, Year (e.g., "Monday, January 15, 2024")
  String formatDateDisplay(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }

  /// Check if a record is in legacy format (no date/time slot fields)
  /// Legacy records only have cumulative counters without session-level tracking
  bool isLegacyRecord(Map<String, dynamic> data) {
    // Legacy records don't have explicit date and time_slot_id fields in session structure
    // They only have cumulative counters at the student level
    return !data.containsKey('date') || !data.containsKey('time_slot_id');
  }

  /// Extract session date from legacy record
  /// Uses the 'date' timestamp field as the session date
  DateTime? getLegacySessionDate(Map<String, dynamic> data) {
    if (data.containsKey('date') && data['date'] is Timestamp) {
      return (data['date'] as Timestamp).toDate();
    }
    return null;
  }

  /// Get default time slot for legacy records
  /// Returns a special "Legacy Session" time slot for records without time slot info
  TimeSlot getLegacyTimeSlot() {
    return TimeSlot(
      id: 'legacy',
      displayName: 'Legacy Session',
      startTime: '',
      endTime: '',
    );
  }

  /// Migrate legacy record to new format
  /// Adds date and time slot fields while preserving existing counters
  Map<String, dynamic> migrateLegacyRecord(
    Map<String, dynamic> legacyData,
    DateTime sessionDate,
    TimeSlot timeSlot,
  ) {
    return {
      ...legacyData,
      'date': formatDate(sessionDate),
      'time_slot_id': timeSlot.id,
      'time_slot_name': timeSlot.displayName,
      'migrated': true,
      'migrated_at': FieldValue.serverTimestamp(),
    };
  }

  /// Verify counter calculation consistency between cumulative and session-level data
  /// Returns true if counters match, false otherwise
  Future<bool> verifyCounterConsistency(
    String semester,
    String courseName,
    String studentId,
  ) async {
    try {
      // Get cumulative counters
      final studentDoc = await _firestore
          .collection('Attendance')
          .doc(semester)
          .collection(courseName)
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        return true; // No data to verify
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;
      final cumulativePresent = studentData['present'] ?? 0;
      final cumulativeTotal = studentData['total'] ?? 0;

      // Calculate from session-level data
      final sessionsSnapshot = await _firestore
          .collection('Attendance')
          .doc(semester)
          .collection(courseName)
          .doc('sessions')
          .collection('records')
          .get();

      int sessionPresent = 0;
      int sessionTotal = 0;

      for (var sessionDoc in sessionsSnapshot.docs) {
        final studentSessionDoc = await sessionDoc.reference
            .collection('students')
            .doc(studentId)
            .get();

        if (studentSessionDoc.exists) {
          final status = studentSessionDoc.data()?['status'] ?? 'A';
          sessionTotal++;
          if (status == 'P') {
            sessionPresent++;
          }
        }
      }

      // Compare cumulative vs session-level calculations
      final isConsistent = (cumulativePresent == sessionPresent) && 
                          (cumulativeTotal == sessionTotal);

      if (!isConsistent) {
        print('Counter mismatch for student $studentId:');
        print('  Cumulative: present=$cumulativePresent, total=$cumulativeTotal');
        print('  Session-level: present=$sessionPresent, total=$sessionTotal');
      }

      return isConsistent;
    } catch (e) {
      print('Error verifying counter consistency: $e');
      return false;
    }
  }

  /// Recalculate and fix cumulative counters from session-level data
  /// Used to repair inconsistencies between old and new data formats
  Future<void> recalculateCounters(
    String semester,
    String courseName,
    String studentId,
  ) async {
    try {
      // Calculate from session-level data
      final sessionsSnapshot = await _firestore
          .collection('Attendance')
          .doc(semester)
          .collection(courseName)
          .doc('sessions')
          .collection('records')
          .get();

      int sessionPresent = 0;
      int sessionTotal = 0;

      for (var sessionDoc in sessionsSnapshot.docs) {
        final studentSessionDoc = await sessionDoc.reference
            .collection('students')
            .doc(studentId)
            .get();

        if (studentSessionDoc.exists) {
          final status = studentSessionDoc.data()?['status'] ?? 'A';
          sessionTotal++;
          if (status == 'P') {
            sessionPresent++;
          }
        }
      }

      // Update cumulative counters
      await _firestore
          .collection('Attendance')
          .doc(semester)
          .collection(courseName)
          .doc(studentId)
          .set({
        'present': sessionPresent,
        'total': sessionTotal,
        'recalculated': true,
        'recalculated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Recalculated counters for student $studentId: present=$sessionPresent, total=$sessionTotal');
    } catch (e) {
      print('Error recalculating counters: $e');
      rethrow;
    }
  }
}
