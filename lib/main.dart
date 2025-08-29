import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/infrastructure/app_initializer.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_config.dart';
import 'package:puzzgame_flutter/core/configuration/build_config.dart';
import 'package:puzzgame_flutter/game_module2/infrastructure/feature_flags.dart';
import 'package:puzzgame_flutter/presentation/screens/loading_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/early_access_registration_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/sharing_encouragement_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/sign_in_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/game_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/home_screen.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Global feature flag service instance
late final FeatureFlagService _globalFeatureFlags;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase first
  await SupabaseConfig.initialize();
  print('Supabase initialized successfully in main()');
  
  // Initialize Feature Flags BEFORE service locator setup
  print('=== INITIALIZING FEATURE FLAGS ===');
  print('Creating FeatureFlagService instance...');
  _globalFeatureFlags = FeatureFlagService.instance;
  print('Calling initialize on FeatureFlagService...');
  await _globalFeatureFlags.initialize();
  print('Feature flag initialization complete');
  
  // Debug output for feature flags
  print('Checking feature flag values...');
  final showSamplePuzzle = await _globalFeatureFlags.isEnabled('sample_puzzle');
  final magneticGestures = await _globalFeatureFlags.isEnabled('magnetic_gestures');
  final enhancedFeedback = await _globalFeatureFlags.isEnabled('enhanced_feedback');
  final smoothAnimations = await _globalFeatureFlags.isEnabled('smooth_animations');
  
  print('=== FEATURE FLAG STATUS ===');
  print('sample_puzzle: $showSamplePuzzle');
  print('magnetic_gestures: $magneticGestures');
  print('enhanced_feedback: $enhancedFeedback');
  print('smooth_animations: $smoothAnimations');
  print('Flag source: ${_globalFeatureFlags.lastSource}');
  print('Environment: ${_globalFeatureFlags.currentEnvironment}');
  print('===========================');
  
  // IMPORTANT: Override navigation based on feature flag
  if (!showSamplePuzzle) {
    print('>>> SAMPLE PUZZLE DISABLED - Should show menu/registration <<<');
  } else {
    print('>>> SAMPLE PUZZLE ENABLED - Will show puzzle <<<');
  }
  
  // Set up dependency injection
  setupDependencies();
  
  // Initialize Sentry
  final sentryDsn = const String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    print('Sentry DSN configured: ${sentryDsn.substring(0, 30)}...');
  }
  
  // Create and run the app with or without Sentry based on configuration
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = Debug.enabled ? 'development' : 'production';
        options.debug = Debug.enabled;
        options.tracesSampleRate = Debug.enabled ? 1.0 : 0.1; // 100% in debug, 10% in production
        options.attachScreenshot = true;
        options.attachViewHierarchy = true;
        options.profilesSampleRate = Debug.enabled ? 1.0 : 0.1;
      },
      appRunner: () => runApp(
        ProviderScope(
          child: PuzzleBazaarGameApp(),
        ),
      ),
    );
  } else {
    runApp(
      ProviderScope(
        child: PuzzleBazaarGameApp(),
      ),
    );
  }
}

/// Main application widget
class PuzzleBazaarGameApp extends StatelessWidget {
  const PuzzleBazaarGameApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Set preferred orientations (portrait for mobile)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return MaterialApp(
      title: 'Puzzle Nook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoadingScreen(
        initializationFuture: AppInitializer.initialize(),
        child: FeatureFlagAwareHome(),
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/game': (context) => const GameScreen(),
        '/early-access': (context) => const EarlyAccessRegistrationScreen(),
        '/sharing-encouragement': (context) => const SharingEncouragementScreen(),
        '/sign-in': (context) => const SignInScreen(),
      },
      debugShowCheckedModeBanner: Debug.enabled,
    );
  }
}

/// Widget that decides which screen to show based on feature flags
class FeatureFlagAwareHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('>>> FeatureFlagAwareHome: Checking feature flags...');
    
    return FutureBuilder<bool>(
      future: _globalFeatureFlags.isEnabled('sample_puzzle'),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          print('>>> FeatureFlagAwareHome: Still loading flags...');
          // Still checking feature flags
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final showSamplePuzzle = snapshot.data ?? false;
        
        print('>>> FeatureFlagAwareHome: sample_puzzle = $showSamplePuzzle');
        print('>>> FeatureFlagAwareHome: Navigating to ${showSamplePuzzle ? "GameScreen" : "EarlyAccessRegistrationScreen"}');
        
        // Navigate based on feature flag
        if (showSamplePuzzle) {
          // Show the game directly if sample puzzle is enabled
          return const GameScreen();
        } else {
          // Show early access registration if sample puzzle is disabled
          if (Features.earlyAccessRegistration) {
            return const EarlyAccessRegistrationScreen();
          } else {
            // Fallback to home screen
            return const HomeScreen();
          }
        }
      },
    );
  }
}
