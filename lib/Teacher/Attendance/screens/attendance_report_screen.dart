import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/time_slot.dart';
import '../models/lecture_session.dart';
import '../services/attendance_service.dart';
import '../services/excel_report_generator.dart';
import '../exceptions/excel_report_exception.dart';

class AttendanceReportScreen extends StatefulWidget {
  final String semester;
  final String courseName;
  final String teacherId;
  final String teacherName;

  const AttendanceReportScreen({
    super.key,
    required this.semester,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  
  DateTime? _startDate;
  DateTime? _endDate;
  List<TimeSlot> _availableTimeSlots = [];
  List<String> _selectedTimeSlotIds = [];
  bool _isLoadingTimeSlots = true;
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _loadTimeSlots();
  }

  Future<void> _loadTimeSlots() async {
    try {
      final timeSlots = await _attendanceService.getTimeSlots(
        widget.semester,
        widget.courseName,
      );
      
      // Add legacy time slot option for filtering legacy records
      final legacyTimeSlot = _attendanceService.getLegacyTimeSlot();
      
      setState(() {
        _availableTimeSlots = [...timeSlots, legacyTimeSlot];
        _isLoadingTimeSlots = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTimeSlots = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load time slots: $e')),
        );
      }
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Select Start Date',
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Ensure end date is not before start date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Select End Date',
    );
    
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _toggleTimeSlotSelection(String timeSlotId) {
    setState(() {
      if (_selectedTimeSlotIds.contains(timeSlotId)) {
        _selectedTimeSlotIds.remove(timeSlotId);
      } else {
        _selectedTimeSlotIds.add(timeSlotId);
      }
    });
  }

  String _formatDateDisplay(DateTime? date) {
    if (date == null) return 'Not selected';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  List<String> _getSelectedTimeSlotNames() {
    if (_selectedTimeSlotIds.isEmpty) {
      return [];
    }
    return _availableTimeSlots
        .where((slot) => _selectedTimeSlotIds.contains(slot.id))
        .map((slot) => slot.displayName)
        .toList();
  }

  Future<void> _generateReport() async {
    // Validation
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Start date must be before or equal to end date')),
      );
      return;
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      // Fetch filtered attendance data
      final attendanceData = await _fetchFilteredAttendanceData();

      // Handle empty data scenario with specific message
      if (attendanceData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No attendance records found for the selected criteria'),
              action: SnackBarAction(
                label: 'Adjust Filters',
                onPressed: () {
                  // User can adjust filters and try again
                },
              ),
            ),
          );
        }
        return;
      }

      // Fetch lecture sessions for Excel generation
      final lectureSessions = await _fetchLectureSessions();

      // Generate Excel report
      final excelGenerator = ExcelReportGenerator();
      final filePath = await excelGenerator.generateExcelReport(
        studentAttendance: attendanceData,
        lectureSessions: lectureSessions,
        courseName: widget.courseName,
        semester: widget.semester,
        startDate: _startDate!,
        endDate: _endDate!,
        selectedTimeSlotNames: _getSelectedTimeSlotNames(),
      );

