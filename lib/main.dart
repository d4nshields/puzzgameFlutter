import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzgame_flutter/game_module2/game_module2.dart';
import 'package:puzzgame_flutter/game_module2/infrastructure/feature_flags.dart';
import 'package:puzzgame_flutter/core/services/error_reporting_service.dart';
import 'package:puzzgame_flutter/core/services/supabase_game_session_tracking.dart';
import 'package:puzzgame_flutter/core/services/asset_preloader.dart';
import 'package:puzzgame_flutter/core/configuration/desktop_window_config.dart';
import 'package:puzzgame_flutter/screens/main_menu_screen.dart';
import 'package:puzzgame_flutter/screens/puzzle_game_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  print('Supabase initialized successfully in main()');
  
  // Initialize Feature Flags BEFORE anything else that might need them
  print('Initializing feature flag service...');
  final featureFlags = FeatureFlagService.instance;
  await featureFlags.initialize();
  
  // Debug output for feature flags
  final showSamplePuzzle = await featureFlags.isEnabled('sample_puzzle');
  final magneticGestures = await featureFlags.isEnabled('magnetic_gestures');
  final enhancedFeedback = await featureFlags.isEnabled('enhanced_feedback');
  final smoothAnimations = await featureFlags.isEnabled('smooth_animations');
  
  print('=== FEATURE FLAG STATUS ===');
  print('sample_puzzle: $showSamplePuzzle');
  print('magnetic_gestures: $magneticGestures');
  print('enhanced_feedback: $enhancedFeedback');
  print('smooth_animations: $smoothAnimations');
  print('Flag source: ${featureFlags.lastSource}');
  print('Environment: ${featureFlags.currentEnvironment}');
  print('===========================');
  
  // Initialize game module with feature flags available
  await PuzzleGameModule2.instance.initialize();
  print('Game module initialized successfully');
  
  // Desktop window configuration
  await DesktopWindowConfig.initialize();
  
  // Initialize Sentry
  final sentryDsn = const String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    print('Sentry DSN configured: ${sentryDsn.substring(0, 30)}...');
  }
  
  // Preload assets
  await AssetPreloader.preloadAssets();
  print('Assets preloaded successfully');
  
  // Initialize error reporting
  final errorReportingService = SentryErrorReportingService();
  await errorReportingService.initialize();
  print('Error reporting service initialized successfully');
  
  // Initialize game session tracking
  final sessionTracking = SupabaseGameSessionTracking();
  await sessionTracking.initialize();
  
  // Determine initial route based on feature flag
  final Widget initialScreen = showSamplePuzzle 
      ? PuzzleGameScreen() 
      : MainMenuScreen();
  
  print('Initial screen: ${showSamplePuzzle ? "PuzzleGameScreen" : "MainMenuScreen"}');
  
  // Run app with Sentry wrapper if DSN is configured
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.1;
        options.profilesSampleRate = 0.1;
      },
      appRunner: () => runApp(PuzzleNookApp(
        initialScreen: initialScreen,
        featureFlags: featureFlags,
      )),
    );
  } else {
    runApp(PuzzleNookApp(
      initialScreen: initialScreen,
      featureFlags: featureFlags,
    ));
  }
}

class PuzzleNookApp extends StatelessWidget {
  final Widget initialScreen;
  final FeatureFlagService featureFlags;
  
  const PuzzleNookApp({
    Key? key,
    required this.initialScreen,
    required this.featureFlags,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Set preferred orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    return MaterialApp(
      title: 'Puzzle Nook',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: initialScreen,
      routes: {
        '/menu': (context) => MainMenuScreen(),
        '/puzzle': (context) => PuzzleGameScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}