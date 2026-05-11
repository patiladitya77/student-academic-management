# Design Document: Teacher Attendance Date and Time Selection

## Overview

This design document outlines the implementation of date and time slot selection functionality for the teacher attendance marking system in the Student Academic Management (SAM) Flutter application. The feature enhances the existing attendance system by allowing teachers to mark attendance for specific dates and time slots, rather than only the current session.

### Current System Analysis

The existing attendance system has the following characteristics:

**Data Structure:**

- Firestore path: `Attendance/{semester}/{courseName}/{studentId}`
- Each student document contains:
  - `present`: Integer count of attended classes
  - `total`: Integer count of total classes
  - `last_status`: String ('P' or 'A')
  - `date`: Timestamp of last update

**Current Limitations:**

- No explicit date or time slot tracking per attendance record
- Cannot mark attendance for past sessions
- Cannot distinguish between multiple sessions on the same day
- Attendance records are cumulative counters without session-level granularity

### Design Goals

1. **Preserve Existing Functionality**: Maintain backward compatibility with existing attendance data and calculations
2. **Add Session-Level Tracking**: Enable tracking of individual attendance sessions by date and time slot
3. **Prevent Duplicates**: Warn teachers when marking attendance for already-recorded sessions
4. **Intuitive UX**: Provide a clear, step-by-step flow for date and time selection
5. **Enhanced Reporting**: Enable date and time-filtered attendance reports

## Architecture

### High-Level Flow

```
Course Selection → Date Selection → Time Slot Selection → Attendance Marking → Firestore Storage
```

### Component Structure

```
TeacherAttendance (existing)
    ↓
DateSelectionScreen (new)
    ↓
TimeSlotSelectionScreen (new)
    ↓
AttendancePage (modified)
    ↓
AttendanceService (new)
```

### Navigation Architecture

The feature implements a sequential navigation flow with state preservation:

1. **Entry Point**: Teacher selects course from semester screen (existing)
2. **Date Selection**: New screen for selecting attendance date
3. **Time Slot Selection**: New screen for selecting time slot
4. **Attendance Marking**: Modified existing screen with date/time context
5. **Back Navigation**: Each screen preserves previous selections when navigating back

## Components and Interfaces

### 1. DateSelectionScreen

**Purpose**: Allow teachers to select a specific date for attendance marking.

**State Management:**

```dart
class DateSelectionScreen extends StatefulWidget {
  final String semester;
  final String courseName;
  final String teacherId;
  final String teacherName;

  const DateSelectionScreen({
    required this.semester,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
  });
}

class _DateSelectionScreenState extends State<DateSelectionScreen> {
  DateTime selectedDate = DateTime.now();
  final DateTime earliestDate = DateTime.now().subtract(Duration(days: 90));
  final DateTime latestDate = DateTime.now();
}
```

**UI Components:**

