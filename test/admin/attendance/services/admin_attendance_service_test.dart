import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sam_pro/Admin/Attendance/services/admin_attendance_service.dart';

import 'admin_attendance_service_test.mocks.dart';

// Generate mocks for DatabaseReference and Query
@GenerateMocks([DatabaseReference, Query, DataSnapshot])
void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Builds a [FakeFirebaseFirestore] pre-populated with [Admin_added_Course]
  /// documents for the given semester/branch.
  FakeFirebaseFirestore firestoreWithCourses({
    required String semester,
    required String branch,
    required List<String> courseNames,
    List<Map<String, dynamic>> extraDocs = const [],
  }) {
    final firestore = FakeFirebaseFirestore();
    for (final name in courseNames) {
      firestore.collection('Admin_added_Course').add({
        'course_name': name,
        'semester': semester,
        'branch': branch,
      });
    }
    for (final doc in extraDocs) {
      firestore.collection('Admin_added_Course').add(doc);
    }
    return firestore;
  }

  /// Adds attendance documents to [firestore] at
  /// Attendance/{semester}/{courseName}/{studentId}.
  Future<void> addAttendance(
    FakeFirebaseFirestore firestore, {
    required String semester,
    required String courseName,
    required String studentId,
    required int present,
    required int total,
  }) async {
    await firestore
        .collection('Attendance')
        .doc(semester)
        .collection(courseName)
        .doc(studentId)
        .set({'present': present, 'total': total});
  }

  /// Builds a mock [DatabaseReference] that returns [students] when
  /// `orderByChild('semester').equalTo(semester).get()` is called.
  ///
  /// [students] is a map of { nodeKey: { id, semester, branch, ... } }.
  MockDatabaseReference mockStudentsRef(
    Map<String, dynamic> students,
  ) {
    final mockRef = MockDatabaseReference();
    final mockQuery = MockQuery();
    final mockSnapshot = MockDataSnapshot();

    // Stub the chained query calls
    when(mockRef.orderByChild('semester')).thenReturn(mockQuery);
    when(mockQuery.equalTo(any)).thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);

    // Stub snapshot
    when(mockSnapshot.exists).thenReturn(students.isNotEmpty);
    when(mockSnapshot.value).thenReturn(students.isEmpty ? null : students);

    return mockRef;
  }

  // ---------------------------------------------------------------------------
  // Task 8.2 — fetchCourseNames returns correct course names
  // ---------------------------------------------------------------------------
  group('fetchCourseNames', () {
    test('returns course names matching semester and branch', () async {
      final firestore = firestoreWithCourses(
        semester: '3',
        branch: 'Computer Science & Engineering',
        courseNames: ['Data Structures', 'Algorithms', 'Operating Systems'],
      );

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef({}),
      );

      final names = await service.fetchCourseNames(
        '3',
        'Computer Science & Engineering',
      );

      expect(names, containsAll(['Data Structures', 'Algorithms', 'Operating Systems']));
      expect(names.length, 3);
    });

    test('does not return courses from a different semester', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('Admin_added_Course').add({
        'course_name': 'Physics',
        'semester': '1',
        'branch': 'Computer Science & Engineering',
      });
      await firestore.collection('Admin_added_Course').add({
        'course_name': 'Data Structures',
        'semester': '3',
        'branch': 'Computer Science & Engineering',
      });

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef({}),
      );

      final names = await service.fetchCourseNames(
        '3',
        'Computer Science & Engineering',
      );

      expect(names, equals(['Data Structures']));
    });

    test('does not return courses from a different branch', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('Admin_added_Course').add({
        'course_name': 'Thermodynamics',
        'semester': '3',
        'branch': 'Mechanical Engineering',
      });
      await firestore.collection('Admin_added_Course').add({
        'course_name': 'Data Structures',
        'semester': '3',
        'branch': 'Computer Science & Engineering',
      });

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef({}),
      );

      final names = await service.fetchCourseNames(
        '3',
        'Computer Science & Engineering',
      );

      expect(names, equals(['Data Structures']));
    });

    test('returns empty list when no matching courses exist', () async {
      final firestore = FakeFirebaseFirestore();

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef({}),
      );

      final names = await service.fetchCourseNames('5', 'Electronics');

      expect(names, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 8.3 — fetchStudentIds returns IDs filtered by branch
  // ---------------------------------------------------------------------------
  group('fetchStudentIds', () {
    test('returns student IDs matching semester and branch', () async {
      final students = {
        'node1': {
          'id': 'CS21001',
          'semester': '3',
          'branch': 'Computer Science & Engineering',
        },
        'node2': {
          'id': 'CS21002',
          'semester': '3',
          'branch': 'Computer Science & Engineering',
        },
      };

      final service = AdminAttendanceService(
        firestore: FakeFirebaseFirestore(),
        studentsRef: mockStudentsRef(students),
      );

      final ids = await service.fetchStudentIds(
        '3',
        'Computer Science & Engineering',
      );

      expect(ids, containsAll(['CS21001', 'CS21002']));
      expect(ids.length, 2);
    });

    test('filters out students from a different branch', () async {
      final students = {
        'node1': {
          'id': 'CS21001',
          'semester': '3',
          'branch': 'Computer Science & Engineering',
        },
        'node2': {
          'id': 'ME21001',
          'semester': '3',
          'branch': 'Mechanical Engineering',
        },
      };

      final service = AdminAttendanceService(
        firestore: FakeFirebaseFirestore(),
        studentsRef: mockStudentsRef(students),
      );

      final ids = await service.fetchStudentIds(
        '3',
        'Computer Science & Engineering',
      );

      expect(ids, equals(['CS21001']));
    });

    test('returns empty list when snapshot has no data', () async {
      final service = AdminAttendanceService(
        firestore: FakeFirebaseFirestore(),
        studentsRef: mockStudentsRef({}),
      );

      final ids = await service.fetchStudentIds('3', 'Computer Science & Engineering');

      expect(ids, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 8.4 — generateReport aggregates present/total correctly
  // ---------------------------------------------------------------------------
  group('generateReport - aggregation', () {
    test('aggregates present and total across multiple courses', () async {
      const semester = '3';
      const branch = 'Computer Science & Engineering';

      final firestore = firestoreWithCourses(
        semester: semester,
        branch: branch,
        courseNames: ['Math', 'Physics'],
      );

      // Student CS21001: Math(8/10) + Physics(6/8) → 14/18
      await addAttendance(firestore,
          semester: semester,
          courseName: 'Math',
          studentId: 'CS21001',
          present: 8,
          total: 10);
      await addAttendance(firestore,
          semester: semester,
          courseName: 'Physics',
          studentId: 'CS21001',
          present: 6,
          total: 8);

      final students = {
        'node1': {
          'id': 'CS21001',
          'semester': semester,
          'branch': branch,
        },
      };

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef(students),
      );

      final report = await service.generateReport(semester, branch);

      expect(report.length, 1);
      expect(report[0].studentId, 'CS21001');
      expect(report[0].totalPresent, 14);
      expect(report[0].totalClasses, 18);
    });

    test('aggregates correctly for two students across two courses', () async {
      const semester = '3';
      const branch = 'Computer Science & Engineering';

      final firestore = firestoreWithCourses(
        semester: semester,
        branch: branch,
        courseNames: ['CourseA', 'CourseB'],
      );

      // Student A: CourseA(5/10) + CourseB(3/5) → 8/15
      await addAttendance(firestore,
          semester: semester,
          courseName: 'CourseA',
          studentId: 'S001',
          present: 5,
          total: 10);
      await addAttendance(firestore,
          semester: semester,
          courseName: 'CourseB',
          studentId: 'S001',
          present: 3,
          total: 5);

      // Student B: CourseA(10/10) + CourseB(5/5) → 15/15
      await addAttendance(firestore,
          semester: semester,
          courseName: 'CourseA',
          studentId: 'S002',
          present: 10,
          total: 10);
      await addAttendance(firestore,
          semester: semester,
          courseName: 'CourseB',
          studentId: 'S002',
          present: 5,
          total: 5);

      final students = {
        'node1': {'id': 'S001', 'semester': semester, 'branch': branch},
        'node2': {'id': 'S002', 'semester': semester, 'branch': branch},
      };

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef(students),
      );

      final report = await service.generateReport(semester, branch);

      expect(report.length, 2);

      final s001 = report.firstWhere((s) => s.studentId == 'S001');
      expect(s001.totalPresent, 8);
      expect(s001.totalClasses, 15);

      final s002 = report.firstWhere((s) => s.studentId == 'S002');
      expect(s002.totalPresent, 15);
      expect(s002.totalClasses, 15);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 8.5 — generateReport returns list sorted ascending by student ID
  // ---------------------------------------------------------------------------
  group('generateReport - sort order', () {
    test('returns students sorted ascending by studentId', () async {
      const semester = '3';
      const branch = 'Computer Science & Engineering';

      final firestore = firestoreWithCourses(
        semester: semester,
        branch: branch,
        courseNames: ['Math'],
      );

      // Add attendance for all students
      for (final id in ['CS21003', 'CS21001', 'CS21002']) {
        await addAttendance(firestore,
            semester: semester,
            courseName: 'Math',
            studentId: id,
            present: 5,
            total: 10);
      }

      // Provide students in non-sorted order
      final students = {
        'node1': {'id': 'CS21003', 'semester': semester, 'branch': branch},
        'node2': {'id': 'CS21001', 'semester': semester, 'branch': branch},
        'node3': {'id': 'CS21002', 'semester': semester, 'branch': branch},
      };

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef(students),
      );

      final report = await service.generateReport(semester, branch);

      expect(report.length, 3);
      expect(report[0].studentId, 'CS21001');
      expect(report[1].studentId, 'CS21002');
      expect(report[2].studentId, 'CS21003');
    });

    test('single student report is trivially sorted', () async {
      const semester = '3';
      const branch = 'Computer Science & Engineering';

      final firestore = firestoreWithCourses(
        semester: semester,
        branch: branch,
        courseNames: ['Math'],
      );

      await addAttendance(firestore,
          semester: semester,
          courseName: 'Math',
          studentId: 'ONLY001',
          present: 7,
          total: 10);

      final students = {
        'node1': {'id': 'ONLY001', 'semester': semester, 'branch': branch},
      };

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef(students),
      );

      final report = await service.generateReport(semester, branch);

      expect(report.length, 1);
      expect(report[0].studentId, 'ONLY001');
    });
  });

  // ---------------------------------------------------------------------------
  // Task 8.6 — missing attendance documents treated as present=0, total=0
  // ---------------------------------------------------------------------------
  group('generateReport - missing attendance documents', () {
    test('missing attendance doc for a course contributes 0 present and 0 total',
        () async {
      const semester = '3';
      const branch = 'Computer Science & Engineering';

      final firestore = firestoreWithCourses(
        semester: semester,
        branch: branch,
        courseNames: ['Math', 'Physics'],
      );

      // Only add attendance for Math; Physics doc is missing
      await addAttendance(firestore,
          semester: semester,
          courseName: 'Math',
          studentId: 'CS21001',
          present: 8,
          total: 10);
      // No Physics attendance doc for CS21001

      final students = {
        'node1': {'id': 'CS21001', 'semester': semester, 'branch': branch},
      };

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef(students),
      );

      final report = await service.generateReport(semester, branch);

      expect(report.length, 1);
      // Physics missing → 0/0 added; total = 8/10
      expect(report[0].totalPresent, 8);
      expect(report[0].totalClasses, 10);
    });

    test('all attendance docs missing results in 0 present and 0 total',
        () async {
      const semester = '3';
      const branch = 'Computer Science & Engineering';

      final firestore = firestoreWithCourses(
        semester: semester,
        branch: branch,
        courseNames: ['Math', 'Physics'],
      );
      // No attendance docs added at all

      final students = {
        'node1': {'id': 'CS21001', 'semester': semester, 'branch': branch},
      };

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef(students),
      );

      final report = await service.generateReport(semester, branch);

      expect(report.length, 1);
      expect(report[0].totalPresent, 0);
      expect(report[0].totalClasses, 0);
      expect(report[0].attendancePercentage, 0.0);
    });

    test('no courses means every student gets 0 present and 0 total', () async {
      const semester = '3';
      const branch = 'Computer Science & Engineering';

      // No courses in Firestore
      final firestore = FakeFirebaseFirestore();

      final students = {
        'node1': {'id': 'CS21001', 'semester': semester, 'branch': branch},
      };

      final service = AdminAttendanceService(
        firestore: firestore,
        studentsRef: mockStudentsRef(students),
      );

      final report = await service.generateReport(semester, branch);

      expect(report.length, 1);
      expect(report[0].totalPresent, 0);
      expect(report[0].totalClasses, 0);
    });
  });
}