      if (mounted) {
        // Show success message with file options
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Show file options dialog
        await _showFileOptions(filePath);
      }
    } on ExcelReportException catch (e) {
      // Handle ExcelReportException with user-friendly messages
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseException catch (e) {
      // Handle Firebase-specific errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to retrieve attendance data. Please check your connection and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      debugPrint('Firebase error in _generateReport: $e');
    } on FileSystemException catch (e) {
      // Handle file system errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save file. Please check available storage space.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      debugPrint('File system error in _generateReport: $e');
    } catch (e) {
      // Handle any other unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      debugPrint('Unexpected error in _generateReport: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReport = false;
        });
      }
    }
  }

  /// Get user-friendly error message based on ErrorType
  /// Provides clear, actionable error messages for different failure scenarios
  String _getErrorMessage(ExcelReportException error) {
    switch (error.type) {
      case ErrorType.database:
        return 'Unable to retrieve attendance data. Please check your connection and try again.';
      case ErrorType.validation:
        return error.message; // Use specific validation message
      case ErrorType.fileGeneration:
        return 'Failed to create Excel file. Please try again.';
      case ErrorType.storage:
        return 'Unable to save file. Please check available storage space.';
      case ErrorType.fileAccess:
        return 'Unable to open or share the file. Please check app permissions.';
      case ErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchFilteredAttendanceData() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    
    // Query sessions collection
    final sessionsQuery = firestore
        .collection('Attendance')
        .doc(widget.semester)
        .collection(widget.courseName)
        .doc('sessions')
        .collection('records');

    final sessionsSnapshot = await sessionsQuery.get();

    // Apply date range and time slot filters in memory
    final startDateStr = _attendanceService.formatDate(_startDate!);
    final endDateStr = _attendanceService.formatDate(_endDate!);
    
    final filteredSessions = sessionsSnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final sessionDate = data['date'] as String?;
      
      // Apply date range filter
      if (sessionDate == null) return false;
      if (sessionDate.compareTo(startDateStr) < 0) return false;
      if (sessionDate.compareTo(endDateStr) > 0) return false;
      
      // Apply time slot filter if selected
      if (_selectedTimeSlotIds.isNotEmpty) {
        final timeSlotId = data['time_slot_id'] as String?;
        if (timeSlotId == null || !_selectedTimeSlotIds.contains(timeSlotId)) {
          return false;
        }
      }
      
      return true;
    }).toList();

    // Aggregate student attendance data
    Map<String, Map<String, dynamic>> studentAttendance = {};

    for (var sessionDoc in filteredSessions) {
      final studentsSnapshot = await sessionDoc.reference
          .collection('students')
          .get();

      for (var studentDoc in studentsSnapshot.docs) {
        final studentId = studentDoc.id;
        final data = studentDoc.data();
        final status = data['status'] as String;

        if (!studentAttendance.containsKey(studentId)) {
          studentAttendance[studentId] = {
            'present': 0,
            'total': 0,
          };
        }

        studentAttendance[studentId]!['total'] += 1;
        if (status == 'P') {
          studentAttendance[studentId]!['present'] += 1;
        }
      }
    }

    // Handle legacy data: Read cumulative counters for students without session records
    // Legacy records are stored directly at Attendance/{semester}/{courseName}/{studentId}
    await _includeLegacyData(firestore, studentAttendance);

    return studentAttendance;
  }

  /// Include legacy attendance data in the report
  /// Legacy records don't have session-level tracking, only cumulative counters
  Future<void> _includeLegacyData(
    FirebaseFirestore firestore,
    Map<String, Map<String, dynamic>> studentAttendance,
  ) async {
    try {
      // Query student-level cumulative records
      final studentRecordsSnapshot = await firestore
          .collection('Attendance')
          .doc(widget.semester)
          .collection(widget.courseName)
          .get();

      for (var studentDoc in studentRecordsSnapshot.docs) {
        // Skip the 'sessions' document
        if (studentDoc.id == 'sessions') continue;

        final studentId = studentDoc.id;
        final data = studentDoc.data();

        // Check if this is a legacy record (has cumulative counters but no session structure)
        if (_attendanceService.isLegacyRecord(data)) {
          // Extract legacy session date from timestamp
          final legacyDate = _attendanceService.getLegacySessionDate(data);
          
          if (legacyDate != null) {
            // Check if legacy date falls within filter range
            final legacyDateStr = _attendanceService.formatDate(legacyDate);
            final startDateStr = _attendanceService.formatDate(_startDate!);
            final endDateStr = _attendanceService.formatDate(_endDate!);

            if (legacyDateStr.compareTo(startDateStr) >= 0 &&
                legacyDateStr.compareTo(endDateStr) <= 0) {
              // Check time slot filter - legacy records match "legacy" time slot
              if (_selectedTimeSlotIds.isEmpty ||
                  _selectedTimeSlotIds.contains('legacy')) {
                // Include legacy data in report
                // Note: We use cumulative counters as-is since we can't break them down by session
                if (!studentAttendance.containsKey(studentId)) {
                  studentAttendance[studentId] = {
                    'present': data['present'] ?? 0,
                    'total': data['total'] ?? 0,
                    'is_legacy': true,
                  };
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error including legacy data: $e');
      // Don't fail the entire report if legacy data can't be read
    }
  }

  /// Fetch individual lecture sessions for Excel report generation
  /// Returns a list of LectureSession objects with date, time slot, and student statuses
  /// Applies date range and time slot filters
  /// Includes legacy data when legacy time slot is selected
  Future<List<LectureSession>> _fetchLectureSessions() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final List<LectureSession> lectureSessions = [];

    try {
      // Query sessions collection
      final sessionsQuery = firestore
          .collection('Attendance')
          .doc(widget.semester)
          .collection(widget.courseName)
          .doc('sessions')
          .collection('records');

      final sessionsSnapshot = await sessionsQuery.get();

      // Apply date range and time slot filters
      final startDateStr = _attendanceService.formatDate(_startDate!);
      final endDateStr = _attendanceService.formatDate(_endDate!);

      for (var sessionDoc in sessionsSnapshot.docs) {
        final data = sessionDoc.data();
        final sessionDate = data['date'] as String?;
        final timeSlotId = data['time_slot_id'] as String?;

        // Apply date range filter
        if (sessionDate == null) continue;
        if (sessionDate.compareTo(startDateStr) < 0) continue;
        if (sessionDate.compareTo(endDateStr) > 0) continue;

        // Apply time slot filter if selected
        if (_selectedTimeSlotIds.isNotEmpty) {
          if (timeSlotId == null || !_selectedTimeSlotIds.contains(timeSlotId)) {
            continue;
          }
        }

        // Fetch student statuses for this session
        final studentsSnapshot = await sessionDoc.reference
            .collection('students')
            .get();

        final Map<String, String> studentStatuses = {};
        for (var studentDoc in studentsSnapshot.docs) {
          final studentId = studentDoc.id;
          final studentData = studentDoc.data();
          final status = studentData['status'] as String? ?? 'A';
          studentStatuses[studentId] = status;
        }

        // Create LectureSession object
        final lectureSession = LectureSession.fromFirestore(
          sessionDoc,
          studentStatuses,
        );
        lectureSessions.add(lectureSession);
      }

      // Handle legacy data inclusion when legacy time slot is selected
      if (_selectedTimeSlotIds.isEmpty || _selectedTimeSlotIds.contains('legacy')) {
        await _includeLegacyLectureSessions(firestore, lectureSessions);
      }

      // Sort sessions by date
      lectureSessions.sort((a, b) => a.date.compareTo(b.date));

      return lectureSessions;
    } catch (e) {
      debugPrint('Error fetching lecture sessions: $e');
      rethrow;
    }
  }

  /// Include legacy attendance data as lecture sessions
  /// Legacy records are converted to pseudo-sessions for Excel report compatibility
  Future<void> _includeLegacyLectureSessions(
    FirebaseFirestore firestore,
    List<LectureSession> lectureSessions,
  ) async {
    try {
      // Query student-level cumulative records
      final studentRecordsSnapshot = await firestore
          .collection('Attendance')
          .doc(widget.semester)
          .collection(widget.courseName)
          .get();

      // Track legacy students and their data
      Map<String, Map<String, dynamic>> legacyStudents = {};

      for (var studentDoc in studentRecordsSnapshot.docs) {
        // Skip the 'sessions' document
        if (studentDoc.id == 'sessions') continue;

        final studentId = studentDoc.id;
        final data = studentDoc.data();

        // Check if this is a legacy record
        if (_attendanceService.isLegacyRecord(data)) {
          // Extract legacy session date from timestamp
          final legacyDate = _attendanceService.getLegacySessionDate(data);

          if (legacyDate != null) {
            // Check if legacy date falls within filter range
            final legacyDateStr = _attendanceService.formatDate(legacyDate);
            final startDateStr = _attendanceService.formatDate(_startDate!);
            final endDateStr = _attendanceService.formatDate(_endDate!);

            if (legacyDateStr.compareTo(startDateStr) >= 0 &&
                legacyDateStr.compareTo(endDateStr) <= 0) {
              // Store legacy student data
              legacyStudents[studentId] = {
                'date': legacyDate,
                'present': data['present'] ?? 0,
                'total': data['total'] ?? 0,
              };
            }
          }
        }
      }

      // Create pseudo-sessions for legacy data
      // Since legacy data doesn't have individual session records, we create
      // synthetic sessions based on the cumulative counters
      if (legacyStudents.isNotEmpty) {
        // Group legacy students by date
        Map<DateTime, Map<String, String>> legacySessionsByDate = {};

        for (var entry in legacyStudents.entries) {
          final studentId = entry.key;
          final data = entry.value;
          final date = data['date'] as DateTime;
          final present = data['present'] as int;
          final total = data['total'] as int;

          // Create a normalized date (midnight)
          final normalizedDate = DateTime(date.year, date.month, date.day);

          if (!legacySessionsByDate.containsKey(normalizedDate)) {
            legacySessionsByDate[normalizedDate] = {};
          }

          // For legacy data, we can't determine exact P/A for each session
          // We'll mark as 'P' if present count > 0, otherwise 'A'
          // This is a limitation of legacy data format
          legacySessionsByDate[normalizedDate]![studentId] = present > 0 ? 'P' : 'A';
        }

        // Create LectureSession objects for legacy data
        for (var entry in legacySessionsByDate.entries) {
          final date = entry.key;
          final studentStatuses = entry.value;

          final legacySession = LectureSession(
            date: date,
            timeSlotId: 'legacy',
            timeSlotName: 'Legacy',
            studentStatuses: studentStatuses,
          );

          lectureSessions.add(legacySession);
        }
      }
    } catch (e) {
      debugPrint('Error including legacy lecture sessions: $e');
      // Don't fail the entire report if legacy data can't be read
    }
  }

  /// Show dialog with options to open or share the generated file
  /// Provides user-friendly access to the generated Excel report
  Future<void> _showFileOptions(String filePath) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Report Generated'),
          content: Text('Your report has been generated successfully. What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _shareFile(filePath);
              },
              child: Text('Share'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openFile(filePath);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: Text(
                'Open',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Open the generated file using the default application
  /// Throws ExcelReportException with type fileAccess if opening fails
  Future<void> _openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      
      if (result.type != ResultType.done) {
        throw ExcelReportException(
          'Unable to open file: ${result.message}',
          type: ErrorType.fileAccess,
        );
      }
    } on ExcelReportException {
      rethrow;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error opening file: $e');
    }
  }

  /// Share the generated file using the system share dialog
  /// Throws ExcelReportException with type fileAccess if sharing fails
  Future<void> _shareFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw ExcelReportException(
          'File not found',
          type: ErrorType.fileAccess,
        );
      }

      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        subject: 'Attendance Report - ${widget.courseName}',
        text: 'Attendance report for ${widget.courseName} (${widget.semester})',
      );
    } on ExcelReportException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(
              ExcelReportException('File not found', type: ErrorType.fileAccess)
            )),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error sharing file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Report'),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoadingTimeSlots
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course info
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.courseName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Semester: ${widget.semester}',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Date range filter
                  Text(
                    'Date Range',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: InkWell(
                            onTap: _selectStartDate,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatDateDisplay(_startDate),
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: InkWell(
                            onTap: _selectEndDate,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatDateDisplay(_endDate),
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Time slot filter
                  Text(
                    'Time Slots (Optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select specific time slots or leave empty for all',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  if (_availableTimeSlots.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No time slots available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: _availableTimeSlots.map((timeSlot) {
                          final isSelected = _selectedTimeSlotIds.contains(timeSlot.id);
                          return CheckboxListTile(
                            title: Text(timeSlot.displayName),
                            subtitle: timeSlot.startTime.isNotEmpty && timeSlot.endTime.isNotEmpty
                                ? Text('${timeSlot.startTime} - ${timeSlot.endTime}')
                                : null,
                            value: isSelected,
                            onChanged: (bool? value) {
                              _toggleTimeSlotSelection(timeSlot.id);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  
                  SizedBox(height: 32),
                  
                  // Generate full report button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingReport ? null : _generateReport,
                      icon: Icon(Icons.table_chart, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      label: _isGeneratingReport
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Generate Excel Report',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Defaulter list button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingReport ? null : _generateDefaulterList,
                      icon: Icon(Icons.warning_amber_rounded, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      label: Text(
                        'Get Defaulter List (< 75%)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Generate defaulter list Excel — students with attendance < 75%
  Future<void> _generateDefaulterList() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }

    setState(() => _isGeneratingReport = true);

    try {
      final attendanceData = await _fetchFilteredAttendanceData();

      // Filter defaulters: attendance percentage < 75%
      final defaulters = attendanceData.entries.where((entry) {
        final present = entry.value['present'] as int? ?? 0;
        final total = entry.value['total'] as int? ?? 0;
        if (total == 0) return true; // 0 attendance = defaulter
        return (present * 100.0 / total) < 75.0;
      }).toList();

      if (defaulters.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No defaulters found — all students have ≥ 75% attendance'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Build Excel
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != 'Defaulter List') {
        excel.rename(defaultSheet, 'Defaulter List');
      }
      final sheet = excel.sheets['Defaulter List'] ?? excel.sheets[excel.getDefaultSheet()!]!;

      // Metadata
      var cell = sheet.cell(CellIndex.indexByString('A1'));
      cell.value = TextCellValue('Course: ${widget.courseName}');
      cell.cellStyle = CellStyle(bold: true);

      cell = sheet.cell(CellIndex.indexByString('A2'));
      cell.value = TextCellValue('Semester: ${widget.semester}');
      cell.cellStyle = CellStyle(bold: true);

      cell = sheet.cell(CellIndex.indexByString('A3'));
      cell.value = TextCellValue(
        'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
      );
      cell.cellStyle = CellStyle(bold: true);

      cell = sheet.cell(CellIndex.indexByString('A4'));
      cell.value = TextCellValue('Threshold: < 75% attendance');
      cell.cellStyle = CellStyle(bold: true);

      // Header row
      const headerRow = 5;
      final headers = ['S.No', 'Student ID', 'Present', 'Total', 'Attendance %'];
      for (int i = 0; i < headers.length; i++) {
        cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true);
      }

      // Sort defaulters by attendance % ascending
      defaulters.sort((a, b) {
        final aTotal = a.value['total'] as int? ?? 0;
        final aPresent = a.value['present'] as int? ?? 0;
        final bTotal = b.value['total'] as int? ?? 0;
        final bPresent = b.value['present'] as int? ?? 0;
        final aPct = aTotal > 0 ? aPresent * 100.0 / aTotal : 0.0;
        final bPct = bTotal > 0 ? bPresent * 100.0 / bTotal : 0.0;
        return aPct.compareTo(bPct);
      });

      // Data rows
      for (int i = 0; i < defaulters.length; i++) {
        final studentId = defaulters[i].key;
        final data = defaulters[i].value;
        final present = data['present'] as int? ?? 0;
        final total = data['total'] as int? ?? 0;
        final pct = total > 0 ? (present * 100.0 / total).toStringAsFixed(2) : '0.00';
        final rowIndex = headerRow + 1 + i;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
            TextCellValue('${i + 1}');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
            TextCellValue(studentId);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
            TextCellValue('$present');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
            TextCellValue('$total');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
            TextCellValue('$pct%');
      }

      // Auto-size columns
      for (int col = 0; col < headers.length; col++) {
        sheet.setColumnWidth(col, col == 1 ? 20.0 : 14.0);
      }

      // Save file
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final sanitized = widget.courseName
          .trim()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      final filename = '${sanitized}_defaulters_$timestamp.xlsx';

      Directory directory;
      if (Platform.isAndroid) {
        directory = (await getExternalStorageDirectory())!;
        final downloadsPath = directory.path.replaceAll(
            'Android/data/com.example.app/files', 'Download');
        final downloadsDir = Directory(downloadsPath);
        if (await downloadsDir.exists()) directory = downloadsDir;
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final filePath = '${directory.path}/$filename';
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');
      await File(filePath).writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Defaulter list generated — ${defaulters.length} student(s)'),
            backgroundColor: Colors.orange.shade700,
            duration: Duration(seconds: 2),
          ),
        );
        await _showFileOptions(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate defaulter list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Defaulter list error: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }
}
