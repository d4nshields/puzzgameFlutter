import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

/// Main screen of the application
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = serviceLocator<AuthService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Nook'),
        centerTitle: true,
        actions: [
          // Show sign-in or user avatar
          StreamBuilder(
            stream: _authService.authStateChanges,
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user != null) {
                // User is signed in - show avatar
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: CozyPuzzleTheme.goldenSandbar,
                    child: Text(
                      user.email.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: CozyPuzzleTheme.deepSlate),
                    ),
                  ),
                );
              } else {
                // User is not signed in - show sign-in button
                return IconButton(
                  icon: const Icon(Icons.account_circle),
                  onPressed: () {
                    Navigator.pushNamed(context, '/sign-in');
                  },
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CozyPuzzleTheme.linenWhite,
              CozyPuzzleTheme.warmSand.withOpacity(0.3),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to Puzzle Nook!',
                    style: CozyPuzzleTheme.headingLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cozy puzzle solving for relaxation',
                    style: CozyPuzzleTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Primary action - Start Game
                  CozyPuzzleTheme.createThemedButton(
                    text: 'Start New Game',
                    onPressed: () => Navigator.pushNamed(context, '/game'),
                    icon: Icons.play_arrow,
                    isPrimary: true,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Secondary actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CozyPuzzleTheme.createThemedButton(
                            text: 'Settings',
                            onPressed: () => Navigator.pushNamed(context, '/settings'),
                            icon: Icons.settings,
                            isPrimary: false,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: CozyPuzzleTheme.createThemedButton(
                            text: 'Test Animation',
                            onPressed: () => Navigator.pushNamed(context, '/lottie-test'),
                            icon: Icons.animation,
                            isPrimary: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Debug/Development actions in a card
                  CozyPuzzleTheme.createThemedContainer(
                    isPrimary: false,
                    child: Column(
                      children: [
                        Text(
                          'Developer Tools',
                          style: CozyPuzzleTheme.headingSmall,
                        ),
                        const SizedBox(height: 16),
                        CozyPuzzleTheme.createThemedButton(
                          text: 'Auto-Solve Debug',
                          onPressed: () => Navigator.pushNamed(context, '/auto-solve'),
                          icon: Icons.bug_report,
                          isAlert: true,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Puzzle Nook',
                              applicationVersion: '1.0.0',
                              applicationLegalese: '© 2025 - Cozy Puzzle Experience',
                              children: [
                                const SizedBox(height: 16),
                                Text(
                                  'A relaxing jigsaw puzzle game designed for cozy moments.',
                                  style: CozyPuzzleTheme.bodyMedium,
                                ),
                              ],
                            );
                          },
                          child: const Text('About Puzzle Nook'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
