import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/student_attendance_summary.dart';

/// Service responsible for fetching courses, students, and attendance data
/// from Firebase for the admin attendance report.
class AdminAttendanceService {
  final FirebaseFirestore _firestore;
  final DatabaseReference _studentsRef;

  AdminAttendanceService({
    FirebaseFirestore? firestore,
    DatabaseReference? studentsRef,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _studentsRef = studentsRef ??
            FirebaseDatabase.instance.ref('Admin_Students_List');


  /// Queries [Admin_added_Course] Firestore collection for documents matching
  /// [semester] and [branch], and returns the list of [course_name] strings.
  ///
  /// Throws [FirebaseException] on Firestore errors.
  Future<List<String>> fetchCourseNames(
      String semester, String branch) async {
    final snapshot = await _firestore
        .collection('Admin_added_Course')
        .where('semester', isEqualTo: semester)
        .where('branch', isEqualTo: branch)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['course_name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }


  /// Queries [Admin_Students_List] Realtime DB ordered by [semester], then
  /// filters in-memory by [branch], and returns the list of student [id] strings.
  ///
  /// Throws [Exception] on database errors.
  Future<List<String>> fetchStudentIds(
      String semester, String branch) async {
    final snapshot = await _studentsRef
        .orderByChild('semester')
        .equalTo(semester)
        .get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    return data.values
        .where((entry) {
          final student = Map<String, dynamic>.from(entry as Map);
          return student['branch'] == branch;
        })
        .map((entry) {
          final student = Map<String, dynamic>.from(entry as Map);
          return student['id'] as String? ?? '';
        })
        .where((id) => id.isNotEmpty)
        .toList();
  }


  /// Reads [Attendance/{semester}/{courseName}/{studentId}] for every course
  /// and aggregates present/total counts into a [StudentAttendanceSummary].
  ///
  /// Missing attendance documents are treated as present=0, total=0.
  Future<StudentAttendanceSummary> computeStudentSummary(
    String studentId,
    String semester,
    List<String> courseNames,
  ) async {
    int totalPresent = 0;
    int totalClasses = 0;

    for (final courseName in courseNames) {
      final doc = await _firestore
          .collection('Attendance')
          .doc(semester)
          .collection(courseName)
          .doc(studentId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        totalPresent += (data['present'] as num? ?? 0).toInt();
        totalClasses += (data['total'] as num? ?? 0).toInt();
      }
      // Missing document → treated as present=0, total=0 (no-op)
    }

    return StudentAttendanceSummary.compute(
      studentId: studentId,
      totalPresent: totalPresent,
      totalClasses: totalClasses,
    );
  }

  /// Generates the full attendance report for [semester] and [branch].
  ///
  /// 1. Fetches course names via [fetchCourseNames].
  /// 2. Fetches student IDs via [fetchStudentIds].
  /// 3. For each student, aggregates attendance across all courses.
  /// 4. Returns the list sorted ascending by [studentId].
  ///
  /// Throws [FirebaseException] or [Exception] on any Firebase error.
  Future<List<StudentAttendanceSummary>> generateReport(
    String semester,
    String branch,
  ) async {
    final courseNames = await fetchCourseNames(semester, branch);
    final studentIds = await fetchStudentIds(semester, branch);

    final summaries = await Future.wait(
      studentIds.map(
        (id) => computeStudentSummary(id, semester, courseNames),
      ),
    );

    summaries.sort((a, b) => a.studentId.compareTo(b.studentId));
    return summaries;
  }
}
