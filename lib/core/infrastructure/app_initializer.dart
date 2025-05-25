import 'dart:async';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';

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
    await Future.wait([
      _initializeGameModule(),
      _preloadAssets(),
      _ensureMinimumSplashDuration(startTime),
    ]);
  }
  
  /// Initialize the game module
  static Future<void> _initializeGameModule() async {
    try {
      final gameModule = serviceLocator<GameModule>();
      await gameModule.initialize();
      print('Game module initialized successfully');
    } catch (e) {
      print('Error initializing game module: $e');
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
    const minimumSplashDuration = Duration(seconds: 2);
    final elapsedTime = DateTime.now().difference(startTime);
    
    if (elapsedTime < minimumSplashDuration) {
      final remainingTime = minimumSplashDuration - elapsedTime;
      await Future.delayed(remainingTime);
    }
  }
}
