import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/lecture_session.dart';
import '../exceptions/excel_report_exception.dart';

/// Service class responsible for generating Excel attendance reports
class ExcelReportGenerator {
  /// Generate Excel report from attendance data
  /// 
  /// Returns the file path of the generated Excel file
  /// 
  /// Throws [ExcelReportException] if generation fails
  /// 
  /// Parameters:
  /// - [studentAttendance]: Map of student IDs to their attendance data
  /// - [lectureSessions]: List of individual lecture sessions with attendance
  /// - [courseName]: Name of the course
  /// - [semester]: Semester information
  /// - [startDate]: Start date of the report range
  /// - [endDate]: End date of the report range
  /// - [selectedTimeSlotNames]: List of selected time slot names for filtering
  Future<String> generateExcelReport({
    required Map<String, Map<String, dynamic>> studentAttendance,
    required List<LectureSession> lectureSessions,
    required String courseName,
    required String semester,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> selectedTimeSlotNames,
  }) async {
    try {
      // Validate inputs
      _validateInputs(startDate, endDate, courseName);

      // Create Excel workbook
      final excel = _createWorkbook();
      final sheet = excel.sheets[excel.getDefaultSheet()]!;

      // Add metadata rows
      _addMetadataRows(
        sheet,
        excel,
        courseName,
        semester,
        startDate,
        endDate,
        selectedTimeSlotNames,
      );

      // Add column headers
      _addColumnHeaders(sheet, excel, lectureSessions);

      // Populate student data rows
      _populateStudentRows(
        sheet,
        excel,
        studentAttendance,
        lectureSessions,
      );

      // Apply formatting
      _applyFormatting(sheet, excel);

      // Save and return file path
      return await _saveExcelFile(excel, courseName);
    } on ExcelReportException {
      // Re-throw ExcelReportException as-is
      rethrow;
    } on FirebaseException catch (e) {
      _logError('Database error during report generation', e);
      throw ExcelReportException(
        'Failed to retrieve attendance data from database',
        type: ErrorType.database,
        originalError: e,
      );
    } on FileSystemException catch (e) {
      _logError('File system error during report generation', e);
      throw ExcelReportException(
        'Failed to save Excel file to storage',
        type: ErrorType.storage,
        originalError: e,
      );
    } catch (e) {
      _logError('Unexpected error during report generation', e);
      throw ExcelReportException(
        'Failed to create Excel file: ${e.toString()}',
        type: ErrorType.fileGeneration,
        originalError: e,
      );
    }
  }

  /// Validate input parameters
  /// 
  /// Throws [ExcelReportException] with type [ErrorType.validation] if validation fails
  void _validateInputs(DateTime startDate, DateTime endDate, String courseName) {
    if (startDate.isAfter(endDate)) {
      throw ExcelReportException(
        'Start date must be before or equal to end date',
        type: ErrorType.validation,
      );
    }

    if (courseName.trim().isEmpty) {
      throw ExcelReportException(
        'Course name cannot be empty',
        type: ErrorType.validation,
      );
    }
  }

  /// Log error with context for debugging
  void _logError(String context, dynamic error) {
    debugPrint('ExcelReportGenerator Error [$context]: $error');
    if (error is Error) {
      debugPrint('Stack trace: ${error.stackTrace}');
    }
  }

