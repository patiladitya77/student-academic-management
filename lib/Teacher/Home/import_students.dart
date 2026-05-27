import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class TeacherImportStudentsScreen extends StatefulWidget {
  final String teacherBranch;

  const TeacherImportStudentsScreen({
    super.key,
    required this.teacherBranch,
  });

  @override
  State<TeacherImportStudentsScreen> createState() =>
      _TeacherImportStudentsScreenState();
}

class _TeacherImportStudentsScreenState
    extends State<TeacherImportStudentsScreen> {
  final CollectionReference _studentsFirestore =
      FirebaseFirestore.instance.collection('Admin_Students_List');

  bool _isUploading = false;
  String _statusMessage = '';
  int _uploadedCount = 0;
  int _skippedCount = 0;

  final List<String> _semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];
  String _selectedSemester = '1';
  late String _selectedBranch;

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.teacherBranch;
  }

  Future<void> _importStudents() async {
    setState(() {
      _isUploading = true;
      _statusMessage = '';
      _uploadedCount = 0;
      _skippedCount = 0;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() {
          _statusMessage = 'No file selected.';
          _isUploading = false;
        });
        return;
      }

      final bytes = result.files.single.bytes!;
      final workbook = Excel.decodeBytes(bytes);

      if (workbook.tables.isEmpty) {
        setState(() {
          _statusMessage = 'No sheets found in the Excel file.';
          _isUploading = false;
        });
        return;
      }

      for (final sheetName in workbook.tables.keys) {
        final sheet = workbook.tables[sheetName];
        if (sheet == null || sheet.rows.isEmpty) {
          continue;
        }

        final headerRow = sheet.rows.first;
        final headerIndex = _buildHeaderIndex(headerRow);

        if (!headerIndex.containsKey('role_no')) {
          setState(() {
            _statusMessage =
                'Missing required column. Ensure the sheet has a roll_no (or usn/id) column.';
          });
          break;
        }

        // Collect all valid rows first
        final List<Map<String, dynamic>> toWrite = [];

        for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
          final row = sheet.rows[rowIndex];
          final roleNo = _cellValue(row, headerIndex['role_no']);
          final email = _cellValue(row, headerIndex['email']);
          final name = _cellValue(row, headerIndex['name']);
          final phoneNo = _cellValue(row, headerIndex['phone_no']);
          final semester = _cellValue(row, headerIndex['semester']);
          final branch = _cellValue(row, headerIndex['branch']);

          if (roleNo == null || roleNo.isEmpty) {
            _skippedCount++;
            continue;
          }

          final normalizedId = roleNo.toUpperCase();
          final payload = <String, dynamic>{
            'role': 'student',
            'id': normalizedId,
            // Use Excel value if present, otherwise fall back to selected dropdown
            'semester': (semester != null && semester.isNotEmpty) ? semester : _selectedSemester,
            'branch': (branch != null && branch.isNotEmpty) ? branch : _selectedBranch,
          };

          if (email != null && email.isNotEmpty) payload['email'] = email;
          if (name != null && name.isNotEmpty) payload['name'] = name;
          if (phoneNo != null && phoneNo.isNotEmpty) payload['phone_no'] = phoneNo;

          toWrite.add(payload);
        }

        // Write in batches of 500 (Firestore limit)
        const batchSize = 500;
        for (var i = 0; i < toWrite.length; i += batchSize) {
          final chunk = toWrite.sublist(i, i + batchSize > toWrite.length ? toWrite.length : i + batchSize);
          final batch = FirebaseFirestore.instance.batch();
          for (final payload in chunk) {
            final docRef = _studentsFirestore.doc(payload['id'] as String);
            batch.set(docRef, payload);
          }
          await batch.commit().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Upload timed out. Check your internet connection.'),
          );
          _uploadedCount += chunk.length;
        }
      }

      setState(() {
        _statusMessage =
            'Imported $_uploadedCount students. Skipped $_skippedCount rows.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to import students: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Map<String, int> _buildHeaderIndex(List<Data?> row) {
    const aliases = {
      'role_no': 'role_no',
      'roll_no': 'role_no',
      'role': 'role_no',
      'usn': 'role_no',
      'id': 'role_no',
      'name': 'name',
      'student_name': 'name',
      'email': 'email',
      'phone_no': 'phone_no',
      'phone': 'phone_no',
      'mobile': 'phone_no',
      'semester': 'semester',
      'sem': 'semester',
      'branch': 'branch',
      'department': 'branch',
    };

    final index = <String, int>{};
    for (var i = 0; i < row.length; i++) {
      final raw = _stringCell(row[i]);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      final normalized = _normalizeHeader(raw);
      final mapped = aliases[normalized];
      if (mapped != null && !index.containsKey(mapped)) {
        index[mapped] = i;
      }
    }

    return index;
  }

  String? _cellValue(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) {
      return null;
    }
    return _stringCell(row[index]);
  }

  String? _stringCell(Data? cell) {
    final value = cell?.value;
    if (value == null) {
      return null;
    }
    return value.toString().trim();
  }

  String _normalizeHeader(String header) {
    return header
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        title: const Text(
          'Import Students',
          style: TextStyle(fontFamily: 'Nexa', color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSemester,
              decoration: const InputDecoration(
                labelText: 'Semester',
                border: OutlineInputBorder(),
              ),
              items: _semesters
                  .map((s) => DropdownMenuItem(value: s, child: Text('Semester $s')))
                  .toList(),
              onChanged: _isUploading ? null : (v) => setState(() => _selectedSemester = v!),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Branch',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _selectedBranch,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _importStudents,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Excel File'),
            ),
            const SizedBox(height: 16),
            if (_isUploading)
              const Center(child: CircularProgressIndicator())
            else if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: const TextStyle(fontFamily: 'NexaBold'),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Required column: roll_no (or usn / id).\n'
                  'Optional columns: name, email, phone_no.\n'
                  'Semester and branch will use the dropdowns above unless your Excel includes those columns.',
                  style: TextStyle(fontFamily: 'Nexa'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
