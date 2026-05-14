class StudentAttendanceSummary {
  final String studentId;
  final int totalPresent;
  final int totalClasses;
  final double attendancePercentage; // rounded to 2 decimal places

  const StudentAttendanceSummary({
    required this.studentId,
    required this.totalPresent,
    required this.totalClasses,
    required this.attendancePercentage,
  });

  /// Factory constructor that computes [attendancePercentage] automatically.
  ///
  /// - When [totalClasses] > 0: percentage = (totalPresent / totalClasses) * 100
  /// - When [totalClasses] == 0: percentage = 0.0
  /// - Result is rounded to 2 decimal places.
  factory StudentAttendanceSummary.compute({
    required String studentId,
    required int totalPresent,
    required int totalClasses,
  }) {
    final double percentage = totalClasses > 0
        ? double.parse((totalPresent / totalClasses * 100).toStringAsFixed(2))
        : 0.0;

    return StudentAttendanceSummary(
      studentId: studentId,
      totalPresent: totalPresent,
      totalClasses: totalClasses,
      attendancePercentage: percentage,
    );
  }
}
