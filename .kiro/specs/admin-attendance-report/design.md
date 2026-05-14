# Design Document: Admin Attendance Report

## Overview

This feature replaces the "Post Notice" list tile on the admin dashboard with an "Attendance Report" list tile. Tapping it navigates to a selection screen where the admin picks a semester and branch. After confirming, a report screen loads and displays each student's overall attendance percentage aggregated across all courses for that cohort.

The feature introduces three new files under `lib/Admin/Attendance/`:

- `screens/admin_attendance_selection_screen.dart` — semester/branch picker
- `screens/admin_attendance_report_screen.dart` — report display
- `services/admin_attendance_service.dart` — Firebase data access

One existing file is modified:

- `lib/Admin/Home/Homepage.dart` — swap "Post Notice" tile for "Attendance Report" tile

## Architecture

```mermaid
graph TD
    A[adminhomepage] -->|tap Attendance Report| B[AdminAttendanceSelectionScreen]
    B -->|tap Generate Report| C[AdminAttendanceReportScreen]
    C --> D[AdminAttendanceService]
    D -->|query courses| E[Firestore: Admin_added_Course]
    D -->|query students| F[Realtime DB: Admin_Students_List]
    D -->|query attendance| G[Firestore: Attendance/{sem}/{course}/{studentId}]
```

The service layer is kept separate from the UI, mirroring the pattern used in `lib/Teacher/Attendance/services/attendance_service.dart`.

## Components and Interfaces

### AdminAttendanceSelectionScreen

A `StatefulWidget` that presents two dropdowns and a button.

```dart
class AdminAttendanceSelectionScreen extends StatefulWidget {
  const AdminAttendanceSelectionScreen({super.key});
}
```

State fields:

- `String? _selectedSemester`
- `String? _selectedBranch`

The "Generate Report" button is enabled only when both fields are non-null. On tap it pushes `AdminAttendanceReportScreen(semester: ..., branch: ...)`.

### AdminAttendanceReportScreen

A `StatefulWidget` that loads data on `initState` and renders the report.

```dart
class AdminAttendanceReportScreen extends StatefulWidget {
  final String semester;
  final String branch;
  const AdminAttendanceReportScreen({
    super.key,
    required this.semester,
    required this.branch,
  });
}
```

State fields:

- `bool _isLoading`
- `String? _errorMessage`
- `List<StudentAttendanceSummary> _reportData`

On error, shows the error message and a "Retry" button that re-invokes the load method.

### AdminAttendanceService

A plain Dart class (no `StatefulWidget` dependency) responsible for all Firebase calls.

```dart
class AdminAttendanceService {
  Future<List<String>> fetchCourseNames(String semester, String branch);
  Future<List<String>> fetchStudentIds(String semester, String branch);
  Future<StudentAttendanceSummary> computeStudentSummary(
    String studentId,
    String semester,
    List<String> courseNames,
  );
  Future<List<StudentAttendanceSummary>> generateReport(
    String semester,
    String branch,
  );
}
```

### StudentAttendanceSummary (data model)

```dart
class StudentAttendanceSummary {
  final String studentId;
  final int totalPresent;
  final int totalClasses;
  final double attendancePercentage; // rounded to 2 decimal places

  const StudentAttendanceSummary({
    required this.studentId,
    required this.totalPresent,
    required this.totalClasses,
    required this.attendancePercentage,
  });
}
```

## Data Models

### Firestore: Admin_added_Course

Each document has at minimum:

```
{
  "course_name": "Data Structures",
  "semester": "3",
  "branch": "Computer Science & Engineering",
  "course_instructor": "...",
  "instructor_id": "..."
}
```

Query: `where('semester', isEqualTo: semester).where('branch', isEqualTo: branch)`

### Firebase Realtime Database: Admin_Students_List

Each node keyed by student ID:

```
{
  "id": "CS21001",
  "email": "...",
  "semester": "3",
  "branch": "Computer Science & Engineering",
  "role": "student"
}
```

> **Note:** The current `student.dart` add-student form does not include a `branch` field. The implementation must add `branch` to the student record when adding students, or the query will return no results. The design assumes `branch` is stored on each student node. If existing records lack `branch`, the service will fall back to filtering by `semester` only and the report screen will note this limitation. The tasks include updating the add-student form to capture `branch`.

Query: `orderByChild('semester').equalTo(semester)` then filter in-memory by `branch`.

