# Implementation Plan: Teacher Attendance Excel Report

## Overview

This implementation plan converts the existing PDF-based attendance report system to generate Excel files with detailed lecture-by-lecture attendance data. The Excel format displays individual lecture dates as columns with P/A status for each student, providing enhanced data analysis capabilities.

## Tasks

- [x] 1. Set up Excel generation infrastructure
  - Add excel package dependency to pubspec.yaml (^4.0.6)
  - Add open_file package for file opening capabilities
  - Verify path_provider is available for file storage
  - _Requirements: 1.3, 7.1, 7.2_

- [x] 2. Create LectureSession model
  - [x] 2.1 Implement LectureSession data class
    - Create lib/Teacher/Attendance/models/lecture_session.dart
    - Define properties: date, timeSlotId, timeSlotName, studentStatuses map
    - Implement factory constructor fromFirestore for creating from session documents
    - Add date parsing helper for YYYY-MM-DD format
    - _Requirements: 4.3, 4.4_

  - [ ]\* 2.2 Write unit tests for LectureSession model
    - Test fromFirestore factory with valid session data
    - Test date parsing with various date formats
    - Test edge cases (missing fields, invalid dates)
    - _Requirements: 4.3, 4.4_

- [x] 3. Create ExcelReportGenerator service
  - [x] 3.1 Create service class structure
    - Create lib/Teacher/Attendance/services/excel_report_generator.dart
    - Define generateExcelReport method signature with all required parameters
    - Add private helper method stubs for workbook creation, metadata, headers, data population
    - _Requirements: 1.1, 1.4_

  - [x] 3.2 Implement Excel workbook creation
    - Implement \_createWorkbook method to initialize Excel object
    - Create default sheet named "Attendance Report"
    - _Requirements: 1.1, 1.2_

  - [x] 3.3 Implement metadata row generation
    - Implement \_addMetadataRows to add course name, semester, date range, time slots
    - Apply bold formatting to metadata cells
    - Position metadata rows at top of sheet (rows 0-3)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [ ]\* 3.4 Write property test for metadata completeness
    - **Property 13: Metadata Completeness**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
    - Verify all metadata fields present in generated Excel files
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 4. Implement column header generation
  - [x] 4.1 Implement \_addColumnHeaders method
    - Add "student_id" as first column header
    - Add lecture date columns in chronological order
    - Add "attendance_percentage" as last column header
    - Format date headers using readable format (YYYY-MM-DD or MMM DD, YYYY)
    - Apply bold formatting to header row
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 4.2 Handle empty lecture dates scenario
    - When no lectures in date range, create only student_id and attendance_percentage columns
    - _Requirements: 2.6_

  - [ ]\* 4.3 Write property test for column structure
    - **Property 2: Column Structure Completeness**
    - **Validates: Requirements 2.1, 2.3, 2.4**
    - Verify column order and completeness across random inputs
    - _Requirements: 2.1, 2.3, 2.4_

  - [ ]\* 4.4 Write property test for lecture date correspondence
    - **Property 3: Lecture Date Column Correspondence**
    - **Validates: Requirements 2.2, 4.3**
    - Verify number of date columns equals unique lecture dates
    - _Requirements: 2.2, 4.3_

- [x] 5. Checkpoint - Verify Excel structure generation
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement student data population
  - [x] 6.1 Implement \_populateStudentRows method
    - Create one row per student with student ID in first column
    - Populate P/A status for each lecture date column
    - Calculate and populate attendance percentage in last column
    - Format percentage as number with two decimals followed by "%"
    - Center-align P/A status cells
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [ ]\* 6.2 Write property test for attendance status mapping
    - **Property 6: Attendance Status Mapping**
    - **Validates: Requirements 3.2, 3.3, 4.4**
    - Verify P/A values correctly map to student presence/absence
    - _Requirements: 3.2, 3.3, 4.4_

  - [ ]\* 6.3 Write property test for percentage calculation accuracy
    - **Property 9: Percentage Calculation Accuracy**
    - **Validates: Requirements 4.5, 8.4**
    - Verify percentage = (present / total) × 100 with 2 decimal precision
    - _Requirements: 4.5, 8.4_

  - [ ]\* 6.4 Write unit tests for edge cases
    - Test student with 100% attendance
    - Test student with 0% attendance
    - Test student with no attendance records
    - Test percentage rounding edge cases
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 7. Implement Excel formatting
  - [x] 7.1 Implement \_applyFormatting method
    - Apply borders to all data cells
    - Auto-size columns to fit content
    - Freeze header row for scrolling
    - Ensure bold formatting on headers and metadata
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [ ]\* 7.2 Write unit tests for formatting
    - Verify bold formatting applied to headers
    - Verify borders applied to data cells
    - Verify center alignment on P/A cells
    - _Requirements: 9.1, 9.2, 9.3, 9.6_

- [x] 8. Implement file storage and naming
  - [x] 8.1 Implement \_saveExcelFile method
    - Generate unique filename with course name and timestamp
    - Use .xlsx extension
    - Save to user-accessible directory using path_provider
    - Return file path on success
    - _Requirements: 1.2, 7.3, 7.4, 7.5_

  - [ ]\* 8.2 Write property test for file generation
    - **Property 1: Excel File Generation with Correct Extension**
    - **Validates: Requirements 1.1, 1.2, 1.4**
    - Verify file exists and has .xlsx extension
    - _Requirements: 1.1, 1.2, 1.4_

  - [ ]\* 8.3 Write property test for filename uniqueness
    - **Property 19: Filename Uniqueness**
    - **Validates: Requirements 7.4**
    - Verify files generated at different times have different names
    - _Requirements: 7.4_

