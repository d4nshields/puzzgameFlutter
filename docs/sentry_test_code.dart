// Test Sentry Integration
// Add this to any button press or app startup for testing

import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/error_reporting_service.dart';

Future<void> testSentryIntegration() async {
  // Test 1: Manual exception report
  try {
    throw Exception('Test Sentry integration - this is a test crash');
  } catch (e, stackTrace) {
    final errorReporting = serviceLocator<ErrorReportingService>();
    await errorReporting.reportException(
      e,
      stackTrace: stackTrace,
      context: 'test_crash',
      extra: {
        'test_type': 'manual_exception',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Test 2: Message report
  final errorReporting = serviceLocator<ErrorReportingService>();
  await errorReporting.reportMessage(
    'Test message from production app',
    level: 'info',
    tags: {'test': 'true'},
  );

  // Test 3: Breadcrumb
  await errorReporting.addBreadcrumb(
    'User triggered test crash',
    category: 'user_action',
    data: {'action': 'test_button_pressed'},
  );
}
