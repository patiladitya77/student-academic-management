import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Model class representing a single lecture session with attendance data
class LectureSession {
  final DateTime date;
  final String timeSlotId;
  final String timeSlotName;
  final Map<String, String> studentStatuses; // studentId -> 'P' or 'A'

  LectureSession({
    required this.date,
    required this.timeSlotId,
    required this.timeSlotName,
    required this.studentStatuses,
  });

  /// Create LectureSession from Firestore session document
  factory LectureSession.fromFirestore(
    DocumentSnapshot sessionDoc,
    Map<String, String> studentStatuses,
  ) {
    final data = sessionDoc.data() as Map<String, dynamic>;
    return LectureSession(
      date: _parseDate(data['date'] ?? ''),
      timeSlotId: data['time_slot_id'] ?? 'unknown',
      timeSlotName: data['time_slot_name'] ?? 'Unknown',
      studentStatuses: studentStatuses,
    );
  }

  /// Parse date string in YYYY-MM-DD format
  static DateTime _parseDate(String dateStr) {
    try {
      return DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (e) {
      // Fallback to current date if parsing fails
      return DateTime.now();
    }
  }
}
