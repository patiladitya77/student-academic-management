import 'package:flutter/material.dart';
import 'admin_attendance_report_screen.dart';
import '../services/admin_attendance_service.dart';

class AdminAttendanceSelectionScreen extends StatefulWidget {
  // Optional factory for injecting a custom service into the report screen
  // (used in tests to avoid Firebase initialization).
  final AdminAttendanceService? Function()? serviceFactory;

  const AdminAttendanceSelectionScreen({super.key, this.serviceFactory});

  @override
  State<AdminAttendanceSelectionScreen> createState() =>
      _AdminAttendanceSelectionScreenState();
}

class _AdminAttendanceSelectionScreenState
    extends State<AdminAttendanceSelectionScreen> {
  String? _selectedSemester;
  String? _selectedBranch;

  static const List<String> _semesters = [
    '1', '2', '3', '4', '5', '6', '7', '8',
  ];

  static const List<String> _branches = [
    'Computer Science & Engineering',
    'Information Science & Engineering',
    'Civil Engineering',
    'Mechanical Engineering',
    'Electrical Engineering',
    'Electronics & Communication Eng',
    'Biotechnology Engineering',
  ];

  bool get _canGenerate =>
      _selectedSemester != null && _selectedBranch != null;

  void _onGenerateReport() {
    if (!_canGenerate) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAttendanceReportScreen(
          semester: _selectedSemester!,
          branch: _selectedBranch!,
          service: widget.serviceFactory?.call(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSemester,
              decoration: const InputDecoration(
                labelText: 'Select Semester',
                border: OutlineInputBorder(),
              ),
              items: _semesters
                  .map((s) => DropdownMenuItem(value: s, child: Text('Semester $s')))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSemester = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBranch,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Branch',
                border: OutlineInputBorder(),
              ),
              items: _branches
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedBranch = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _canGenerate ? _onGenerateReport : null,
              child: const Text('Generate Report'),
            ),
          ],
        ),
      ),
    );
  }
}
