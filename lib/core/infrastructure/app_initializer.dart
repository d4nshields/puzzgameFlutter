import 'dart:async';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/error_reporting_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/infrastructure/desktop_window_config.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_config.dart';

/// AppInitializer is responsible for loading necessary resources and
/// initializing components during the splash screen display.
class AppInitializer {
  /// Initialize the application
  /// 
  /// Returns a future that completes when initialization is done
  static Future<void> initialize() async {
    // Record start time to ensure minimum splash screen duration if needed
    final startTime = DateTime.now();
    
    // Initialize services in parallel
    // Note: Supabase is already initialized in main() before dependency injection
    await Future.wait([
      _initializeErrorReporting(),
      _initializeGameModule(),
      _initializeDesktopWindow(),
      _preloadAssets(),
      _ensureMinimumSplashDuration(startTime),
    ]);
  }
  
  /// Initialize error reporting service
  static Future<void> _initializeErrorReporting() async {
    try {
      final errorReporting = serviceLocator<ErrorReportingService>();
      await errorReporting.initialize();
      
      // Set basic application context
      await errorReporting.addBreadcrumb(
        'Application started',
        category: 'app_lifecycle',
        level: 'info',
        data: {
          'app_version': '0.1.11+12',
          'platform': 'flutter',
        },
      );
      
      print('Error reporting service initialized successfully');
    } catch (e) {
      print('Error initializing error reporting service: $e');
      // Continue app initialization even if error reporting fails
    }
  }
  
  /// Initialize desktop window configuration for portrait layout
  static Future<void> _initializeDesktopWindow() async {
    try {
      await DesktopWindowConfig.initialize();
      print('Desktop window configuration initialized successfully');
    } catch (e) {
      print('Error initializing desktop window configuration: $e');
      // Continue anyway - non-critical error
    }
  }
  
  /// Initialize the game module
  static Future<void> _initializeGameModule() async {
    try {
      final gameModule = serviceLocator<GameModule>();
      await gameModule.initialize();
      print('Game module initialized successfully');
      
      // Report successful initialization
      final errorReporting = serviceLocator<ErrorReportingService>();
      await errorReporting.addBreadcrumb(
        'Game module initialized',
        category: 'initialization',
        level: 'info',
      );
    } catch (e) {
      print('Error initializing game module: $e');
      
      // Report the error
      try {
        final errorReporting = serviceLocator<ErrorReportingService>();
        await errorReporting.reportException(
          e,
          context: 'game_module_initialization',
          extra: {
            'stage': 'app_startup',
            'critical': true,
          },
        );
      } catch (reportingError) {
        print('Failed to report game module initialization error: $reportingError');
      }
      
      // Still continue app initialization - we'll handle this in the UI
    }
  }
  
  /// Preload any assets needed for immediate use
  static Future<void> _preloadAssets() async {
    try {
      // Preload images
      await Future.wait([
        // Add any images that need to be preloaded
        // Example: precacheImage(AssetImage('assets/images/background.png'), null),
      ]);
      
      // Preload other assets if needed
      await Future.wait([
        // Example: rootBundle.loadString('assets/data/game_config.json'),
      ]);
      
      print('Assets preloaded successfully');
    } catch (e) {
      print('Error preloading assets: $e');
      // Continue anyway - non-critical error
    }
  }
  
  /// Ensure the splash screen shows for at least a minimum duration
  static Future<void> _ensureMinimumSplashDuration(DateTime startTime) async {
    const minimumSplashDuration = Duration(milliseconds: 500); // Reduced for custom LoadingScreen
    final elapsedTime = DateTime.now().difference(startTime);
    
    if (elapsedTime < minimumSplashDuration) {
      final remainingTime = minimumSplashDuration - elapsedTime;
      await Future.delayed(remainingTime);
    }
  }
}
