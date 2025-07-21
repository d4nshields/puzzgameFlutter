import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/infrastructure/app_initializer.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_config.dart';
import 'package:puzzgame_flutter/presentation/screens/game_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/home_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/settings_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/auto_solve_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/lottie_test_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/loading_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/sign_in_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/early_access_registration_screen.dart';

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

/// Main application widget
class PuzzleBazaarGameApp extends StatelessWidget {
  const PuzzleBazaarGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puzzle Nook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const GameScreen(), // Direct to game instead of home
        '/home': (context) => const HomeScreen(),
        '/sign-in': (context) => const SignInScreen(),
        '/early-access': (context) => const EarlyAccessRegistrationScreen(),
        '/game': (context) => const GameScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/auto-solve': (context) => const AutoSolveScreen(),
        '/lottie-test': (context) => const LottieTestScreen(),
      },
    );
  }
}
