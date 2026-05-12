/// Exception thrown during Excel report generation
class ExcelReportException implements Exception {
  final String message;
  final ErrorType type;
  final dynamic originalError;

  ExcelReportException(
    this.message, {
    required this.type,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Types of errors that can occur during Excel report generation
enum ErrorType {
  /// Database query or connection failure
  database,

  /// Input validation failure (e.g., invalid date range)
  validation,

  /// Excel file creation or formatting failure
  fileGeneration,

  /// File system storage failure
  storage,

  /// File opening or sharing failure
  fileAccess,

  /// Unknown or unexpected error
  unknown,
}
