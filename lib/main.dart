import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:puzzgame_flutter/core/infrastructure/app_initializer.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/presentation/screens/game_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/home_screen.dart';
import 'package:puzzgame_flutter/presentation/screens/settings_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up dependency injection
  setupDependencies();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize app services and resources
  // The native splash screen will be shown during this time
  await AppInitializer.initialize();
  
  // Run the app with Sentry integration
  await SentryFlutter.init(
    (options) {
      // This will be overridden by SentryErrorReportingService,
      // but we need this minimal setup for Flutter error capture
      options.dsn = 'https://bad7dd46cda8efe8c1d48e06a893a048@o4509486679195648.ingest.de.sentry.io/4509486690467920';
      options.debug = false;
    },
    appRunner: () => runApp(
      // Wrap the app with ProviderScope for Riverpod state management
      const ProviderScope(
        child: PuzzleBazaarGameApp(),
      ),
    ),
  );
}

/// Main application widget
class PuzzleBazaarGameApp extends StatelessWidget {
  const PuzzleBazaarGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puzzle Bazaar',
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
        '/': (context) => const HomeScreen(),
        '/game': (context) => const GameScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
