import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/time_slot.dart';
import '../services/attendance_service.dart';
import '../Teacheraddattemdance.dart';

/// Screen for selecting the time slot for attendance marking
/// Allows teachers to choose a specific time slot for the selected date
class TimeSlotSelectionScreen extends StatefulWidget {
  final String semester;
  final String courseName;
  final String teacherId;
  final String teacherName;
  final DateTime selectedDate;

  const TimeSlotSelectionScreen({
    super.key,
    required this.semester,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.selectedDate,
  });

  @override
  State<TimeSlotSelectionScreen> createState() =>
      _TimeSlotSelectionScreenState();
}

class _TimeSlotSelectionScreenState extends State<TimeSlotSelectionScreen> {
  List<TimeSlot> availableTimeSlots = [];
  TimeSlot? selectedTimeSlot;
  bool isLoading = true;
  bool hasExistingRecords = false;
  DateTime? existingRecordDate;
  AttendanceService? _attendanceService;

  AttendanceService get attendanceService {
    _attendanceService ??= AttendanceService();
    return _attendanceService!;
  }

  @override
  void initState() {
    super.initState();
    _loadTimeSlots();
  }

  /// Load available time slots from Firestore or use defaults
  /// Includes error handling with retry mechanism
  Future<void> _loadTimeSlots() async {
    setState(() {
      isLoading = true;
    });

    try {
      final timeSlots = await attendanceService.getTimeSlots(
        widget.semester,
        widget.courseName,
      );

      if (mounted) {
        setState(() {
          availableTimeSlots = timeSlots;
          isLoading = false;
        });
      }
    } catch (e) {
      // Log error for debugging
      debugPrint('Error loading time slots: $e');
      
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        // Show error message with retry option
        _showConnectionErrorDialog();
      }
    }
  }

  /// Show connection error dialog with retry mechanism
  void _showConnectionErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Connection Error'),
            ],
          ),
          content: const Text(
            'Unable to load time slots. Please check your internet connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to date selection
              },
              child: const Text('Go Back'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _loadTimeSlots(); // Retry loading
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

  /// Check if attendance already exists for the selected date and time slot
  /// Includes error handling to not block user if check fails
  Future<void> _checkExistingAttendance() async {
    if (selectedTimeSlot == null) return;

    try {
      final sessionData = await attendanceService.getExistingSession(
        widget.semester,
        widget.courseName,
        widget.selectedDate,
        selectedTimeSlot!.id,
      );

      if (sessionData != null && mounted) {
        setState(() {
          hasExistingRecords = true;
          // Extract the created_at timestamp if available
          if (sessionData['created_at'] != null) {
            existingRecordDate = sessionData['created_at'].toDate();
          }
        });
      } else if (mounted) {
        setState(() {
          hasExistingRecords = false;
          existingRecordDate = null;
        });
      }
    } catch (e) {
      // Log error for debugging
      debugPrint('Error checking existing attendance: $e');
      
      // Don't block the user if check fails - just log and continue
      if (mounted) {
        setState(() {
          hasExistingRecords = false;
          existingRecordDate = null;
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

  /// Handle time slot selection
  void _onTimeSlotSelected(TimeSlot timeSlot) {
    setState(() {
      selectedTimeSlot = timeSlot;
    });
    // Check for existing attendance when a time slot is selected
    _checkExistingAttendance();
  }

  /// Proceed to attendance marking screen
  void _proceedToAttendanceMarking() {
    if (selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot to continue.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to AttendancePage with selected date and time slot
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendancePage(
          semester: widget.semester,
          courseName: widget.courseName,
          id: widget.teacherId,
          name: widget.teacherName,
          selectedDate: widget.selectedDate,
          selectedTimeSlot: selectedTimeSlot!,
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
          'Select Time Slot',
          style: TextStyle(fontFamily: 'Nexa', color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : availableTimeSlots.isEmpty
              ? _buildEmptyState()
              : _buildTimeSlotList(),
    );
  }

  /// Build empty state when no time slots are available
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.schedule_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Time Slots Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'NexaBold',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No time slots are configured for this course. Please contact your administrator to set up time slots.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadTimeSlots,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the main time slot selection list
  Widget _buildTimeSlotList() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Course and date information header
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
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        attendanceService.formatDateDisplay(widget.selectedDate),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Warning banner if existing records found
          if (hasExistingRecords) _buildWarningBanner(),

          // Time slot selection section
          const Text(
            'Select Time Slot',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'NexaBold',
            ),
          ),
          const SizedBox(height: 10),

          // Time slot list
          Expanded(
            child: ListView.builder(
              itemCount: availableTimeSlots.length,
              itemBuilder: (context, index) {
                final timeSlot = availableTimeSlots[index];
                final isSelected = selectedTimeSlot?.id == timeSlot.id;

                return Card(
                  elevation: isSelected ? 4 : 1,
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _onTimeSlotSelected(timeSlot),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Radio button indicator
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : Colors.grey,
                                width: 2,
                              ),
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),

                          // Time slot information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timeSlot.displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'NexaBold',
                                    color: isSelected
                                        ? Colors.blueAccent
                                        : Colors.black,
                                  ),
                                ),
                                if (timeSlot.startTime.isNotEmpty &&
                                    timeSlot.endTime.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${timeSlot.startTime} - ${timeSlot.endTime}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Arrow indicator for selected item
                          if (isSelected)
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Continue button
          ElevatedButton(
            onPressed: selectedTimeSlot != null
                ? _proceedToAttendanceMarking
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              disabledBackgroundColor: Colors.grey.shade300,
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
    );
  }

  /// Build warning banner for existing attendance records
  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Already Exists',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NexaBold',
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  existingRecordDate != null
                      ? 'Attendance for this date and time slot was already marked on ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(existingRecordDate!)}. Continuing will overwrite the existing records.'
                      : 'Attendance for this date and time slot has already been marked. Continuing will overwrite the existing records.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
