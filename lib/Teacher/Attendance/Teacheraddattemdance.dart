import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'models/time_slot.dart';
import 'screens/attendance_report_screen.dart';

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

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _studentsRef =
  FirebaseFirestore.instance.collection('Admin_Students_List');
  final CollectionReference _attendanceRef =
  FirebaseFirestore.instance.collection('Attendance');

  bool _loading = false;
  bool _checkingExisting = true;
  bool _hasExistingRecords = false;
  DateTime? _existingRecordDate;
  bool _userConfirmedOverwrite = false;
  Map<String, String> attendance = {}; // Stores attendance for each student
  Map<String, String> _savedAttendanceBackup = {}; // Backup for retry on failure
  List<String> _failedStudentIds = []; // Track failed student records

  @override
  void initState() {
    super.initState();
    _checkForExistingAttendance();
  }

  // Check if attendance already exists for this date and time slot
  // Includes error handling to not block the user
  Future<void> _checkForExistingAttendance() async {
    try {
      final sessionId = _generateSessionId();
      final sessionDoc = await _attendanceRef
          .doc(widget.semester)
          .collection(widget.courseName)
          .doc('sessions')
          .collection('records')
          .doc(sessionId)
          .get();

      if (mounted) {
        if (sessionDoc.exists) {
          final data = sessionDoc.data() as Map<String, dynamic>;
          setState(() {
            _hasExistingRecords = true;
            _existingRecordDate = (data['created_at'] as Timestamp?)?.toDate();
            _checkingExisting = false;
          });
        } else {
          setState(() {
            _checkingExisting = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking existing attendance: $e');
      
      // Don't block the user - just log and continue
      if (mounted) {
        setState(() {
          _checkingExisting = false;
        });
        
        // Show a non-blocking warning
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to check for existing records. You may proceed, but be aware that records might already exist.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Generate unique session ID
  String _generateSessionId() {
    final dateStr = DateFormat('yyyyMMdd').format(widget.selectedDate);
    return '${dateStr}_${widget.selectedTimeSlot.id}';
  }

  // Format date for storage
  String _formatDate() {
    return DateFormat('yyyy-MM-dd').format(widget.selectedDate);
  }

  // Format date for display
  String _formatDateDisplay() {
    return DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate);
  }

  // Format time slot for display
  String _formatTimeSlotDisplay() {
    if (widget.selectedTimeSlot.startTime.isNotEmpty && 
        widget.selectedTimeSlot.endTime.isNotEmpty) {
      return '${widget.selectedTimeSlot.displayName}: ${widget.selectedTimeSlot.startTime} - ${widget.selectedTimeSlot.endTime}';
    }
    return widget.selectedTimeSlot.displayName;
  }

  // Show confirmation dialog for overwriting existing records
  // Handles duplicate session conflicts with clear options
  Future<void> _showOverwriteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Confirm Overwrite'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance records already exist for this session.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_existingRecordDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Existing Record Details:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(_existingRecordDate!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Overwriting will replace the existing records with your current selections. This action cannot be undone.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to continue?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(false);
                _viewExistingRecords();
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Existing'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.edit),
              label: const Text('Overwrite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _userConfirmedOverwrite = true;
      });
      await saveAttendance();
    }
  }

  // View existing attendance records
  Future<void> _viewExistingRecords() async {
    try {
      final sessionId = _generateSessionId();
      final studentsSnapshot = await _attendanceRef
          .doc(widget.semester)
          .collection(widget.courseName)
          .doc('sessions')
          .collection('records')
          .doc(sessionId)
          .collection('students')
          .get();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Existing Attendance Records'),
            content: Container(
              width: double.maxFinite,
              child: studentsSnapshot.docs.isEmpty
                  ? Text('No student records found.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: studentsSnapshot.docs.length,
                      itemBuilder: (context, index) {
                        final doc = studentsSnapshot.docs[index];
                        final data = doc.data();
                        return ListTile(
                          title: Text(doc.id),
                          trailing: Text(
                            data['status'] ?? 'N/A',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: data['status'] == 'P'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load existing records: $e')),
      );
    }
  }

  // Save attendance data to Firestore
  // Includes comprehensive error handling for network failures, partial batch failures, and duplicate conflicts
  Future<void> saveAttendance() async {
    // Check if overwrite confirmation is needed
    if (_hasExistingRecords && !_userConfirmedOverwrite) {
      await _showOverwriteConfirmation();
      return;
    }

    setState(() {
      _loading = true;
    });

    // Backup attendance data for retry on failure
    _savedAttendanceBackup = Map.from(attendance);

    try {
      debugPrint("Starting attendance submission...");
      
      // Generate unique session ID
      final sessionId = _generateSessionId();
      final formattedDate = _formatDate();
      
      // Check if session already exists (for idempotence)
      final sessionRef = _attendanceRef
          .doc(widget.semester)
          .collection(widget.courseName)
          .doc('sessions')
          .collection('records')
          .doc(sessionId);
      
      final sessionSnapshot = await sessionRef.get();
      final isOverwriting = sessionSnapshot.exists;
      
      // Use batch writes for atomic operations
      final batch = _firestore.batch();
      
      // Create/update session-level document with metadata
      batch.set(sessionRef, {
        'date': formattedDate,
        'time_slot_id': widget.selectedTimeSlot.id,
        'time_slot_name': widget.selectedTimeSlot.displayName,
        'created_at': FieldValue.serverTimestamp(),
        'teacher_id': widget.id,
        'teacher_name': widget.name,
      });
      
      debugPrint("Session metadata prepared for $sessionId");
      
      // Process each student's attendance
      DocumentReference semesterDoc = _attendanceRef.doc(widget.semester);
      CollectionReference courseCollection = semesterDoc.collection(widget.courseName);
      
      for (var studentId in attendance.keys) {
        String status = attendance[studentId] ?? 'A';
        
        // Get existing cumulative counters
        DocumentReference studentDoc = courseCollection.doc(studentId);
        DocumentSnapshot studentSnapshot = await studentDoc.get();
        int present = 0;
        int total = 0;
        bool wasLegacyRecord = false;
        
        if (studentSnapshot.exists) {
          Map<String, dynamic> studentData = studentSnapshot.data() as Map<String, dynamic>;
          present = studentData['present'] ?? 0;
          total = studentData['total'] ?? 0;
          
          // Check if this is a legacy record being migrated
          // Legacy records don't have 'migrated' field and lack session structure
          wasLegacyRecord = !studentData.containsKey('migrated') && 
                           !studentData.containsKey('time_slot_id');
        }
        
        // If overwriting, check the old status to adjust counters correctly
        if (isOverwriting) {
          final oldStudentSessionDoc = await sessionRef
              .collection('students')
              .doc(studentId)
              .get();
          
          if (oldStudentSessionDoc.exists) {
            final oldStatus = oldStudentSessionDoc.data()?['status'] ?? 'A';
            
            // Reverse the old status effect
            if (oldStatus == 'P') {
              present--;
            }
            total--;
          }
        }
        
        // Apply new status
        if (status == 'P') {
          present++;
        }
        total++;
        
        // Update cumulative counters with migration marker if this was a legacy record
        Map<String, dynamic> updateData = {
          'present': present,
          'total': total,
          'last_status': status,
          'date': FieldValue.serverTimestamp(),
        };
        
        // Mark as migrated if this was a legacy record
        if (wasLegacyRecord) {
          updateData['migrated'] = true;
          updateData['migrated_at'] = FieldValue.serverTimestamp();
          updateData['time_slot_id'] = widget.selectedTimeSlot.id;
          updateData['time_slot_name'] = widget.selectedTimeSlot.displayName;
          debugPrint("Migrating legacy record for student $studentId");
        }
        
        batch.set(studentDoc, updateData, SetOptions(merge: true));
        
        // Store individual session record
        final studentSessionRef = sessionRef.collection('students').doc(studentId);
        batch.set(studentSessionRef, {
          'status': status,
          'marked_at': FieldValue.serverTimestamp(),
        });
        
        debugPrint("Attendance for student $studentId prepared.");
      }
      
      // Commit all changes atomically
      await batch.commit();
      debugPrint("Batch write completed successfully.");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reset confirmation flag and update state
      setState(() {
        _userConfirmedOverwrite = false;
        _hasExistingRecords = true; // Now records exist
        _failedStudentIds.clear(); // Clear any previous failures
      });
    } on FirebaseException catch (e) {
      debugPrint("Firebase error during attendance submission: ${e.code} - ${e.message}");
      
      if (mounted) {
        _handleFirebaseError(e);
      }
    } catch (e) {
      debugPrint("Error during attendance submission: $e");
      
      if (mounted) {
        _handleGeneralError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Handle Firebase-specific errors
  void _handleFirebaseError(FirebaseException e) {
    String errorMessage;
    bool canRetry = true;

    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        errorMessage = 'Network connection lost. Please check your internet connection and try again.';
        break;
      case 'permission-denied':
        errorMessage = 'You do not have permission to submit attendance. Please contact your administrator.';
        canRetry = false;
        break;
      case 'not-found':
        errorMessage = 'The attendance collection was not found. Please contact your administrator.';
        canRetry = false;
        break;
      case 'already-exists':
        errorMessage = 'Attendance records already exist for this session. Please refresh and try again.';
        _hasExistingRecords = true;
        break;
      default:
        errorMessage = 'Failed to submit attendance: ${e.message ?? 'Unknown error'}';
    }

    _showErrorDialog(
      'Submission Failed',
      errorMessage,
      canRetry: canRetry,
    );
  }

  /// Handle general errors
  void _handleGeneralError(dynamic e) {
    String errorMessage = 'An unexpected error occurred: ${e.toString()}';
    
    // Check if it's a network-related error
    if (e.toString().contains('SocketException') || 
        e.toString().contains('NetworkException') ||
        e.toString().contains('Failed host lookup')) {
      errorMessage = 'Network connection lost. Please check your internet connection and try again.';
    }

    _showErrorDialog(
      'Submission Failed',
      errorMessage,
      canRetry: true,
    );
  }

  /// Show error dialog with retry option
  void _showErrorDialog(String title, String message, {bool canRetry = true}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (canRetry) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Your attendance data has been preserved. You can retry submission.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            if (canRetry)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Restore attendance data from backup
                  setState(() {
                    attendance = Map.from(_savedAttendanceBackup);
                  });
                  // Retry submission
                  saveAttendance();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
          ],
        );
      },
    );
  }

  // Navigate to filtered report screen
  void _navigateToFilteredReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceReportScreen(
          semester: widget.semester,
          courseName: widget.courseName,
          teacherId: widget.id,
          teacherName: widget.name,
        ),
      ),
    );
  }

  // Generate an Excel report with attendance data
  Future<void> printAttendanceData() async {
    try {
      print("Generating attendance Excel report...");

      // Fetch attendance data from Firestore
      DocumentReference semesterDoc = _attendanceRef.doc(widget.semester);
      CollectionReference courseCollection =
      semesterDoc.collection(widget.courseName);

      QuerySnapshot studentsSnapshot = await courseCollection.get();

      if (studentsSnapshot.docs.isEmpty) {
        print("No attendance records found.");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No attendance records found.')));
        return;
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      
      // Rename default sheet
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.rename(defaultSheet, 'Attendance Report');
      }
      
      // Get the sheet reference after renaming
      final sheet = excel.sheets['Attendance Report']!;

      // Add metadata rows
      var cell = sheet.cell(CellIndex.indexByString('A1'));
      cell.value = TextCellValue('Course: ${widget.courseName}');
      cell.cellStyle = CellStyle(bold: true);
      
      cell = sheet.cell(CellIndex.indexByString('A2'));
      cell.value = TextCellValue('Semester: ${widget.semester}');
      cell.cellStyle = CellStyle(bold: true);
      
      cell = sheet.cell(CellIndex.indexByString('A3'));
      cell.value = TextCellValue('Generated: ${DateFormat('MMM dd, yyyy \'at\' h:mm a').format(DateTime.now())}');
      cell.cellStyle = CellStyle(bold: true);

      // Add column headers (row 4, index 3)
      const int headerRowIndex = 3;
      cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRowIndex));
      cell.value = TextCellValue('S.No');
      cell.cellStyle = CellStyle(bold: true);
      
      cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRowIndex));
      cell.value = TextCellValue('Student ID');
      cell.cellStyle = CellStyle(bold: true);
      
      cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: headerRowIndex));
      cell.value = TextCellValue('Present');
      cell.cellStyle = CellStyle(bold: true);
      
      cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: headerRowIndex));
      cell.value = TextCellValue('Total');
      cell.cellStyle = CellStyle(bold: true);
      
      cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: headerRowIndex));
      cell.value = TextCellValue('Attendance %');
      cell.cellStyle = CellStyle(bold: true);

      // Add student data rows (starting from row 5, index 4)
      int rowIndex = 4;
      int counter = 1;
      
      for (var doc in studentsSnapshot.docs) {
        // Skip the 'sessions' document
        if (doc.id == 'sessions') continue;
        
        Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
        int present = studentData['present'] ?? 0;
        int total = studentData['total'] ?? 0;
        String studentId = doc.id;
        String attendancePercentage =
            total > 0 ? (present * 100 / total).toStringAsFixed(2) : '0.00';

        // S.No
        cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
        cell.value = TextCellValue(counter.toString());
        
        // Student ID
        cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
        cell.value = TextCellValue(studentId);
        
        // Present
        cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
        cell.value = TextCellValue(present.toString());
        cell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
        
        // Total
        cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
        cell.value = TextCellValue(total.toString());
        cell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
        
        // Attendance %
        cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
        cell.value = TextCellValue('$attendancePercentage%');
        cell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

        counter++;
        rowIndex++;
      }

      // Auto-size columns
      for (int colIndex = 0; colIndex < 5; colIndex++) {
        double maxWidth = 10.0;
        
        for (int row = 0; row < rowIndex && row < 20; row++) {
          final cellValue = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: row,
          )).value?.toString() ?? '';
          
          final estimatedWidth = cellValue.length * 1.2;
          if (estimatedWidth > maxWidth) {
            maxWidth = estimatedWidth;
          }
        }
        
        maxWidth = maxWidth.clamp(10.0, 50.0);
        sheet.setColumnWidth(colIndex, maxWidth);
      }

      // Save Excel file
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final sanitizedCourseName = widget.courseName
          .trim()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      
      final filename = '${sanitizedCourseName}_quick_report_$timestamp.xlsx';
      
      Directory directory;
      if (Platform.isAndroid) {
        directory = (await getExternalStorageDirectory())!;
        final downloadsPath = directory.path.replaceAll('Android/data/com.example.app/files', 'Download');
        final downloadsDir = Directory(downloadsPath);
        
        if (await downloadsDir.exists()) {
          directory = downloadsDir;
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final filePath = '${directory.path}/$filename';
      final excelBytes = excel.encode();
      
      if (excelBytes == null) {
        throw Exception('Failed to encode Excel file');
      }
      
      final file = File(filePath);
      await file.writeAsBytes(excelBytes);
      
      print('Excel file saved successfully: $filePath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel report generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Show file options dialog
        await _showQuickReportFileOptions(filePath);
      }
    } catch (e) {
      print("Error during Excel generation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate Excel report: $e')),
        );
      }
    }
  }

  /// Show dialog with options to open or share the quick report file
  Future<void> _showQuickReportFileOptions(String filePath) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Report Generated'),
          content: Text('Your quick report has been generated successfully. What would you like to do?'),
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
                await _shareQuickReportFile(filePath);
              },
              child: Text('Share'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openQuickReportFile(filePath);
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

  /// Open the generated quick report file
  Future<void> _openQuickReportFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open file: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

  /// Share the generated quick report file
  Future<void> _shareQuickReportFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        subject: 'Quick Attendance Report - ${widget.courseName}',
        text: 'Quick attendance report for ${widget.courseName} (${widget.semester})',
      );
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
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        title: Text('${widget.courseName}',
            style: TextStyle(fontFamily: 'Nexa', color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Sticky header with date and time slot information
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(
                bottom: BorderSide(color: Colors.blueAccent, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.courseName}',
                        style: TextStyle(
                          fontFamily: 'NexaBold',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.class_, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Semester: ${widget.semester}',
                      style: TextStyle(
                        fontFamily: 'Nexa',
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatDateDisplay(),
                        style: TextStyle(
                          fontFamily: 'Nexa',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatTimeSlotDisplay(),
                        style: TextStyle(
                          fontFamily: 'Nexa',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Warning banner for existing records
          if (_hasExistingRecords)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                border: Border(
                  bottom: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[800], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Attendance Already Exists',
                          style: TextStyle(
                            fontFamily: 'NexaBold',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    _existingRecordDate != null
                        ? 'Records were created on ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(_existingRecordDate!)}'
                        : 'Records already exist for this session',
                    style: TextStyle(
                      fontFamily: 'Nexa',
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _viewExistingRecords,
                          icon: Icon(Icons.visibility, size: 16),
                          label: Text('View'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange[800],
                            side: BorderSide(color: Colors.orange),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showOverwriteConfirmation(),
                          icon: Icon(Icons.edit, size: 16),
                          label: Text('Overwrite'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.cancel, size: 16),
                          label: Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            side: BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _checkingExisting
                ? Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
              stream: _studentsRef
                  .where('semester', isEqualTo: widget.semester)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print("Error in student data stream: ${snapshot.error}");
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print("No students found.");
                  return Center(child: Text('No students found.'));
                }

                final studentDocs = snapshot.data!.docs;

                for (var student in studentDocs) {
                  final studentData = student.data() as Map<String, dynamic>;
                  final studentId =
                      studentData['id'] ?? 'Unknown ID'; // Provide fallback
                  attendance[studentId] ??= 'P'; // Set default to 'P'
                }

                return ListView.builder(
                  itemCount: studentDocs.length,
                  itemBuilder: (context, index) {
                    final student = studentDocs[index];
                    final studentData = student.data() as Map<String, dynamic>;
                    final studentId =
                        studentData['id'] ?? 'Unknown ID';
                    final studentEmail =
                        studentData['email'] ?? 'No Email';

                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            child: Icon(Icons.perm_identity),
                          ),
                          title: Text(studentId),
                          subtitle: Text(studentEmail),
                          trailing: StatefulBuilder(
                            builder: (context, setLocalState) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('P'),
                                      Radio<String>(
                                        value: 'P',
                                        groupValue: attendance[studentId],
                                        onChanged: (value) {
                                          setLocalState(() {
                                            attendance[studentId] = value!;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('A'),
                                      Radio<String>(
                                        value: 'A',
                                        groupValue: attendance[studentId],
                                        onChanged: (value) {
                                          setLocalState(() {
                                            attendance[studentId] = value!;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Divider(
                          thickness: 2,
                          indent: 5,
                          endIndent: 5,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      side: BorderSide(color: Colors.blueAccent)),
                  onPressed: saveAttendance,
                  child: _loading
                      ? Container(
                      height: 30,
                      child: CircularProgressIndicator())
                      : Text('Submit Attendance',
                      style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'NexaBold',
                          fontWeight: FontWeight.w900)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      side: BorderSide(color: Colors.blueAccent)),
                  onPressed: printAttendanceData,
                  child: Text('Quick Report',
                      style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'NexaBold',
                          fontWeight: FontWeight.w900)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      side: BorderSide(color: Colors.blueAccent)),
                  onPressed: _navigateToFilteredReport,
                  child: Text('Filtered Report',
                      style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'NexaBold',
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
