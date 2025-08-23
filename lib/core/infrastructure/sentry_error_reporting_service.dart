import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:puzzgame_flutter/core/domain/services/error_reporting_service.dart';

/// Sentry implementation of ErrorReportingService
/// 
/// Provides crash reporting and performance monitoring using Sentry.
/// Designed to be privacy-conscious and GDPR-compliant.
class SentryErrorReportingService implements ErrorReportingService {
  bool _isInitialized = false;
  bool _isEnabled = true;
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      print('SentryErrorReportingService: Already initialized');
      return;
    }
    
    try {
      await SentryFlutter.init(
        (options) {
          // TODO: Replace with your actual Sentry DSN
          // Get this from: https://sentry.io/settings/[your-org]/projects/[your-project]/keys/
          options.dsn = _getDsn();
          
          // Environment configuration
          options.environment = kDebugMode ? 'development' : 'production';
          options.debug = kDebugMode;
          
          // Performance monitoring
          options.tracesSampleRate = 0.1; // 10% sampling for performance
          options.profilesSampleRate = 0.1; // 10% profiling sampling
          
          // Privacy settings
          options.sendDefaultPii = false; // Don't send personally identifiable info
          options.attachStacktrace = true; // Include stack traces
          options.attachViewHierarchy = false; // Don't send UI hierarchy
          
          // Release tracking
          options.release = _getRelease();
          
          // Custom filtering
          options.beforeSend = _filterEvent;
          options.beforeBreadcrumb = _filterBreadcrumb;
          
          // Data scrubbing for privacy - simplified for Sentry 8.x
          // Note: Sentry 8.x handles most sensitive data scrubbing automatically
          // including file path sanitization and PII detection
          // Our privacy settings above (sendDefaultPii = false) provide the main protection
        },
      );
      
      _isInitialized = true;
      print('SentryErrorReportingService: Initialized successfully');
      
      // Send a test event to verify connection
      await Sentry.captureMessage(
        'Sentry integration test - app started',
        level: SentryLevel.info,
      );
      print('SentryErrorReportingService: Test message sent to Sentry');
    } catch (e) {
      print('SentryErrorReportingService: Failed to initialize: $e');
      _isEnabled = false;
    }
  }
  
  @override
  Future<void> reportException(
    dynamic exception, {
    dynamic stackTrace,
    String? context,
    Map<String, dynamic>? extra,
    String? userId,
    Map<String, String>? tags,
  }) async {
    if (!_isEnabled || !_isInitialized) return;
    
    try {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        withScope: (scope) {
          // Add context information
          if (context != null) {
            scope.setTag('context', context);
          }
          
          if (userId != null) {
            scope.setUser(SentryUser(id: userId));
          }
          
          // Add tags
          tags?.forEach((key, value) {
            scope.setTag(key, value);
          });
          
          // Add extra data
          if (extra != null) {
            extra.forEach((key, value) {
              scope.setExtra(key, value);
            });
          }
          
          // Add puzzle game specific context
          scope.setTag('app_section', 'puzzle_game');
          scope.level = SentryLevel.error;
        },
      );
    } catch (e) {
      print('SentryErrorReportingService: Failed to report exception: $e');
    }
  }
  
  @override
  Future<void> reportMessage(
    String message, {
    String level = 'info',
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
  }) async {
    if (!_isEnabled || !_isInitialized) return;
    
    try {
      final sentryLevel = _convertLogLevel(level);
      
      await Sentry.captureMessage(
        message,
        level: sentryLevel,
        withScope: (scope) {
          tags?.forEach((key, value) {
            scope.setTag(key, value);
          });
          
          if (extra != null) {
            extra.forEach((key, value) {
              scope.setExtra(key, value);
            });
          }
        },
      );
    } catch (e) {
      print('SentryErrorReportingService: Failed to report message: $e');
    }
  }
  
  @override
  Future<void> setUserContext({
    String? userId,
    String? email,
    Map<String, dynamic>? extra,
  }) async {
    if (!_isEnabled || !_isInitialized) return;
    
    try {
      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: userId,
          email: email,
          extras: extra,
        ));
      });
    } catch (e) {
      print('SentryErrorReportingService: Failed to set user context: $e');
    }
  }
  
  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    String level = 'info',
    Map<String, dynamic>? data,
  }) async {
    if (!_isEnabled || !_isInitialized) return;
    
    try {
      await Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        category: category,
        level: _convertLogLevel(level),
        data: data,
      ));
    } catch (e) {
      print('SentryErrorReportingService: Failed to add breadcrumb: $e');
    }
  }
  
  @override
  Future<PerformanceTransaction?> startTransaction(
    String name,
    String operation,
  ) async {
    if (!_isEnabled || !_isInitialized) return null;
    
    try {
      final transaction = Sentry.startTransaction(name, operation);
      return SentryPerformanceTransaction(transaction);
    } catch (e) {
      print('SentryErrorReportingService: Failed to start transaction: $e');
      return null;
    }
  }
  
  @override
  bool get isEnabled => _isEnabled && _isInitialized;
  
  @override
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    
    try {
      await Sentry.configureScope((scope) {
        scope.clear();
      });
    } catch (e) {
      print('SentryErrorReportingService: Failed to configure enabled state: $e');
    }
  }
  
  // Private helper methods
  
  String _getDsn() {
    // Your actual Sentry DSN from your Sentry project
    const dsn = 'https://bad7dd46cda8efe8c1d48e06a893a048@o4509486679195648.ingest.de.sentry.io/4509486690467920';
    
    // For environment variable approach, uncomment below and comment above:
    // const dsn = String.fromEnvironment(
    //   'SENTRY_DSN',
    //   defaultValue: 'https://bad7dd46cda8efe8c1d48e06a893a048@o4509486679195648.ingest.de.sentry.io/4509486690467920',
    // );
    
    print('Sentry DSN configured: ${dsn.substring(0, 30)}...'); // Log partial DSN for verification
    return dsn;
  }
  
  String _getRelease() {
    // This should match your app version
    return 'puzzgame_flutter@0.1.11+12';
  }
  
  FutureOr<SentryEvent?> _filterEvent(SentryEvent event, Hint hint) {
    // Temporarily disable filtering for debugging
    // TODO: Re-enable filtering after confirming Sentry works
    print('Sentry: Allowing event - ${event.exceptions?.first.type}');
    return event;
    
    // Original filtering code (commented out for debugging):
    /*
    // Filter out events we don't want to report
    
    // Skip debug mode events unless explicitly enabled
    if (kDebugMode && !kDebugMode) {
      return null;
    }
    
    // Filter out specific exception types that are not actionable
    final exception = event.exceptions?.first;
    if (exception != null) {
      final exceptionType = exception.type;
      
      // Skip network connectivity issues
      if (exceptionType?.contains('SocketException') == true ||
          exceptionType?.contains('TimeoutException') == true) {
        return null;
      }
      
      // Skip asset loading issues in debug mode
      if (kDebugMode && exceptionType?.contains('AssetBundle') == true) {
        return null;
      }
    }
    
    return event;
    */
  }
  
  Breadcrumb? _filterBreadcrumb(Breadcrumb? breadcrumb, Hint? hint) {
    // Filter out noisy breadcrumbs
    if (breadcrumb?.message?.contains('setState') == true ||
        breadcrumb?.message?.contains('build') == true) {
      return null;
    }
    
    return breadcrumb;
  }
  
  SentryLevel _convertLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return SentryLevel.debug;
      case 'info':
        return SentryLevel.info;
      case 'warning':
      case 'warn':
        return SentryLevel.warning;
      case 'error':
        return SentryLevel.error;
      case 'fatal':
        return SentryLevel.fatal;
      default:
        return SentryLevel.info;
    }
  }
}

/// Sentry implementation of PerformanceTransaction
class SentryPerformanceTransaction implements PerformanceTransaction {
  final ISentrySpan _transaction;
  
  SentryPerformanceTransaction(this._transaction);
  
  @override
  void setData(String key, dynamic value) {
    _transaction.setData(key, value);
  }
  
  @override
  void setTag(String key, String value) {
    _transaction.setTag(key, value);
  }
  
  @override
  Future<void> finish() async {
    await _transaction.finish();
  }
}