- Calendar widget (Flutter's `showDatePicker` or custom calendar)
- Date display showing selected date in readable format
- Continue button to proceed to time slot selection
- Back button to return to course selection

**Validation Logic:**

- Ensure selected date is within 90 days in the past
- Ensure selected date is not in the future
- Display error message for invalid dates

**Navigation:**

```dart
void _proceedToTimeSlotSelection() {
  if (_validateDate(selectedDate)) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimeSlotSelectionScreen(
          semester: widget.semester,
          courseName: widget.courseName,
          teacherId: widget.teacherId,
          teacherName: widget.teacherName,
          selectedDate: selectedDate,
        ),
      ),
    );
  }
}
```

### 2. TimeSlotSelectionScreen

**Purpose**: Allow teachers to select a specific time slot for the selected date.

**State Management:**

```dart
class TimeSlotSelectionScreen extends StatefulWidget {
  final String semester;
  final String courseName;
  final String teacherId;
  final String teacherName;
  final DateTime selectedDate;

  const TimeSlotSelectionScreen({
    required this.semester,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.selectedDate,
  });
}

class _TimeSlotSelectionScreenState extends State<TimeSlotSelectionScreen> {
  List<TimeSlot> availableTimeSlots = [];
  TimeSlot? selectedTimeSlot;
  bool isLoading = true;
  bool hasExistingRecords = false;
  DateTime? existingRecordDate;
}
```

**Time Slot Model:**

```dart
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

  factory TimeSlot.fromFirestore(Map<String, dynamic> data, String id) {
    return TimeSlot(
      id: id,
      displayName: data['display_name'] ?? 'Period $id',
      startTime: data['start_time'] ?? '',
      endTime: data['end_time'] ?? '',
    );
  }
}
```

**UI Components:**

- List of selectable time slots (retrieved from Firestore or hardcoded)
- Warning banner if attendance already exists for selected date/time
- Continue button to proceed to attendance marking
- Back button to return to date selection

**Duplicate Detection:**

```dart
Future<void> _checkExistingAttendance() async {
  final sessionDoc = await FirebaseFirestore.instance
      .collection('Attendance')
      .doc(widget.semester)
      .collection(widget.courseName)
      .doc('sessions')
      .collection('records')
      .where('date', isEqualTo: _formatDate(widget.selectedDate))
      .where('time_slot_id', isEqualTo: selectedTimeSlot!.id)
      .limit(1)
      .get();

  if (sessionDoc.docs.isNotEmpty) {
    setState(() {
      hasExistingRecords = true;
      existingRecordDate = (sessionDoc.docs.first['created_at'] as Timestamp).toDate();
    });
  }
}
```

**Navigation:**

```dart
void _proceedToAttendanceMarking() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AttendancePage(
        semester: widget.semester,
        courseName: widget.courseName,
        id: widget.teacherId,
        name: widget.teacherName,
        selectedDate: widget.selectedDate,
        selectedTimeSlot: selectedTimeSlot!,
      ),
    ),
  );
}
```

### 3. Modified AttendancePage

**Purpose**: Mark attendance for students with date and time slot context.

**Updated Constructor:**

```dart
class AttendancePage extends StatefulWidget {
  final String semester;
  final String id;
  final String name;
  final String courseName;
  final DateTime selectedDate;
  final TimeSlot selectedTimeSlot;

  const AttendancePage({
    super.key,
    required this.semester,
    required this.courseName,
    required this.id,
    required this.name,
    required this.selectedDate,
    required this.selectedTimeSlot,
  });
}
```

**UI Enhancements:**

- Header section displaying:
  - Course name
  - Semester
  - Selected date (formatted: "Monday, January 15, 2024")
  - Selected time slot (e.g., "Period 1: 9:00 AM - 10:00 AM")
- Sticky header that remains visible while scrolling
- Warning banner if overwriting existing records

**Modified Save Logic:**

```dart
Future<void> saveAttendance() async {
  setState(() {
    _loading = true;
  });

  try {
    final batch = FirebaseFirestore.instance.batch();
    final sessionId = _generateSessionId(widget.selectedDate, widget.selectedTimeSlot);

    // Save session-level record
    final sessionRef = FirebaseFirestore.instance
        .collection('Attendance')
        .doc(widget.semester)
        .collection(widget.courseName)
        .doc('sessions')
        .collection('records')
        .doc(sessionId);

    batch.set(sessionRef, {
      'date': _formatDate(widget.selectedDate),
      'time_slot_id': widget.selectedTimeSlot.id,
      'time_slot_name': widget.selectedTimeSlot.displayName,
      'created_at': FieldValue.serverTimestamp(),
      'teacher_id': widget.id,
      'teacher_name': widget.name,
    });

    // Update student records
    for (var studentId in attendance.keys) {
      String status = attendance[studentId] ?? 'A';

      // Update cumulative counters
      final studentRef = FirebaseFirestore.instance
          .collection('Attendance')
          .doc(widget.semester)
          .collection(widget.courseName)
          .doc(studentId);

      DocumentSnapshot studentSnapshot = await studentRef.get();
      int present = 0;
      int total = 0;

      if (studentSnapshot.exists) {
        Map<String, dynamic> studentData = studentSnapshot.data() as Map<String, dynamic>;
        present = studentData['present'] ?? 0;
        total = studentData['total'] ?? 0;
      }

      if (status == 'P') {
        present++;
      }
      total++;

      batch.set(studentRef, {
        'present': present,
        'total': total,
        'last_status': status,
        'date': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save individual session record
      final studentSessionRef = sessionRef.collection('students').doc(studentId);
      batch.set(studentSessionRef, {
        'status': status,
        'marked_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attendance submitted successfully!')));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to submit attendance: $e')));
  } finally {
    setState(() {
      _loading = false;
    });
  }
}
```

### 4. AttendanceService

**Purpose**: Centralized service for attendance-related operations.

**Interface:**

```dart
class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch time slots for a course
  Future<List<TimeSlot>> getTimeSlots(String semester, String courseName) async {
    // Implementation
  }

  // Check if attendance exists for date/time combination
  Future<bool> hasExistingAttendance(
    String semester,
    String courseName,
    DateTime date,
    String timeSlotId,
  ) async {
    // Implementation
  }

  // Get existing attendance session details
  Future<Map<String, dynamic>?> getExistingSession(
    String semester,
    String courseName,
    DateTime date,
    String timeSlotId,
  ) async {
    // Implementation
  }

  // Generate unique session ID
  String generateSessionId(DateTime date, TimeSlot timeSlot) {
    final dateStr = DateFormat('yyyyMMdd').format(date);
    return '${dateStr}_${timeSlot.id}';
  }

  // Format date for storage
  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Format date for display
  String formatDateDisplay(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }
}
```

## Data Models

### Firestore Schema Changes

#### Current Structure

```
Attendance/
  {semester}/
    {courseName}/
      {studentId}/
        present: int
        total: int
        last_status: string
        date: timestamp
```

#### Enhanced Structure

```
Attendance/
  {semester}/
    {courseName}/
      {studentId}/                          # Cumulative records (existing)
        present: int
        total: int
        last_status: string
        date: timestamp

      sessions/                             # New: Session-level tracking
        records/
          {sessionId}/                      # Format: YYYYMMDD_timeSlotId
            date: string                    # Format: YYYY-MM-DD
            time_slot_id: string
            time_slot_name: string
            created_at: timestamp
            teacher_id: string
            teacher_name: string

            students/
              {studentId}/
                status: string              # 'P' or 'A'
                marked_at: timestamp
```

#### Time Slot Configuration (Optional)

```
TimeSlots/
  {semester}/
    {timeSlotId}/
      display_name: string
      start_time: string
      end_time: string
      order: int
```

### Dart Models

**TimeSlot Model:**

```dart
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

  factory TimeSlot.fromFirestore(Map<String, dynamic> data, String id) {
    return TimeSlot(
      id: id,
      displayName: data['display_name'] ?? 'Period $id',
      startTime: data['start_time'] ?? '',
      endTime: data['end_time'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'display_name': displayName,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}
```

**AttendanceSession Model:**

```dart
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
```

**StudentAttendanceRecord Model:**

```dart
class StudentAttendanceRecord {
  final String studentId;
  final String status;
  final DateTime markedAt;

  StudentAttendanceRecord({
    required this.studentId,
    required this.status,
    required this.markedAt,
  });

  factory StudentAttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentAttendanceRecord(
      studentId: doc.id,
      status: data['status'],
      markedAt: (data['marked_at'] as Timestamp).toDate(),
    );
  }
}
```

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property 1: Date Range Validation

_For any_ date selected by a teacher, the system should accept the date if and only if it falls within the range of 90 days in the past up to the current date, and should display an error message and prevent navigation for dates outside this range.

**Validates: Requirements 1.2, 1.4, 1.5**

### Property 2: Time Slot Display Completeness

_For any_ course with configured time slots, when a teacher selects a valid date, all available time slots for that course should be displayed in the time slot selector.

**Validates: Requirements 2.2**

### Property 3: Session Context Display

_For any_ selected date and time slot combination, when a teacher reaches the attendance marking screen, the rendered output should contain both the formatted date and the time slot information prominently displayed.

**Validates: Requirements 2.4, 5.1, 5.2, 5.4**

### Property 4: Date Format Consistency

_For any_ date displayed in the attendance marking interface, the formatted output should match the pattern "DayOfWeek, Month Day, Year" (e.g., "Monday, January 15, 2024").

**Validates: Requirements 5.3**

### Property 5: Session Metadata Storage

_For any_ attendance submission, the stored record should include both the selected date (in YYYY-MM-DD format) and the selected time slot ID, allowing the record to be uniquely identified by the date-time combination.

**Validates: Requirements 3.1, 3.2**

### Property 6: Queryable Session Structure

_For any_ stored attendance session, querying the database by date and time slot ID should successfully retrieve that specific session's records.

**Validates: Requirements 3.3**

### Property 7: Session Idempotence

_For any_ date and time slot combination, submitting attendance twice for the same session should result in the same final state as submitting once (no duplicate session records should exist, and student records should reflect the most recent submission).

**Validates: Requirements 3.4**

### Property 8: Cumulative Counter Accuracy

_For any_ sequence of attendance submissions across multiple sessions, the cumulative present and total counts for each student should equal the sum of their individual session statuses (present count = number of 'P' statuses, total count = number of sessions).

**Validates: Requirements 3.5**

### Property 9: Duplicate Session Detection

_For any_ date and time slot combination that already has attendance records, when a teacher selects that combination, the system should detect the existing records and display a warning message containing the creation timestamp of the existing session.

**Validates: Requirements 4.1, 4.2, 4.3**

### Property 10: Navigation State Preservation

_For any_ selected date, when a teacher navigates from the attendance marking screen back to the time slot selection screen, the previously selected date should remain unchanged and available in the state.

**Validates: Requirements 6.5**

### Property 11: Date Range Report Filtering

_For any_ date range filter applied to an attendance report, the generated report should include only attendance sessions where the session date falls within the specified range (inclusive).

**Validates: Requirements 7.2**

### Property 12: Time Slot Report Filtering

_For any_ set of time slot IDs selected as filters for an attendance report, the generated report should include only attendance sessions where the session's time slot ID is in the selected set.

**Validates: Requirements 7.3**

### Property 13: Report Metadata Display

_For any_ generated attendance report with date range and time slot filters applied, the PDF output should contain text displaying the applied filter criteria (date range and time slot names).

**Validates: Requirements 7.4**

### Property 14: Filtered Attendance Percentage Calculation

_For any_ attendance report with filters applied, the calculated attendance percentage for each student should be based only on the sessions that match the filter criteria (present count from filtered sessions / total count from filtered sessions \* 100).

**Validates: Requirements 7.5**

### Property 15: Legacy Data Compatibility

_For any_ existing attendance record without explicit date and time slot fields, the system should successfully read the record and treat the 'date' timestamp field as the session date.

**Validates: Requirements 8.1, 8.2**

### Property 16: Legacy Data Migration

_For any_ existing attendance record in the old format, when that record is updated through the new system, the updated record should include the new date and time slot fields while preserving the existing present/total counts.

**Validates: Requirements 8.3**

### Property 17: Counter Calculation Consistency

_For any_ student's attendance data, the present/total count calculation should produce the same result whether calculated using the old cumulative counter method or by summing individual session records.

**Validates: Requirements 8.4**

## Error Handling

### Date Selection Errors

**Invalid Date Range:**

- **Error**: Teacher selects a date more than 90 days in the past or in the future
- **Handling**: Display error dialog with message "Please select a date within the last 90 days" and prevent navigation to time slot selection
- **Recovery**: Allow teacher to select a different date

**Date Picker Failure:**

- **Error**: Date picker widget fails to load or crashes
- **Handling**: Log error, display fallback text input for manual date entry with validation
- **Recovery**: Validate manually entered date and proceed if valid

### Time Slot Selection Errors

**No Time Slots Available:**

- **Error**: No time slots configured for the selected course
- **Handling**: Display message "No time slots configured for this course. Please contact administrator." with option to go back
- **Recovery**: Allow teacher to return to date selection or exit

**Firestore Connection Error:**

- **Error**: Cannot retrieve time slots from Firestore
- **Handling**: Display error message "Unable to load time slots. Please check your connection." with retry button
- **Recovery**: Provide retry mechanism, fallback to default time slots if configured

### Attendance Submission Errors

**Network Failure During Submission:**

- **Error**: Network connection lost while submitting attendance
- **Handling**: Display error message "Submission failed. Please check your connection and try again."
- **Recovery**: Preserve attendance data in local state, allow retry without re-marking

**Partial Batch Write Failure:**

- **Error**: Some documents in the batch write succeed while others fail
- **Handling**: Log failed documents, display warning "Attendance partially saved. Some records may need resubmission."
- **Recovery**: Identify failed student records, allow teacher to resubmit only failed records

**Duplicate Session Conflict:**

- **Error**: Another teacher submits attendance for the same session simultaneously
- **Handling**: Detect conflict, display warning with options: "Attendance already exists for this session. View existing / Overwrite / Cancel"
- **Recovery**: Allow teacher to choose action, require confirmation for overwrite

### Report Generation Errors

**No Data for Selected Filters:**

- **Error**: Selected date range and time slots have no attendance records
- **Handling**: Display message "No attendance records found for the selected criteria."
- **Recovery**: Allow teacher to adjust filters and regenerate

**PDF Generation Failure:**

- **Error**: PDF library fails to generate document
- **Handling**: Log error, display message "Failed to generate PDF. Please try again."
- **Recovery**: Provide retry mechanism, offer alternative export format (CSV) if available

**Large Dataset Timeout:**

- **Error**: Report generation takes too long for large date ranges
- **Handling**: Display progress indicator, implement pagination or chunking
- **Recovery**: Suggest narrower date range, implement background processing with notification

### Data Migration Errors

**Legacy Record Format Mismatch:**

- **Error**: Old attendance record has unexpected structure
- **Handling**: Log warning, use default values for missing fields, continue processing
- **Recovery**: Mark record for manual review, notify administrator

**Migration Conflict:**

- **Error**: Cannot determine correct date/time for legacy record
- **Handling**: Use timestamp from 'date' field, assign default time slot "Legacy Session"
- **Recovery**: Flag record for manual verification, allow administrator to correct

## Testing Strategy

### Overview

This feature will be tested using a dual approach combining unit tests for specific scenarios and property-based tests for comprehensive validation across many inputs.

### Unit Testing

Unit tests will focus on:

**Specific Examples:**

- Date selector defaults to current date on screen load (Requirement 1.3)
- Navigation flow proceeds from date selection to time slot selection (Requirement 2.1)
- Time slot selection navigates to attendance marking screen (Requirement 2.3)
- Sequential navigation flow follows correct order (Requirement 6.1)
- Back button navigation works at each step (Requirement 6.4)
- Duplicate warning displays options to view/overwrite/cancel (Requirement 4.4)
- Overwrite action requires confirmation (Requirement 4.5)
- Report generation includes date and time slot filters (Requirement 7.1)

**Edge Cases:**

- Empty time slot list handling
- Null or missing date fields in legacy data
- Simultaneous submissions by multiple teachers
- Network interruption during batch write
- Very large student lists (performance)

**Integration Tests:**

- Time slots retrieved from Firestore configuration (Requirement 2.5)
- Attendance data written to correct Firestore paths
- PDF report generation with real data
- Legacy data migration during update operations

### Property-Based Testing

Property-based tests will validate universal behaviors across randomized inputs using the **fast_check** library for Dart (or **test_api** with custom generators).

**Configuration:**

- Minimum 100 iterations per property test
- Each test tagged with: **Feature: teacher-attendance-date-time-selection, Property {number}: {property_text}**

**Property Test Implementations:**

1. **Property 1: Date Range Validation**
   - Generate: Random dates spanning 180 days before and after current date
   - Test: Dates within 90 days past to current are accepted, others rejected
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 1: Date range validation_

2. **Property 2: Time Slot Display Completeness**
   - Generate: Random lists of time slots (0-10 slots)
   - Test: All generated time slots appear in selector
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 2: Time slot display completeness_

3. **Property 3: Session Context Display**
   - Generate: Random dates and time slots
   - Test: Both date and time slot appear in rendered output
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 3: Session context display_

4. **Property 4: Date Format Consistency**
   - Generate: Random dates
   - Test: Formatted output matches "DayOfWeek, Month Day, Year" pattern
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 4: Date format consistency_

5. **Property 5: Session Metadata Storage**
   - Generate: Random attendance submissions with dates and time slots
   - Test: Stored records contain both date (YYYY-MM-DD) and time slot ID
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 5: Session metadata storage_

6. **Property 6: Queryable Session Structure**
   - Generate: Random attendance sessions
   - Test: Query by date and time slot successfully retrieves the session
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 6: Queryable session structure_

7. **Property 7: Session Idempotence**
   - Generate: Random attendance data
   - Test: Submitting twice produces same result as submitting once
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 7: Session idempotence_

8. **Property 8: Cumulative Counter Accuracy**
   - Generate: Random sequences of attendance sessions with varying P/A statuses
   - Test: Cumulative counters equal sum of individual session statuses
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 8: Cumulative counter accuracy_

9. **Property 9: Duplicate Session Detection**
   - Generate: Random existing sessions, then attempt to create duplicate
   - Test: System detects duplicate and displays warning with timestamp
   - Tag: _Feature: teacher-attendance-date-time-selection, Property 9: Duplicate session detection_

10. **Property 10: Navigation State Preservation**
    - Generate: Random dates
    - Test: After back navigation, selected date remains unchanged
    - Tag: _Feature: teacher-attendance-date-time-selection, Property 10: Navigation state preservation_

11. **Property 11: Date Range Report Filtering**
    - Generate: Random attendance sessions and date range filters
    - Test: Report includes only sessions within date range
    - Tag: _Feature: teacher-attendance-date-time-selection, Property 11: Date range report filtering_

12. **Property 12: Time Slot Report Filtering**
    - Generate: Random attendance sessions and time slot filters
    - Test: Report includes only sessions matching time slot filters
    - Tag: _Feature: teacher-attendance-date-time-selection, Property 12: Time slot report filtering_

13. **Property 13: Report Metadata Display**
    - Generate: Random filter criteria
    - Test: PDF output contains filter criteria text
    - Tag: _Feature: teacher-attendance-date-time-selection, Property 13: Report metadata display_

14. **Property 14: Filtered Attendance Percentage Calculation**
    - Generate: Random attendance data with filters
    - Test: Percentage calculated only from filtered sessions
    - Tag: _Feature: teacher-attendance-date-time-selection, Property 14: Filtered attendance percentage calculation_

15. **Property 15: Legacy Data Compatibility**
    - Generate: Random old-format attendance records
    - Test: System reads records and uses 'date' timestamp field
    - Tag: _Feature: teacher-attendance-date-time-selection, Property 15: Legacy data compatibility_

16. **Property 16: Legacy Data Migration**
    - Generate: Random old-format records
    - Test: After update, records have new fields and preserved counters
    - Tag: _Feature: teacher-attendance-date-time-selection, Property 16: Legacy data migration_

17. **Property 17: Counter Calculation Consistency**
    - Generate: Random attendance data
    - Test: Old and new calculation methods produce same result
    - Tag: _Feature: teacher-attendance-date-time-selection, Property 17: Counter calculation consistency_

### Test Data Generators

**Date Generator:**

```dart
Arbitrary<DateTime> dateGenerator() {
  return Arbitrary.dateTime(
    min: DateTime.now().subtract(Duration(days: 180)),
    max: DateTime.now().add(Duration(days: 180)),
  );
}
```

**Time Slot Generator:**

```dart
Arbitrary<TimeSlot> timeSlotGenerator() {
  return Arbitrary.combine3(
    Arbitrary.string(minLength: 1, maxLength: 10),
    Arbitrary.string(pattern: r'\d{1,2}:\d{2} [AP]M'),
    Arbitrary.string(pattern: r'\d{1,2}:\d{2} [AP]M'),
    (id, start, end) => TimeSlot(
      id: id,
      displayName: 'Period $id',
      startTime: start,
      endTime: end,
    ),
  );
}
```

**Attendance Status Generator:**

```dart
Arbitrary<String> attendanceStatusGenerator() {
  return Arbitrary.oneOf(['P', 'A']);
}
```

**Student Attendance Map Generator:**

```dart
Arbitrary<Map<String, String>> studentAttendanceGenerator(int studentCount) {
  return Arbitrary.map(
    Arbitrary.string(minLength: 5, maxLength: 15),
    attendanceStatusGenerator(),
    minSize: studentCount,
    maxSize: studentCount,
  );
}
```

### Testing Tools

- **Unit Testing**: Flutter's built-in `test` package
- **Property-Based Testing**: Custom generators using `test_api` or port of QuickCheck concepts
- **Widget Testing**: Flutter's `flutter_test` package for UI components
- **Integration Testing**: `integration_test` package for end-to-end flows
- **Mocking**: `mockito` package for Firestore and service mocks

### Test Coverage Goals

- **Unit Test Coverage**: Minimum 80% code coverage for business logic
- **Property Test Coverage**: All 17 correctness properties implemented
- **Widget Test Coverage**: All new UI components (DateSelectionScreen, TimeSlotSelectionScreen, modified AttendancePage)
- **Integration Test Coverage**: Complete navigation flow from course selection to attendance submission

### Continuous Integration

- Run all unit tests on every commit
- Run property tests (100 iterations) on every pull request
- Run integration tests on staging environment before production deployment
- Generate coverage reports and fail builds below 80% coverage threshold
