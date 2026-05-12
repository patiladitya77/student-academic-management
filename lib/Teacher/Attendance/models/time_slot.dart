import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class representing a time slot for attendance sessions
class TimeSlot {
  final String id;
  final String displayName;
  final String startTime;
  final String endTime;

  TimeSlot({
    required this.id,
    required this.displayName,
    required this.startTime,
    required this.endTime,
  });

  /// Create TimeSlot from Firestore document
  factory TimeSlot.fromFirestore(Map<String, dynamic> data, String id) {
    return TimeSlot(
      id: id,
      displayName: data['display_name'] ?? 'Period $id',
      startTime: data['start_time'] ?? '',
      endTime: data['end_time'] ?? '',
    );
  }

  /// Convert TimeSlot to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'display_name': displayName,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}
