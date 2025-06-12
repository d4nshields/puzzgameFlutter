/// Interface for error reporting services
/// 
/// This abstraction allows us to swap error reporting implementations
/// while maintaining clean architecture principles.
abstract class ErrorReportingService {
  /// Initialize the error reporting service
  Future<void> initialize();
  
  /// Report an exception with optional context
  Future<void> reportException(
    dynamic exception, {
    dynamic stackTrace,
    String? context,
    Map<String, dynamic>? extra,
    String? userId,
    Map<String, String>? tags,
  });
  
  /// Report a custom message/event
  Future<void> reportMessage(
    String message, {
    String level = 'info',
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
  });
  
  /// Set user context for future reports
  Future<void> setUserContext({
    String? userId,
    String? email,
    Map<String, dynamic>? extra,
  });
  
  /// Add breadcrumb for debugging context
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    String level = 'info',
    Map<String, dynamic>? data,
  });
  
  /// Start a performance transaction
  Future<PerformanceTransaction?> startTransaction(
    String name,
    String operation,
  );
  
  /// Check if error reporting is enabled
  bool get isEnabled;
  
  /// Enable or disable error reporting
  Future<void> setEnabled(bool enabled);
}

/// Interface for performance transactions
abstract class PerformanceTransaction {
  /// Set data on the transaction
  void setData(String key, dynamic value);
  
  /// Set tag on the transaction
  void setTag(String key, String value);
  
  /// Finish the transaction
  Future<void> finish();
}
