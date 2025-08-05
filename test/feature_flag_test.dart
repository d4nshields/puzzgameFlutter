import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/core/configuration/build_config.dart';

/// Tests for the feature flag system with corrected behavior
void main() {
  group('BuildConfig Tests', () {
    test('should have valid build configuration', () {
      expect(BuildConfig.currentVariant, isA<String>());
      expect(BuildConfig.isInternal, isA<bool>());
      expect(BuildConfig.isExternal, isA<bool>());
      expect(BuildConfig.isInternal != BuildConfig.isExternal, isTrue);
    });

    test('should provide convenient feature access with clear naming', () {
      // Test that Features class provides access to feature flags with clear names
      expect(Features.samplePuzzle, isA<bool>());
      expect(Features.googleSignIn, isA<bool>());
      expect(Features.earlyAccessRegistration, isA<bool>());
      expect(Features.sharingFlow, isA<bool>());
      expect(Features.debugTools, isA<bool>());
      expect(Features.experimentalFeatures, isA<bool>());
      expect(Features.detailedAnalytics, isA<bool>());
      expect(Features.performanceMonitoring, isA<bool>());
    });

    test('should provide convenient debug access', () {
      // Test that Debug class provides access to debug settings
      expect(Debug.enabled, isA<bool>());
      expect(Debug.performanceOverlay, isA<bool>());
      expect(Debug.widgetInspector, isA<bool>());
      expect(Debug.verboseLogging, isA<bool>());
    });

    test('should provide navigation configuration access', () {
      // Test that Navigation class provides access to navigation settings
      expect(Navigation.initialRoute, isA<String>());
      expect(Navigation.postGameRoute, isA<String>());
      expect(Navigation.postRegistrationRoute, isA<String>());
      
      // Routes should be non-empty
      expect(Navigation.initialRoute.isNotEmpty, isTrue);
      expect(Navigation.postGameRoute.isNotEmpty, isTrue);
      expect(Navigation.postRegistrationRoute.isNotEmpty, isTrue);
    });

    test('should provide feature, debug, and navigation summaries', () {
      final featureSummary = BuildConfig.featureSummary;
      final debugSummary = BuildConfig.debugSummary;
      final navigationSummary = BuildConfig.navigationSummary;
      
      expect(featureSummary, isA<Map<String, bool>>());
      expect(debugSummary, isA<Map<String, bool>>());
      expect(navigationSummary, isA<Map<String, String>>());
      expect(featureSummary.isNotEmpty, isTrue);
      expect(debugSummary.isNotEmpty, isTrue);
      expect(navigationSummary.isNotEmpty, isTrue);
      
      // Check that key features are included
      expect(featureSummary.containsKey('samplePuzzle'), isTrue);
      expect(featureSummary.containsKey('googleSignIn'), isTrue);
      expect(navigationSummary.containsKey('initialRoute'), isTrue);
    });
  });

  group('Feature Flag Logic Tests - CORRECTED BEHAVIOR', () {
    test('sample puzzle should be correctly enabled/disabled based on build variant', () {
      // These features should always be enabled in both builds
      expect(Features.googleSignIn, isTrue);
      expect(Features.earlyAccessRegistration, isTrue);
      expect(Features.sharingFlow, isTrue);
      
      // CORRECTED LOGIC: Sample puzzle behavior based on build variant
      if (BuildConfig.isExternal) {
        // External build - sample puzzle should be DISABLED (not ready for users)
        expect(Features.samplePuzzle, isFalse, 
            reason: 'Sample puzzle should be DISABLED in external builds (not ready for users)');
        expect(Features.debugTools, isFalse);
        expect(Features.experimentalFeatures, isFalse);
        expect(Features.detailedAnalytics, isFalse);
        expect(Debug.enabled, isFalse);
        expect(Debug.verboseLogging, isFalse);
        
        // Navigation should skip sample puzzle
        expect(Navigation.initialRoute, equals('early_access_registration'),
            reason: 'External builds should skip sample puzzle and go to early access');
      } else {
        // Internal build - sample puzzle should be ENABLED (for development)
        expect(Features.samplePuzzle, isTrue,
            reason: 'Sample puzzle should be ENABLED in internal builds (for development)');
        expect(Features.debugTools, isTrue);
        expect(Features.experimentalFeatures, isTrue);
        expect(Features.detailedAnalytics, isTrue);
        expect(Debug.enabled, isTrue);
        expect(Debug.verboseLogging, isTrue);
        
        // Navigation should start with sample puzzle
        expect(Navigation.initialRoute, equals('sample_puzzle'),
            reason: 'Internal builds should start with sample puzzle for development');
      }
    });
    
    test('navigation configuration should be consistent with feature flags', () {
      // Initial route should match sample puzzle availability
      if (Features.samplePuzzle) {
        expect(Navigation.initialRoute, equals('sample_puzzle'),
            reason: 'When sample puzzle is enabled, should start with sample puzzle');
      } else {
        expect(Navigation.initialRoute, equals('early_access_registration'),
            reason: 'When sample puzzle is disabled, should skip to early access');
      }
      
      // Post-game and post-registration routes should be valid
      expect(Navigation.postGameRoute, isA<String>());
      expect(Navigation.postRegistrationRoute, isA<String>());
    });
  });

  group('Build Information Tests', () {
    test('should provide build information', () {
      expect(BuildInfo.variantName, isA<String>());
      expect(BuildInfo.buildSummary, isA<String>());
      expect(BuildInfo.buildSummary.isNotEmpty, isTrue);
    });

    test('build summary should contain relevant information', () {
      final summary = BuildInfo.buildSummary;
      expect(summary.contains('Build Variant:'), isTrue);
      expect(summary.contains('Features:'), isTrue);
      expect(summary.contains('Debug Settings:'), isTrue);
      expect(summary.contains('Navigation:'), isTrue);
    });

    test('build variant should be correctly identified', () {
      final variant = BuildInfo.variantName;
      expect(['internal', 'external'].contains(variant), isTrue);
      
      // Consistency check
      if (variant == 'internal') {
        expect(BuildConfig.isInternal, isTrue);
        expect(BuildConfig.isExternal, isFalse);
      } else {
        expect(BuildConfig.isExternal, isTrue);
        expect(BuildConfig.isInternal, isFalse);
      }
    });
  });
}