### Firestore: Attendance/{semester}/{courseName}/{studentId}

Each document:

```
{
  "present": 12,
  "total": 15
}
```

The service reads this document for every `(studentId, courseName)` pair. Missing documents are treated as `present: 0, total: 0`.

### StudentAttendanceSummary computation

```
totalPresent = sum of present across all courses
totalClasses = sum of total across all courses
percentage   = totalClasses > 0 ? (totalPresent / totalClasses * 100) : 0.0
               rounded to 2 decimal places
```

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property 1: Generate Report button enabled iff both selections made

_For any_ combination of semester and branch dropdown values, the "Generate Report" button is enabled if and only if both a semester and a branch have been selected (neither is null).

**Validates: Requirements 2.3, 2.4**

### Property 2: Attendance percentage formula correctness

_For any_ student with `totalClasses > 0`, the computed `attendancePercentage` equals `(totalPresent / totalClasses * 100)` rounded to two decimal places.

**Validates: Requirements 5.4, 5.6**

### Property 3: Zero-class students get 0.0 percentage

_For any_ student whose `totalClasses` equals zero, the `attendancePercentage` is exactly `0.0`.

**Validates: Requirements 5.5**

### Property 4: Aggregation sums all courses

_For any_ student and any list of courses, `totalPresent` equals the sum of `present` values across all course attendance documents, and `totalClasses` equals the sum of `total` values.

**Validates: Requirements 5.1, 5.2, 5.3**

### Property 5: Report sorted ascending by student ID

_For any_ generated report with more than one student, the list of `StudentAttendanceSummary` objects is sorted in ascending lexicographic order by `studentId`.

**Validates: Requirements 6.5**

### Property 6: Low-attendance flag below 75%

_For any_ student summary, the UI marks the row with a red indicator if and only if `attendancePercentage < 75.0`.

**Validates: Requirements 6.4**

### Property 7: Percentage formatted as two-decimal string with %

_For any_ `StudentAttendanceSummary`, the formatted display string equals `attendancePercentage.toStringAsFixed(2)` followed by `"%"`.

**Validates: Requirements 6.3**

## Error Handling

| Failure point                    | Behaviour                                                              |
| -------------------------------- | ---------------------------------------------------------------------- |
| Firestore courses query fails    | Show "Could not load course data. Please retry." with Retry button     |
| Realtime DB students query fails | Show "Could not load student data. Please retry." with Retry button    |
| Firestore attendance query fails | Show "Could not load attendance data. Please retry." with Retry button |
| No courses found                 | Show "No courses found for the selected semester and branch."          |
| No students found                | Show "No students enrolled for the selected semester and branch."      |

All errors are caught in `AdminAttendanceReportScreen._loadReport()`. The `_errorMessage` state field drives the error UI. The Retry button calls `_loadReport()` again.

The service methods throw typed exceptions (`FirebaseException`, `DatabaseException`) which the screen catches and maps to user-friendly strings.

## Testing Strategy

### Unit tests

Located in `test/admin/attendance/`.

- `admin_attendance_service_test.dart`: mock Firestore and Realtime DB; verify `fetchCourseNames`, `fetchStudentIds`, and `computeStudentSummary` return correct values for known inputs, empty collections, and missing attendance documents.
- `student_attendance_summary_test.dart`: verify percentage calculation, zero-class edge case, and two-decimal rounding.

### Property-based tests

Use the [`fast_check`](https://pub.dev/packages/fast_check) package (Dart property-based testing library).

Each test runs a minimum of 100 iterations.

```
// Feature: admin-attendance-report, Property 2: attendance percentage formula correctness
// Feature: admin-attendance-report, Property 3: zero-class students get 0.0 percentage
// Feature: admin-attendance-report, Property 4: aggregation sums all courses
// Feature: admin-attendance-report, Property 5: report sorted ascending by student ID
// Feature: admin-attendance-report, Property 6: low-attendance flag below 75%
// Feature: admin-attendance-report, Property 7: percentage formatted as two-decimal string with %
```

Property 1 (button enabled state) is tested as a widget property test using `flutter_test` with generated combinations of null/non-null semester and branch values.

Unit tests cover:

- Specific examples: known present/total values produce expected percentage strings
- Edge cases: `total = 0`, single course, single student, all students below 75%
- Error conditions: Firestore throws, Realtime DB throws, empty result sets
