# Requirements Document

## Introduction

This feature enhances the teacher attendance marking functionality in the Student Academic Management (SAM) application by allowing teachers to select a specific date and time slot before marking attendance. Currently, teachers can only mark attendance for the current session, which limits their ability to record attendance for past sessions or pre-schedule attendance marking. This feature provides flexibility for teachers to manage attendance records more effectively.

## Glossary

- **Attendance_System**: The module within the SAM application that handles attendance marking and tracking
- **Teacher**: A user with teacher role who marks attendance for students in their courses
- **Time_Slot**: A specific period during the day when a class session occurs (e.g., "9:00 AM - 10:00 AM", "Period 1")
- **Attendance_Record**: A record containing student presence/absence status for a specific date and time slot
- **Course**: A subject or class that a teacher teaches to students in a specific semester
- **Date_Selector**: UI component that allows teachers to choose a specific date
- **Time_Slot_Selector**: UI component that allows teachers to choose a specific time slot
- **Current_Session**: The present date and time when the teacher is marking attendance
- **Past_Session**: A date and time slot that has already occurred
- **Firestore**: The Firebase database where attendance records are stored

## Requirements

### Requirement 1: Date Selection Interface

**User Story:** As a teacher, I want to select a specific date before marking attendance, so that I can record attendance for past sessions or future sessions.

#### Acceptance Criteria

1. WHEN a teacher navigates to the attendance marking screen, THE Attendance_System SHALL display a Date_Selector before showing the student list
2. THE Date_Selector SHALL allow selection of dates from the past 90 days up to the current date
3. THE Date_Selector SHALL default to the current date
4. WHEN a teacher selects a date, THE Attendance_System SHALL validate that the date is within the allowed range
5. IF a teacher selects a date outside the allowed range, THEN THE Attendance_System SHALL display an error message and prevent proceeding to time slot selection

### Requirement 2: Time Slot Selection Interface

**User Story:** As a teacher, I want to select a specific time slot for the selected date, so that I can mark attendance for the correct class session.

#### Acceptance Criteria

1. WHEN a teacher has selected a valid date, THE Attendance_System SHALL display a Time_Slot_Selector
2. THE Time_Slot_Selector SHALL display all available time slots for the selected course
3. WHEN a teacher selects a time slot, THE Attendance_System SHALL proceed to the student attendance marking screen
4. THE Attendance_System SHALL display the selected date and time slot at the top of the attendance marking screen
5. WHERE time slots are configurable, THE Attendance_System SHALL retrieve time slot options from Firestore configuration

### Requirement 3: Attendance Record Storage with Date and Time

**User Story:** As a teacher, I want attendance records to be stored with the specific date and time slot I selected, so that attendance history is accurate and traceable.

#### Acceptance Criteria

1. WHEN a teacher submits attendance, THE Attendance_System SHALL store the selected date with each Attendance_Record
2. WHEN a teacher submits attendance, THE Attendance_System SHALL store the selected time slot with each Attendance_Record
3. THE Attendance_System SHALL store attendance records in a structure that allows querying by date and time slot
4. WHEN storing attendance for a date and time slot that already has records, THE Attendance_System SHALL update the existing records rather than creating duplicates
5. THE Attendance_System SHALL maintain the existing present/total count logic while associating counts with specific date-time combinations

### Requirement 4: Duplicate Attendance Prevention

**User Story:** As a teacher, I want to be warned if I'm marking attendance for a date and time slot that already has records, so that I don't accidentally overwrite existing attendance data.

#### Acceptance Criteria

1. WHEN a teacher selects a date and time slot combination, THE Attendance_System SHALL check if attendance records already exist for that combination
2. IF attendance records exist for the selected date and time slot, THEN THE Attendance_System SHALL display a warning message indicating that records already exist
3. THE warning message SHALL display the date when the existing records were created
4. THE Attendance_System SHALL provide options to either view existing records, overwrite them, or cancel and select a different date/time
5. WHEN a teacher chooses to overwrite existing records, THE Attendance_System SHALL require confirmation before proceeding

### Requirement 5: Date and Time Display

**User Story:** As a teacher, I want to clearly see which date and time slot I'm marking attendance for, so that I can verify I'm recording attendance for the correct session.

#### Acceptance Criteria

1. WHILE marking attendance, THE Attendance_System SHALL display the selected date prominently at the top of the screen
2. WHILE marking attendance, THE Attendance_System SHALL display the selected time slot prominently at the top of the screen
3. THE date display SHALL use a clear, readable format (e.g., "Monday, January 15, 2024")
4. THE Attendance_System SHALL display the course name, semester, date, and time slot together in the header section
5. THE displayed date and time slot SHALL remain visible while scrolling through the student list

### Requirement 6: Navigation Flow

**User Story:** As a teacher, I want a clear step-by-step flow for selecting date, time slot, and marking attendance, so that the process is intuitive and efficient.

#### Acceptance Criteria

1. THE Attendance_System SHALL implement a sequential flow: Course Selection → Date Selection → Time Slot Selection → Attendance Marking
2. WHEN a teacher completes date selection, THE Attendance_System SHALL automatically proceed to time slot selection
3. WHEN a teacher completes time slot selection, THE Attendance_System SHALL automatically proceed to the attendance marking screen
4. THE Attendance_System SHALL provide a back button at each step to return to the previous selection
5. WHEN a teacher presses the back button from the attendance marking screen, THE Attendance_System SHALL return to time slot selection without losing the selected date

### Requirement 7: Attendance Report Enhancement

**User Story:** As a teacher, I want attendance reports to include date and time slot information, so that I can generate accurate historical attendance records.

#### Acceptance Criteria

1. WHEN generating an attendance report, THE Attendance_System SHALL include date and time slot filters
2. THE Attendance_System SHALL allow teachers to generate reports for a specific date range
3. THE Attendance_System SHALL allow teachers to generate reports for specific time slots
4. THE generated PDF report SHALL display the date range and time slots included in the report
5. THE Attendance_System SHALL calculate attendance percentages based on the filtered date and time slot criteria

### Requirement 8: Backward Compatibility

**User Story:** As a system administrator, I want the new date/time selection feature to work with existing attendance data, so that historical records remain accessible and valid.

#### Acceptance Criteria

1. THE Attendance_System SHALL continue to support existing attendance records that do not have explicit date and time slot fields
2. WHEN displaying existing attendance records without date/time information, THE Attendance_System SHALL treat them as belonging to the date stored in the 'date' timestamp field
3. THE Attendance_System SHALL migrate existing attendance records to include date and time slot fields when they are next updated
4. THE present/total count calculation SHALL remain consistent with the existing implementation
5. THE Attendance_System SHALL maintain compatibility with the existing Firestore data structure while adding new date/time fields
