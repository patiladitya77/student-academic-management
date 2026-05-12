# Requirements Document

## Introduction

This feature modifies the teacher attendance report generation system to produce Excel files instead of PDF files. The Excel format provides a detailed view with individual lecture dates as columns, showing presence/absence status for each student on each date, along with overall attendance percentage.

## Glossary

- **Report_Generator**: The system component responsible for generating attendance reports
- **Excel_File**: A spreadsheet file in .xlsx format containing attendance data
- **Attendance_Record**: A record indicating whether a student was present (P) or absent (A) on a specific date
- **Attendance_Percentage**: The ratio of lectures attended to total lectures, expressed as a percentage
- **Lecture_Date**: A specific date when a lecture was conducted for the course
- **Student_ID**: The unique identifier for a student
- **Time_Slot**: A specific time period when a lecture is scheduled
- **Date_Range**: The start and end dates used to filter attendance records
- **Session_Record**: A database record representing a single lecture session with attendance data

## Requirements

### Requirement 1: Excel File Generation

**User Story:** As a teacher, I want to generate attendance reports in Excel format, so that I can analyze and manipulate attendance data more easily.

#### Acceptance Criteria

1. WHEN a teacher requests an attendance report, THE Report_Generator SHALL generate an Excel_File instead of a PDF file
2. THE Excel_File SHALL have a .xlsx file extension
3. THE Report_Generator SHALL use an Excel library compatible with Flutter/Dart
4. WHEN the Excel_File is generated, THE Report_Generator SHALL save it to the device storage
5. THE Report_Generator SHALL provide a mechanism to open or share the generated Excel_File

### Requirement 2: Excel Column Structure

**User Story:** As a teacher, I want the Excel file to have student IDs, individual lecture dates, and attendance percentage as columns, so that I can see detailed attendance patterns.

#### Acceptance Criteria

1. THE Excel_File SHALL have "student_id" as the first column
2. THE Excel_File SHALL have one column for each Lecture_Date in the filtered date range
3. THE Excel_File SHALL have "attendance_percentage" as the last column
4. THE Excel_File SHALL display Lecture_Date columns in chronological order
5. THE Excel_File SHALL format Lecture_Date column headers in a readable date format
6. WHEN no lectures were conducted in the date range, THE Excel_File SHALL contain only "student_id" and "attendance_percentage" columns

### Requirement 3: Excel Row Data Population

**User Story:** As a teacher, I want each row to show a student's attendance status for each lecture date, so that I can quickly identify attendance patterns.

#### Acceptance Criteria

1. THE Excel_File SHALL have one row per student
2. WHEN a student was present on a Lecture_Date, THE Excel_File SHALL display "P" in the corresponding date column
3. WHEN a student was absent on a Lecture_Date, THE Excel_File SHALL display "A" in the corresponding date column
4. THE Excel_File SHALL display the Student_ID in the "student_id" column for each row
5. THE Excel_File SHALL display the Attendance_Percentage in the "attendance_percentage" column for each row
6. THE Excel_File SHALL format Attendance_Percentage as a number with two decimal places followed by a "%" symbol

### Requirement 4: Attendance Data Retrieval

**User Story:** As a teacher, I want the Excel report to include all attendance data within my selected filters, so that the report accurately reflects the attendance I want to analyze.

#### Acceptance Criteria

1. THE Report_Generator SHALL retrieve Session_Record data from the database based on the selected Date_Range
2. WHERE Time_Slot filters are selected, THE Report_Generator SHALL retrieve only Session_Record data matching the selected Time_Slot values
3. THE Report_Generator SHALL extract individual Lecture_Date values from Session_Record data
4. THE Report_Generator SHALL extract student presence/absence status from Session_Record data
5. THE Report_Generator SHALL calculate Attendance_Percentage for each student based on retrieved Session_Record data
6. THE Report_Generator SHALL include legacy attendance data when the legacy Time_Slot is selected

### Requirement 5: Excel File Metadata

**User Story:** As a teacher, I want the Excel file to include course and filter information, so that I can identify what the report contains.

#### Acceptance Criteria

1. THE Excel_File SHALL include a header row with course name
2. THE Excel_File SHALL include a header row with semester information
3. THE Excel_File SHALL include a header row with the Date_Range filter applied
4. WHERE Time_Slot filters were selected, THE Excel_File SHALL include a header row with the selected Time_Slot names
5. THE Excel_File SHALL place metadata header rows above the column headers
6. THE Excel_File SHALL visually distinguish metadata rows from data rows

### Requirement 6: User Interface Modifications

**User Story:** As a teacher, I want the report generation button to clearly indicate it generates an Excel file, so that I know what format to expect.

#### Acceptance Criteria

1. THE Report_Generator SHALL update the button text to indicate Excel file generation
2. WHEN the Report_Generator is generating the Excel_File, THE Report_Generator SHALL display a loading indicator
3. WHEN the Excel_File generation succeeds, THE Report_Generator SHALL display a success message
4. WHEN the Excel_File generation fails, THE Report_Generator SHALL display an error message with failure details

### Requirement 7: Excel File Handling

**User Story:** As a teacher, I want to easily access the generated Excel file, so that I can open it in a spreadsheet application.

#### Acceptance Criteria

1. WHEN the Excel_File is generated, THE Report_Generator SHALL provide an option to open the file
2. WHEN the Excel_File is generated, THE Report_Generator SHALL provide an option to share the file
3. THE Report_Generator SHALL store the Excel_File in a user-accessible directory
4. THE Report_Generator SHALL generate a unique filename for each Excel_File to prevent overwrites
5. THE Excel_File filename SHALL include the course name and generation timestamp

### Requirement 8: Data Consistency

**User Story:** As a teacher, I want the Excel report to contain the same data that would have been in the PDF report, so that the format change doesn't affect data accuracy.

#### Acceptance Criteria

1. THE Report_Generator SHALL use the same data retrieval logic for Excel_File generation as was used for PDF generation
2. THE Report_Generator SHALL apply the same Date_Range filters for Excel_File generation as were applied for PDF generation
3. THE Report_Generator SHALL apply the same Time_Slot filters for Excel_File generation as were applied for PDF generation
4. THE Report_Generator SHALL calculate Attendance_Percentage using the same formula as was used for PDF generation
5. THE Report_Generator SHALL include the same students in the Excel_File as would have been included in the PDF

### Requirement 9: Excel Formatting

**User Story:** As a teacher, I want the Excel file to be well-formatted and readable, so that I can easily understand the data.

#### Acceptance Criteria

1. THE Excel_File SHALL use bold formatting for column headers
2. THE Excel_File SHALL use bold formatting for metadata rows
3. THE Excel_File SHALL apply borders to data cells for readability
4. THE Excel_File SHALL auto-size columns to fit content
5. THE Excel_File SHALL freeze the header row so it remains visible when scrolling
6. THE Excel_File SHALL center-align attendance status cells (P/A)

### Requirement 10: Error Handling

**User Story:** As a teacher, I want clear error messages if report generation fails, so that I can understand what went wrong.

#### Acceptance Criteria

1. WHEN the database query fails, THE Report_Generator SHALL display an error message indicating database access failure
2. WHEN no attendance data is found, THE Report_Generator SHALL display a message indicating no records match the filters
3. WHEN Excel_File creation fails, THE Report_Generator SHALL display an error message indicating file generation failure
4. WHEN file storage fails, THE Report_Generator SHALL display an error message indicating storage failure
5. THE Report_Generator SHALL log detailed error information for debugging purposes