  /// Create Excel workbook with default sheet
  @visibleForTesting
  Excel _createWorkbook() {
    final excel = Excel.createExcel();
    
    // Rename default sheet to "Attendance Report"
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, 'Attendance Report');
    }
    
    return excel;
  }

  /// Add metadata rows to the sheet
  @visibleForTesting
  void _addMetadataRows(
    Sheet sheet,
    Excel excel,
    String courseName,
    String semester,
    DateTime startDate,
    DateTime endDate,
    List<String> selectedTimeSlotNames,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    // Row 0: Course name
    var cell = sheet.cell(CellIndex.indexByString('A1'));
    cell.value = TextCellValue('Course: $courseName');
    cell.cellStyle = CellStyle(bold: true);
    
    // Row 1: Semester
    cell = sheet.cell(CellIndex.indexByString('A2'));
    cell.value = TextCellValue('Semester: $semester');
    cell.cellStyle = CellStyle(bold: true);
    
    // Row 2: Date range
    cell = sheet.cell(CellIndex.indexByString('A3'));
    cell.value = TextCellValue(
      'Date Range: ${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}'
    );
    cell.cellStyle = CellStyle(bold: true);
    
    // Row 3: Time slots (if any selected)
    cell = sheet.cell(CellIndex.indexByString('A4'));
    if (selectedTimeSlotNames.isNotEmpty) {
      cell.value = TextCellValue('Time Slots: ${selectedTimeSlotNames.join(', ')}');
    } else {
      cell.value = TextCellValue('Time Slots: All');
    }
    cell.cellStyle = CellStyle(bold: true);
  }

  /// Add column headers to the sheet
  @visibleForTesting
  void _addColumnHeaders(
    Sheet sheet,
    Excel excel,
    List<LectureSession> lectureSessions,
  ) {
    // Header row is at row index 5 (after 4 metadata rows: 0-3)
    const int headerRowIndex = 4;
    int columnIndex = 0;
    
    // First column: student_id
    var cell = sheet.cell(CellIndex.indexByColumnRow(
      columnIndex: columnIndex,
      rowIndex: headerRowIndex,
    ));
    cell.value = TextCellValue('student_id');
    cell.cellStyle = CellStyle(bold: true);
    columnIndex++;
    
    // Middle columns: lecture dates in chronological order
    if (lectureSessions.isNotEmpty) {
      // Extract unique dates and sort chronologically
      final uniqueDates = <DateTime>{};
      for (final session in lectureSessions) {
        uniqueDates.add(session.date);
      }
      final sortedDates = uniqueDates.toList()..sort();
      
      // Format dates as column headers
      final dateFormat = DateFormat('yyyy-MM-dd');
      for (final date in sortedDates) {
        cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: headerRowIndex,
        ));
        cell.value = TextCellValue(dateFormat.format(date));
        cell.cellStyle = CellStyle(bold: true);
        columnIndex++;
      }
    }
    
    // Last column: attendance_percentage
    cell = sheet.cell(CellIndex.indexByColumnRow(
      columnIndex: columnIndex,
      rowIndex: headerRowIndex,
    ));
    cell.value = TextCellValue('attendance_percentage');
    cell.cellStyle = CellStyle(bold: true);
  }

  /// Populate student attendance data rows
  @visibleForTesting
  void _populateStudentRows(
    Sheet sheet,
    Excel excel,
    Map<String, Map<String, dynamic>> studentAttendance,
    List<LectureSession> lectureSessions,
  ) {
    // Data rows start at row index 5 (after 4 metadata rows and 1 header row)
    const int firstDataRowIndex = 5;
    int rowIndex = firstDataRowIndex;
    
    // Extract unique dates and sort chronologically
    final uniqueDates = <DateTime>{};
    for (final session in lectureSessions) {
      uniqueDates.add(session.date);
    }
    final sortedDates = uniqueDates.toList()..sort();
    
    // Create a map of date -> list of sessions for that date
    final dateToSessions = <DateTime, List<LectureSession>>{};
    for (final session in lectureSessions) {
      dateToSessions.putIfAbsent(session.date, () => []).add(session);
    }
    
    // Iterate through each student
    for (final entry in studentAttendance.entries) {
      final studentId = entry.key;
      final attendanceData = entry.value;
      int columnIndex = 0;
      
      // Column 0: student_id
      var cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: columnIndex,
        rowIndex: rowIndex,
      ));
      cell.value = TextCellValue(studentId);
      columnIndex++;
      
      // Middle columns: P/A status for each lecture date
      for (final date in sortedDates) {
        cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ));
        
        // Determine P/A status for this student on this date
        String status = 'A'; // Default to absent
        final sessionsOnDate = dateToSessions[date] ?? [];
        
        // Check if student was present in any session on this date
        for (final session in sessionsOnDate) {
          if (session.studentStatuses.containsKey(studentId)) {
            final studentStatus = session.studentStatuses[studentId];
            if (studentStatus == 'P') {
              status = 'P';
              break; // If present in any session, mark as present
            }
          }
        }
        
        cell.value = TextCellValue(status);
        
        // Center-align P/A status cells
        cell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
        );
        
        columnIndex++;
      }
      
      // Last column: attendance_percentage
      cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: columnIndex,
        rowIndex: rowIndex,
      ));
      
      // Calculate attendance percentage
      final present = attendanceData['present'] as int? ?? 0;
      final total = attendanceData['total'] as int? ?? 0;
      final percentage = total > 0 ? (present * 100.0 / total) : 0.0;
      
      // Format percentage as number with two decimals followed by "%"
      final formattedPercentage = '${percentage.toStringAsFixed(2)}%';
      cell.value = TextCellValue(formattedPercentage);
      
      rowIndex++;
    }
  }

  /// Apply formatting to the sheet
  @visibleForTesting
  void _applyFormatting(Sheet sheet, Excel excel) {
    if (sheet.rows.isEmpty) return;
    
    // Determine the dimensions of the data
    final maxRows = sheet.maxRows;
    final maxCols = sheet.maxColumns;
    
    // Header row is at index 4, data starts at index 5
    const int headerRowIndex = 4;
    
    // Apply bold formatting to headers (row 4)
    for (int colIndex = 0; colIndex < maxCols; colIndex++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: colIndex,
        rowIndex: headerRowIndex,
      ));
      
      cell.cellStyle = CellStyle(bold: true);
    }
    
    // Apply bold formatting to metadata rows (rows 0-3)
    for (int rowIndex = 0; rowIndex < headerRowIndex; rowIndex++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: rowIndex,
      ));
      
      cell.cellStyle = CellStyle(bold: true);
    }
    
    // Auto-size columns to fit content
    // Note: The excel package doesn't have built-in auto-size functionality,
    // so we'll set reasonable default widths based on content type
    for (int colIndex = 0; colIndex < maxCols; colIndex++) {
      double maxWidth = 10.0; // Minimum width
      
      // Sample cells in this column to determine appropriate width
      for (int rowIndex = 0; rowIndex < maxRows && rowIndex < 20; rowIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: colIndex,
          rowIndex: rowIndex,
        ));
        
        final cellValue = cell.value?.toString() ?? '';
        final estimatedWidth = cellValue.length * 1.2;
        if (estimatedWidth > maxWidth) {
          maxWidth = estimatedWidth;
        }
      }
      
      // Cap maximum width at 50 characters
      maxWidth = maxWidth.clamp(10.0, 50.0);
      
      // Set column width
      sheet.setColumnWidth(colIndex, maxWidth);
    }
    
    // Note: Row freezing and cell borders are not supported in excel package 4.0.6
    // These features would require a different Excel library or manual implementation
  }

  /// Save Excel file to device storage
  /// 
  /// Generates a unique filename with course name and timestamp,
  /// saves to user-accessible directory, and returns the file path.
  /// 
  /// Throws [ExcelReportException] with type [ErrorType.storage] if save fails
  /// 
  /// Requirements: 1.2, 7.3, 7.4, 7.5
  Future<String> _saveExcelFile(Excel excel, String courseName) async {
    try {
      // Generate unique filename with course name and timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      // Sanitize course name for filename (remove special characters)
      final sanitizedCourseName = courseName
          .trim() // Trim first to remove leading/trailing spaces
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim(); // Trim again in case there were only spaces
      
      // Create filename with .xlsx extension
      final filename = '${sanitizedCourseName}_attendance_$timestamp.xlsx';
      
      // Get user-accessible directory
      Directory directory;
      if (Platform.isAndroid) {
        // For Android, use external storage directory (Downloads or Documents)
        directory = (await getExternalStorageDirectory())!;
        
        // Navigate to a more accessible location
        // Try to use Downloads folder if available
        final downloadsPath = directory.path.replaceAll('Android/data/com.example.app/files', 'Download');
        final downloadsDir = Directory(downloadsPath);
        
        if (await downloadsDir.exists()) {
          directory = downloadsDir;
        }
      } else if (Platform.isIOS) {
        // For iOS, use application documents directory
        directory = await getApplicationDocumentsDirectory();
      } else {
        // For other platforms, use application documents directory
        directory = await getApplicationDocumentsDirectory();
      }
      
      // Create full file path
      final filePath = '${directory.path}/$filename';
      
      // Encode Excel to bytes
      final excelBytes = excel.encode();
      
      if (excelBytes == null) {
        throw ExcelReportException(
          'Failed to encode Excel file',
          type: ErrorType.fileGeneration,
        );
      }
      
      // Write file to storage
      final file = File(filePath);
      await file.writeAsBytes(excelBytes);
      
      debugPrint('Excel file saved successfully: $filePath');
      
      return filePath;
    } on ExcelReportException {
      // Re-throw ExcelReportException as-is
      rethrow;
    } on FileSystemException catch (e) {
      _logError('File system error while saving Excel file', e);
      throw ExcelReportException(
        'Failed to save Excel file to storage: ${e.message}',
        type: ErrorType.storage,
        originalError: e,
      );
    } catch (e) {
      _logError('Unexpected error while saving Excel file', e);
      throw ExcelReportException(
        'Failed to save Excel file: ${e.toString()}',
        type: ErrorType.storage,
        originalError: e,
      );
    }
  }
}
