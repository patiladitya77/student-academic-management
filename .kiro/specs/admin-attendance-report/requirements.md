# Requirements Document

## Introduction

This feature replaces the "Post Notice" button on the admin dashboard with an "Attendance Report" button. When tapped, the admin selects a semester and branch, then generates an overall attendance report for all students in that semester and branch. The report aggregates attendance data across all courses for the selected cohort, giving the admin a bird's-eye view of student attendance.

## Glossary

- **Admin_Dashboard**: The main home screen of the admin role in the application
- **Attendance_Report**: A summary showing each student's overall attendance percentage across all courses in a given semester and branch
- **Branch**: An engineering discipline (e.g., "Computer Science & Engineering") used to group students and courses
- **Semester**: An academic period identifier (values: "1" through "8") used to group students and courses
- **Course**: A subject offered in a specific semester and branch, stored in the `Admin_added_Course` Firestore collection
- **Student**: A learner enrolled in a semester and branch, identified by a student ID stored in `Admin_Students_List` in Firebase Realtime Database
- **Attendance_Record**: A Firestore document at `Attendance/{semester}/{courseName}/{studentId}` containing `present` and `total` integer fields
- **Overall_Attendance_Percentage**: The ratio of total classes attended to total classes held across all courses for a student, expressed as a percentage
- **Report_Screen**: The Flutter screen that displays the generated attendance report
- **Selection_Screen**: The Flutter screen where the admin picks a semester and branch before generating the report
- **Admin_Attendance_Service**: The service class responsible for fetching courses, students, and attendance data from Firebase for the admin report

## Requirements

### Requirement 1: Replace Post Notice Button with Attendance Report Button

**User Story:** As an admin, I want an "Attendance Report" button on the dashboard in place of the "Post Notice" button, so that I can quickly access attendance reporting.

#### Acceptance Criteria

1. THE Admin_Dashboard SHALL display an "Attendance Report" list tile where the "Post Notice" list tile previously appeared
2. THE Admin_Dashboard SHALL NOT display the "Post Notice" list tile
3. WHEN the admin taps the "Attendance Report" list tile, THE Admin_Dashboard SHALL navigate to the Selection_Screen

### Requirement 2: Semester and Branch Selection

**User Story:** As an admin, I want to select a semester and branch before generating a report, so that the report is scoped to the correct student cohort.

#### Acceptance Criteria

1. THE Selection_Screen SHALL display a dropdown for selecting a semester from the values "1" through "8"
2. THE Selection_Screen SHALL display a dropdown for selecting a branch from the list of branches defined in the system: "Computer Science & Engineering", "Information Science & Engineering", "Civil Engineering", "Mechanical Engineering", "Electrical Engineering", "Electronics & Communication Eng", "Biotechnology Engineering"
3. WHEN both a semester and a branch are selected, THE Selection_Screen SHALL enable a "Generate Report" button
4. WHEN only one or neither selection is made, THE Selection_Screen SHALL disable the "Generate Report" button
5. WHEN the admin taps the enabled "Generate Report" button, THE Selection_Screen SHALL navigate to the Report_Screen passing the selected semester and branch

### Requirement 3: Fetch Courses for Selected Semester and Branch

**User Story:** As an admin, I want the report to cover all courses in the selected semester and branch, so that the attendance summary is complete.

#### Acceptance Criteria

1. WHEN the Report_Screen loads, THE Admin_Attendance_Service SHALL query the `Admin_added_Course` Firestore collection for documents where `semester` equals the selected semester AND `branch` equals the selected branch
2. THE Admin_Attendance_Service SHALL extract the `course_name` field from each matching course document
3. IF no courses are found for the selected semester and branch, THEN THE Report_Screen SHALL display a message indicating no courses are available

### Requirement 4: Fetch Students for Selected Semester and Branch

**User Story:** As an admin, I want the report to list all students in the selected semester and branch, so that no student is omitted.

#### Acceptance Criteria

1. WHEN the Report_Screen loads, THE Admin_Attendance_Service SHALL query the `Admin_Students_List` node in Firebase Realtime Database for entries where `semester` equals the selected semester AND `branch` equals the selected branch
2. THE Admin_Attendance_Service SHALL extract the student `id` field from each matching student entry
3. IF no students are found for the selected semester and branch, THEN THE Report_Screen SHALL display a message indicating no students are enrolled

### Requirement 5: Aggregate Overall Attendance Per Student

**User Story:** As an admin, I want to see each student's overall attendance percentage across all courses, so that I can identify students with low attendance.

#### Acceptance Criteria

1. FOR each student in the cohort, THE Admin_Attendance_Service SHALL read the `Attendance/{semester}/{courseName}/{studentId}` Firestore document for every course in the cohort
2. THE Admin_Attendance_Service SHALL sum the `present` values across all courses for each student to obtain a total present count
3. THE Admin_Attendance_Service SHALL sum the `total` values across all courses for each student to obtain a total classes count
4. WHEN the total classes count for a student is greater than zero, THE Admin_Attendance_Service SHALL calculate the Overall_Attendance_Percentage as `(total present / total classes) * 100`
5. WHEN the total classes count for a student is zero, THE Admin_Attendance_Service SHALL set the Overall_Attendance_Percentage to 0.0
6. THE Admin_Attendance_Service SHALL round the Overall_Attendance_Percentage to two decimal places

### Requirement 6: Display Attendance Report

**User Story:** As an admin, I want to see a clear list of all students with their overall attendance percentage, so that I can review attendance at a glance.

#### Acceptance Criteria

1. THE Report_Screen SHALL display the selected semester and branch as a header
2. THE Report_Screen SHALL display one row per student showing the student ID and the Overall_Attendance_Percentage
3. THE Report_Screen SHALL format the Overall_Attendance_Percentage as a number with two decimal places followed by a "%" symbol
4. THE Report_Screen SHALL visually distinguish students whose Overall_Attendance_Percentage is below 75% (e.g., using a red color indicator)
5. THE Report_Screen SHALL sort the student list in ascending order by student ID
6. WHEN attendance data is loading, THE Report_Screen SHALL display a loading indicator

### Requirement 7: Error Handling

**User Story:** As an admin, I want clear feedback when data cannot be loaded, so that I understand what went wrong and can retry.

#### Acceptance Criteria

1. IF the Firestore query for courses fails, THEN THE Report_Screen SHALL display an error message indicating that course data could not be retrieved
2. IF the Realtime Database query for students fails, THEN THE Report_Screen SHALL display an error message indicating that student data could not be retrieved
3. IF the Firestore query for attendance records fails, THEN THE Report_Screen SHALL display an error message indicating that attendance data could not be retrieved
4. THE Report_Screen SHALL provide a retry mechanism so the admin can reload the data after an error
