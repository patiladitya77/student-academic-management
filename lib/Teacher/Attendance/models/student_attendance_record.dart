import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class representing a student's attendance record for a specific session
class StudentAttendanceRecord {
  final String studentId;
  final String status;
  final DateTime markedAt;

  StudentAttendanceRecord({
    required this.studentId,
    required this.status,
    required this.markedAt,
  });

  /// Create StudentAttendanceRecord from Firestore document
  factory StudentAttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentAttendanceRecord(
      studentId: doc.id,
      status: data['status'],
      markedAt: (data['marked_at'] as Timestamp).toDate(),
    );
  }
}
