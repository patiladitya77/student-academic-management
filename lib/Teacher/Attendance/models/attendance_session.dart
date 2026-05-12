import 'package:cloud_firestore/cloud_firestore.dart';
import 'time_slot.dart';

/// Model class representing an attendance session
class AttendanceSession {
  final String sessionId;
  final DateTime date;
  final TimeSlot timeSlot;
  final DateTime createdAt;
  final String teacherId;
  final String teacherName;

  AttendanceSession({
    required this.sessionId,
    required this.date,
    required this.timeSlot,
    required this.createdAt,
    required this.teacherId,
    required this.teacherName,
  });

  /// Create AttendanceSession from Firestore document
  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceSession(
      sessionId: doc.id,
      date: DateTime.parse(data['date']),
      timeSlot: TimeSlot(
        id: data['time_slot_id'],
        displayName: data['time_slot_name'],
        startTime: '',
        endTime: '',
      ),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      teacherId: data['teacher_id'],
      teacherName: data['teacher_name'],
    );
  }
}