- [-] 9. Implement data retrieval for Excel format
  - [x] 9.1 Add \_fetchLectureSessions method to AttendanceReportScreen
    - Query Firestore sessions collection with date range filter
    - Apply time slot filter if selected
    - Extract individual lecture dates and student statuses
    - Create LectureSession objects for each session
    - Handle legacy data inclusion when legacy time slot selected
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.6_

  - [ ]\* 9.2 Write property test for date range filtering
    - **Property 10: Date Range Filtering**
    - **Validates: Requirements 4.1, 8.2**
    - Verify all lecture dates within specified range
    - _Requirements: 4.1, 8.2_

  - [ ]\* 9.3 Write property test for time slot filtering
    - **Property 11: Time Slot Filtering**
    - **Validates: Requirements 4.2, 8.3**
    - Verify only selected time slots included
    - _Requirements: 4.2, 8.3_

  - [ ]\* 9.4 Write unit tests for legacy data handling
    - Test legacy data inclusion when legacy time slot selected
    - Test legacy data exclusion when legacy time slot not selected
    - Test mixed legacy and session-based data
    - _Requirements: 4.6_

- [x] 10. Checkpoint - Verify data retrieval and transformation
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Integrate ExcelReportGenerator into AttendanceReportScreen
  - [ ] 11.1 Modify \_generateReport method
    - Replace PDF generation logic with Excel generation
    - Call \_fetchLectureSessions to get lecture session data
    - Call ExcelReportGenerator.generateExcelReport with all parameters
    - Handle returned file path
    - _Requirements: 1.1, 8.1_

  - [ ] 11.2 Update UI button text
    - Change button text from "Generate Report" to "Generate Excel Report"
    - _Requirements: 6.1_

  - [x] 11.3 Implement loading state
    - Display loading indicator during Excel generation
    - Disable button while generating
    - _Requirements: 6.2_

  - [ ]\* 11.4 Write integration tests for report generation flow
    - Test complete flow from button click to file generation
    - Test UI state transitions (idle → loading → success)
    - Test with various filter combinations
    - _Requirements: 1.1, 6.1, 6.2, 6.3_

- [x] 12. Implement file opening and sharing
  - [x] 12.1 Add \_showFileOptions method
    - Create dialog with "Open" and "Share" buttons
    - Implement open functionality using open_file package
    - Implement share functionality using share_plus package (add dependency if needed)
    - _Requirements: 1.5, 7.1, 7.2_

  - [x] 12.2 Display success message with file options
    - Show success SnackBar after generation
    - Call \_showFileOptions to present open/share dialog
    - _Requirements: 6.3, 7.1, 7.2_

  - [ ]\* 12.3 Write unit tests for file options dialog
    - Test dialog displays correctly
    - Test open button triggers file opening
    - Test share button triggers file sharing
    - _Requirements: 7.1, 7.2_

- [x] 13. Implement error handling
  - [x] 13.1 Create ExcelReportException class
    - Define exception with message, ErrorType enum, and originalError
    - Define ErrorType enum: database, validation, fileGeneration, storage, fileAccess, unknown
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 13.2 Add error handling to ExcelReportGenerator
    - Wrap data retrieval in try-catch for FirebaseException
    - Wrap Excel generation in try-catch for library errors
    - Wrap file storage in try-catch for FileSystemException
    - Add input validation for date ranges
    - Log all errors with context
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 13.3 Add error handling to AttendanceReportScreen
    - Catch ExcelReportException in \_generateReport
    - Display user-friendly error messages based on ErrorType
    - Handle empty data scenario with specific message
    - _Requirements: 6.4, 10.1, 10.2, 10.3, 10.4_

  - [ ]\* 13.4 Write unit tests for error scenarios
    - Test database connection failure
    - Test invalid date range (start after end)
    - Test empty result set
    - Test file storage failure
    - Test file opening failure
    - Verify appropriate error messages displayed
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [x] 14. Verify data consistency with PDF system
  - [x]\* 14.1 Write property test for student set consistency
    - **Property 22: Student Set Consistency**
    - **Validates: Requirements 8.5**
    - Verify same students in Excel as would be in PDF with identical filters
    - _Requirements: 8.5_

  - [x]\* 14.2 Write integration tests comparing Excel and PDF data
    - Generate both Excel and PDF reports with same filters
    - Compare student lists
    - Compare attendance percentages
    - Verify data consistency
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 15. Final checkpoint and cleanup
  - [x] 15.1 Remove unused PDF generation code
    - Remove \_generatePdfReport method from AttendanceReportScreen
    - Remove pdf and printing package imports if no longer used elsewhere
    - Clean up any PDF-specific helper methods
    - _Requirements: 1.1_

  - [x] 15.2 Final integration testing
    - Test complete flow with real Firestore data
    - Test with various date ranges and time slot combinations
    - Test file opening on device
    - Test file sharing functionality
    - Verify all error scenarios handled gracefully
    - _Requirements: 1.1, 1.5, 6.3, 6.4, 7.1, 7.2_

  - [x] 15.3 Ensure all tests pass
    - Run all unit tests
    - Run all property tests (minimum 100 iterations each)
    - Run all integration tests
    - Verify minimum 80% code coverage
    - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests must run minimum 100 iterations
- Property tests must include feature and property number in comments
- Checkpoints ensure incremental validation
- The implementation reuses existing data retrieval logic from AttendanceService
- Excel format provides enhanced data analysis capabilities over PDF
- Backward compatibility with legacy attendance data is maintained
