import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import 'time_slot_selection_screen.dart';

/// Screen for selecting the date for attendance marking
/// Allows teachers to select a date within the past 90 days up to current date
class DateSelectionScreen extends StatefulWidget {
  final String semester;
  final String courseName;
  final String teacherId;
  final String teacherName;

  const DateSelectionScreen({
    super.key,
    required this.semester,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<DateSelectionScreen> createState() => _DateSelectionScreenState();
}

class _DateSelectionScreenState extends State<DateSelectionScreen> {
  late DateTime selectedDate;
  late DateTime earliestDate;
  late DateTime latestDate;
  AttendanceService? _attendanceService;
  bool _datePickerFailed = false;
  final TextEditingController _manualDateController = TextEditingController();
  
  AttendanceService get attendanceService {
    _attendanceService ??= AttendanceService();
    return _attendanceService!;
  }

  @override
  void dispose() {
    _manualDateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Initialize selectedDate to current date
    selectedDate = DateTime.now();
    // Set earliestDate to 90 days ago
    earliestDate = DateTime.now().subtract(const Duration(days: 90));
    // Set latestDate to current date
    latestDate = DateTime.now();
  }

  /// Validate that the selected date is within the allowed range
  bool _validateDate(DateTime date) {
    // Normalize dates to compare only date parts (ignore time)
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedEarliest = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);
    final normalizedLatest = DateTime(latestDate.year, latestDate.month, latestDate.day);

    // Check if date is within range
    if (normalizedDate.isBefore(normalizedEarliest)) {
      return false;
    }
    if (normalizedDate.isAfter(normalizedLatest)) {
      return false;
    }
    return true;
  }

  /// Show error dialog for invalid date selection
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invalid Date'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show date picker and update selected date
  /// Includes error handling with fallback to manual text input
  Future<void> _selectDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: earliestDate,
        lastDate: latestDate,
        helpText: 'Select Attendance Date',
        cancelText: 'Cancel',
        confirmText: 'Select',
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              primaryColor: Colors.blueAccent,
              colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
              buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
            ),
            child: child!,
          );
        },
      );

      if (picked != null && picked != selectedDate) {
        setState(() {
          selectedDate = picked;
          _datePickerFailed = false; // Reset failure flag on success
        });
      }
    } catch (e) {
      // Log the error for debugging
      debugPrint('Date picker failed: $e');
      
      // Show error message and enable fallback text input
      setState(() {
        _datePickerFailed = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Date picker failed to load. Please use manual date entry below.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Parse and validate manually entered date
  void _parseManualDate(String input) {
    try {
      // Try multiple date formats
      DateTime? parsedDate;
      
      // Format: yyyy-MM-dd
      try {
        parsedDate = DateFormat('yyyy-MM-dd').parseStrict(input);
      } catch (_) {
        // Format: MM/dd/yyyy
        try {
          parsedDate = DateFormat('MM/dd/yyyy').parseStrict(input);
        } catch (_) {
          // Format: dd-MM-yyyy
          try {
            parsedDate = DateFormat('dd-MM-yyyy').parseStrict(input);
          } catch (_) {
            throw FormatException('Invalid date format');
          }
        }
      }
      
      if (parsedDate != null) {
        if (_validateDate(parsedDate)) {
          setState(() {
            selectedDate = parsedDate!;
            _manualDateController.clear();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Date updated successfully!'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showErrorDialog('Please enter a date within the last 90 days.');
        }
      }
    } catch (e) {
      debugPrint('Manual date parsing error: $e');
      _showErrorDialog(
        'Invalid date format. Please use one of these formats:\n'
        '• yyyy-MM-dd (e.g., 2024-01-15)\n'
        '• MM/dd/yyyy (e.g., 01/15/2024)\n'
        '• dd-MM-yyyy (e.g., 15-01-2024)'
      );
    }
  }

  /// Proceed to time slot selection screen
  void _proceedToTimeSlotSelection() {
    // Validate date before proceeding
    if (!_validateDate(selectedDate)) {
      String errorMessage;
      final normalizedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final normalizedEarliest = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);
      final normalizedLatest = DateTime(latestDate.year, latestDate.month, latestDate.day);

      if (normalizedDate.isBefore(normalizedEarliest)) {
        errorMessage = 'Please select a date within the last 90 days.';
      } else if (normalizedDate.isAfter(normalizedLatest)) {
        errorMessage = 'Please select a date that is not in the future.';
      } else {
        errorMessage = 'Please select a valid date.';
      }

      // Log error for debugging
      debugPrint('Date validation failed: $errorMessage (Selected: $selectedDate)');
      _showErrorDialog(errorMessage);
      return;
    }

    // Navigate to TimeSlotSelectionScreen
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
        title: const Text(
          'Select Date',
          style: TextStyle(fontFamily: 'Nexa', color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Course information header
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.courseName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'NexaBold',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Semester: ${widget.semester}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Teacher: ${widget.teacherName}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Date selection section
            const Text(
              'Select Attendance Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'NexaBold',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You can select a date from the past 90 days up to today.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),

            // Selected date display card
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              child: InkWell(
                onTap: _selectDate,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 40,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Date',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attendanceService.formatDateDisplay(selectedDate),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'NexaBold',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Date range information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Valid range: ${DateFormat('MMM d, yyyy').format(earliestDate)} to ${DateFormat('MMM d, yyyy').format(latestDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Manual date entry fallback (shown if date picker fails)
            if (_datePickerFailed) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_calendar, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Manual Date Entry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NexaBold',
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _manualDateController,
                      decoration: InputDecoration(
                        hintText: 'Enter date (yyyy-MM-dd)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            if (_manualDateController.text.isNotEmpty) {
                              _parseManualDate(_manualDateController.text);
                            }
                          },
                        ),
                      ),
                      onSubmitted: _parseManualDate,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accepted formats: yyyy-MM-dd, MM/dd/yyyy, dd-MM-yyyy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Continue button
            ElevatedButton(
              onPressed: _proceedToTimeSlotSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'NexaBold',
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Back button
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.blueAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'NexaBold',
                  fontWeight: FontWeight.w900,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
