import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/infrastructure/app_initializer.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_config.dart';
import 'package:puzzgame_flutter/core/domain/services/game_session_tracking_service.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/core/configuration/build_config.dart';
import 'package:puzzgame_flutter/core/configuration/feature_aware_navigation.dart';
import 'package:puzzgame_flutter/presentation/screens/game_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/home_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/settings_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/auto_solve_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/lottie_test_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/loading_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/sign_in_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/early_access_registration_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/sharing_encouragement_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/puzzle_library_screen.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase first (required before setting up dependencies)
  await _initializeSupabase();
  
  // Set up dependency injection
  setupDependencies();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Start app initialization (async)
  final initializationFuture = AppInitializer.initialize();
  
  // Track app launch (after Supabase is initialized)
  _trackAppLaunch();
  
  // Run the app immediately with loading screen
  runApp(
    ProviderScope(
      child: LoadingScreen(
        initializationFuture: initializationFuture,
        child: const PuzzleBazaarGameApp(),
      ),
    ),
  );
}

/// Initialize Supabase early (before dependency injection)
Future<void> _initializeSupabase() async {
  try {
    await SupabaseConfig.initialize();
    print('Supabase initialized successfully in main()');
  } catch (e) {
    print('Error initializing Supabase in main(): $e');
    // Continue app initialization even if Supabase fails
    // Users can still play offline
  }
}

/// Track app launch for analytics
Future<void> _trackAppLaunch() async {
  try {
    // Import the tracking service only when needed
    final trackingService = serviceLocator<GameSessionTrackingService>();
    final authService = serviceLocator<AuthService>();
    final currentUser = authService.currentUser;
    
    await trackingService.recordAppUsage(
      user: currentUser,
      usageData: {
        'action': 'app_launch',
        'platform': 'flutter',
        'launch_time': DateTime.now().toIso8601String(),
      },
    );
  } catch (e) {
    print('Warning: Failed to track app launch: $e');
    // Don't throw - app should continue even if tracking fails
  }
}

/// Main application widget with feature flag integration
class PuzzleBazaarGameApp extends StatelessWidget {
  const PuzzleBazaarGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puzzle Nook',
      theme: CozyPuzzleTheme.lightTheme,
      // Note: Dark theme implementation can be added later if needed
      // For now, using light theme for consistency with cozy aesthetic
      
      // Enable debug banner only for internal builds
      debugShowCheckedModeBanner: Debug.enabled,
      
      // Show performance overlay if enabled in debug config
      showPerformanceOverlay: Debug.performanceOverlay,
      
      initialRoute: '/',
      routes: {
        '/': (context) => const FeatureAwareHomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/sign-in': (context) => Features.googleSignIn 
            ? const SignInScreen() 
            : const FeatureDisabledScreen(featureName: 'Google Sign-In'),
        '/early-access': (context) => Features.earlyAccessRegistration 
            ? const EarlyAccessRegistrationScreen() 
            : const FeatureDisabledScreen(featureName: 'Early Access Registration'),
        '/sharing-encouragement': (context) => Features.sharingFlow 
            ? const SharingEncouragementScreen() 
            : const FeatureDisabledScreen(featureName: 'Sharing Features'),
        '/game': (context) => const GameScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/auto-solve': (context) => const AutoSolveScreen(),
        '/lottie-test': (context) => Features.experimentalFeatures 
            ? const LottieTestScreen() 
            : const FeatureDisabledScreen(featureName: 'Test Features'),
        '/puzzle-library': (context) => const PuzzleLibraryScreen(),
      },
    );
  }
}

/// Home screen that immediately navigates based on feature flags
class FeatureAwareHomeScreen extends StatefulWidget {
  const FeatureAwareHomeScreen({super.key});

  @override
  State<FeatureAwareHomeScreen> createState() => _FeatureAwareHomeScreenState();
}

class _FeatureAwareHomeScreenState extends State<FeatureAwareHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate immediately without showing any intermediate screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FeatureAwareNavigationService.navigateToAppropriateScreen(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Return transparent container to avoid any visual flash
    // The navigation happens immediately in initState
    return const Scaffold(
      body: SizedBox.shrink(), // Invisible placeholder
    );
  }
}

/// Screen shown when a feature is disabled in the current build
class FeatureDisabledScreen extends StatelessWidget {
  final String featureName;
  
  const FeatureDisabledScreen({
    super.key,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Not Available'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                '$featureName Not Available',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is not available in the current version of the app.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/game'),
                child: const Text('Continue to Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
