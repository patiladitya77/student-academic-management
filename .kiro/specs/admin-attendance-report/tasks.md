# Tasks: Admin Attendance Report

## Task List

- [x] 1. Update admin dashboard — swap Post Notice for Attendance Report
  - [x] 1.1 In `lib/Admin/Home/Homepage.dart`, remove the "Post Notice" `InkWell`/`ListTile` block
  - [x] 1.2 Add an "Attendance Report" `InkWell`/`ListTile` in its place, navigating to `AdminAttendanceSelectionScreen`
  - [x] 1.3 Add the import for `AdminAttendanceSelectionScreen`

- [x] 2. Add branch field to student records
  - [x] 2.1 In `lib/Admin/Home/Add_student/student.dart`, add a branch dropdown (same branch list as courses) to the add-student form
  - [x] 2.2 Include `branch` in the data written to both `Admin_Students_List` Realtime DB node and `Admin_Students_List` Firestore collection

- [x] 3. Create `StudentAttendanceSummary` model
  - [x] 3.1 Create `lib/Admin/Attendance/models/student_attendance_summary.dart` with fields: `studentId`, `totalPresent`, `totalClasses`, `attendancePercentage`
  - [x] 3.2 Add a factory/constructor that computes `attendancePercentage` from `totalPresent` and `totalClasses` (0.0 when totalClasses is 0, rounded to 2 decimal places)

- [x] 4. Create `AdminAttendanceService`
  - [x] 4.1 Create `lib/Admin/Attendance/services/admin_attendance_service.dart`
  - [x] 4.2 Implement `fetchCourseNames(semester, branch)` — queries `Admin_added_Course` Firestore collection filtered by semester and branch, returns list of `course_name` strings
  - [x] 4.3 Implement `fetchStudentIds(semester, branch)` — queries `Admin_Students_List` Realtime DB node ordered by `semester`, filters in-memory by `branch`, returns list of student `id` strings
  - [x] 4.4 Implement `generateReport(semester, branch)` — calls fetchCourseNames and fetchStudentIds, then for each student reads `Attendance/{semester}/{courseName}/{studentId}` for every course, aggregates present/total, returns sorted list of `StudentAttendanceSummary`

- [x] 5. Create `AdminAttendanceSelectionScreen`
  - [x] 5.1 Create `lib/Admin/Attendance/screens/admin_attendance_selection_screen.dart`
  - [x] 5.2 Add semester dropdown with values "1"–"8"
  - [x] 5.3 Add branch dropdown with the seven branch values used in `CourseList.dart`
  - [x] 5.4 Disable "Generate Report" button when either dropdown is null; enable when both are selected
  - [x] 5.5 On button tap, navigate to `AdminAttendanceReportScreen(semester: ..., branch: ...)`

- [x] 6. Create `AdminAttendanceReportScreen`
  - [x] 6.1 Create `lib/Admin/Attendance/screens/admin_attendance_report_screen.dart`
  - [x] 6.2 Accept `semester` and `branch` constructor parameters
  - [x] 6.3 On `initState`, call `AdminAttendanceService.generateReport` and set loading/error/data state
  - [x] 6.4 Display semester and branch as a header
  - [x] 6.5 Show `CircularProgressIndicator` while loading
  - [x] 6.6 Show error message and "Retry" button on failure
  - [x] 6.7 Show "No courses available" or "No students enrolled" messages for empty results
  - [x] 6.8 Render one `ListTile` per student showing student ID and formatted percentage (`toStringAsFixed(2) + "%"`)
  - [x] 6.9 Color the percentage text red when `attendancePercentage < 75.0`, green otherwise

- [x] 7. Unit tests for `StudentAttendanceSummary`
  - [x] 7.1 Create `test/admin/attendance/models/student_attendance_summary_test.dart`
  - [x] 7.2 Test percentage calculation with known present/total values
  - [x] 7.3 Test zero-class edge case returns 0.0
  - [x] 7.4 Test two-decimal rounding

- [x] 8. Unit tests for `AdminAttendanceService`
  - [x] 8.1 Create `test/admin/attendance/services/admin_attendance_service_test.dart`
  - [x] 8.2 Mock Firestore; verify `fetchCourseNames` returns correct course names for matching documents
  - [x] 8.3 Mock Realtime DB; verify `fetchStudentIds` returns correct IDs filtered by branch
  - [x] 8.4 Verify `generateReport` aggregates present/total correctly across multiple courses
  - [x] 8.5 Verify `generateReport` returns list sorted ascending by student ID
  - [x] 8.6 Verify missing attendance documents are treated as present=0, total=0

- [x] 9. Property-based tests
  - [x] 9.1 Create `test/admin/attendance/properties/admin_attendance_properties_test.dart`
  - [x] 9.2 Property 1 — button enabled iff both semester and branch selected: for any combination of null/non-null semester and branch, verify button enabled state matches `semester != null && branch != null` (min 100 iterations)
  - [x] 9.3 Property 2 — percentage formula: for any generated (totalPresent, totalClasses > 0), verify `attendancePercentage == double.parse((totalPresent / totalClasses * 100).toStringAsFixed(2))` (min 100 iterations)
  - [x] 9.4 Property 3 — aggregation: for any generated list of (present, total) pairs per course, verify the summary's totalPresent and totalClasses equal the sums (min 100 iterations)
  - [x] 9.5 Property 4 — sort order: for any generated list of StudentAttendanceSummary, verify the report output is sorted ascending by studentId (min 100 iterations)
  - [x] 9.6 Property 5 — low-attendance flag: for any generated attendancePercentage, verify the row color is red iff percentage < 75.0 (min 100 iterations)
  - [x] 9.7 Property 6 — percentage format: for any generated attendancePercentage, verify the formatted string equals `toStringAsFixed(2) + "%"` (min 100 iterations)

- [x] 10. Widget tests for screens
  - [x] 10.1 Create `test/admin/attendance/screens/admin_attendance_selection_screen_test.dart`
  - [x] 10.2 Verify "Attendance Report" tile present and "Post Notice" tile absent on dashboard
  - [x] 10.3 Verify semester dropdown contains values "1"–"8"
  - [x] 10.4 Verify branch dropdown contains all seven branch values
  - [x] 10.5 Verify button disabled with no selection, enabled with both selected
  - [x] 10.6 Verify navigation to report screen with correct arguments on button tap
  - [x] 10.7 Create `test/admin/attendance/screens/admin_attendance_report_screen_test.dart`
  - [x] 10.8 Verify loading indicator shown during data fetch
  - [x] 10.9 Verify error message and Retry button shown on service failure
  - [x] 10.10 Verify "no courses" and "no students" messages shown for empty results
  - [x] 10.11 Verify header displays semester and branch
