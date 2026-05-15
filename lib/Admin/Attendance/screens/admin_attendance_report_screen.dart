import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student_attendance_summary.dart';
import '../services/admin_attendance_service.dart';

class AdminAttendanceReportScreen extends StatefulWidget {
  final String semester;
  final String branch;
  // Optional service injection for testing
  final AdminAttendanceService? service;

  const AdminAttendanceReportScreen({
    super.key,
    required this.semester,
    required this.branch,
    this.service,
  });

  @override
  State<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

class _AdminAttendanceReportScreenState
    extends State<AdminAttendanceReportScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<StudentAttendanceSummary> _reportData = [];

  late final AdminAttendanceService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AdminAttendanceService();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _reportData = [];
    });

    try {
      // Fetch courses first so we can distinguish "no courses" from "no students"
      List<String> courseNames;
      try {
        courseNames = await _service.fetchCourseNames(
          widget.semester,
          widget.branch,
        );
      } on FirebaseException {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load course data. Please retry.';
        });
        return;
      }

      if (courseNames.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No courses found for the selected semester and branch.';
        });
        return;
      }

      // Fetch students
      List<String> studentIds;
      try {
        studentIds = await _service.fetchStudentIds(
          widget.semester,
          widget.branch,
        );
      } on Exception {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load student data. Please retry.';
        });
        return;
      }

      if (studentIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No students enrolled for the selected semester and branch.';
        });
        return;
      }

      // Aggregate attendance for each student across all courses
      List<StudentAttendanceSummary> summaries;
      try {
        summaries = await Future.wait(
          studentIds.map(
            (id) => _service.computeStudentSummary(
              id,
              widget.semester,
              courseNames,
            ),
          ),
        );
      } on FirebaseException {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load attendance data. Please retry.';
        });
        return;
      }

      summaries.sort((a, b) => a.studentId.compareTo(b.studentId));

      setState(() {
        _isLoading = false;
        _reportData = summaries;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load attendance data. Please retry.';
      });
    }
  }

  Future<void> _exportToExcel() async {
    if (_reportData.isEmpty) return;

    final excel = Excel.createExcel();
    final sheet = excel['Attendance Report'];

    // Header row
    sheet.appendRow([
      TextCellValue('Student ID'),
      TextCellValue('Present'),
      TextCellValue('Total'),
      TextCellValue('Attendance %'),
    ]);

    for (final s in _reportData) {
      sheet.appendRow([
        TextCellValue(s.studentId),
        IntCellValue(s.totalPresent),
        IntCellValue(s.totalClasses),
        DoubleCellValue(double.parse(s.attendancePercentage.toStringAsFixed(2))),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'attendance_sem${widget.semester}_${widget.branch.replaceAll(' ', '_')}.xlsx';
    final file = File('${dir.path}/$fileName');
    final bytes = excel.encode();
    if (bytes == null) return;
    await file.writeAsBytes(bytes);

    await OpenFile.open(file.path);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to ${file.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
        actions: [
          if (_reportData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export to Excel',
              onPressed: _exportToExcel,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: semester and branch
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semester: ${widget.semester}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Branch: ${widget.branch}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReport,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reportData.isEmpty) {
      return const Center(
        child: Text('No data available.'),
      );
    }

    return ListView.builder(
      itemCount: _reportData.length,
      itemBuilder: (context, index) {
        final summary = _reportData[index];
        final bool isLowAttendance = summary.attendancePercentage < 75.0;
        final Color percentageColor =
            isLowAttendance ? Colors.red : Colors.green;
        final String formattedPercentage =
            '${summary.attendancePercentage.toStringAsFixed(2)}%';

        return ListTile(
          title: Text(summary.studentId),
          trailing: Text(
            formattedPercentage,
            style: TextStyle(
              color: percentageColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
