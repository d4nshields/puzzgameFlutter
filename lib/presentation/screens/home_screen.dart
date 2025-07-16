import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';

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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      user.email.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Puzzle Nook!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/game');
                },
                child: const Text('Start New Game'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/lottie-test');
                },
                child: const Text('Test Animation'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
                child: const Text('Settings'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/auto-solve');
                },
                child: const Text('Auto-Solve (Debug)'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
                onPressed: () {
                  // Show about dialog
                  showAboutDialog(
                    context: context,
                    applicationName: 'Puzzle Nook',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2025',
                  );
                },
                child: const Text('About'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
