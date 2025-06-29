import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Custom loading screen with Lottie animation shown during app initialization
class LoadingScreen extends StatelessWidget {
  final Future<void> initializationFuture;
  final Widget child;

  const LoadingScreen({
    super.key,
    required this.initializationFuture,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initializationFuture,
      builder: (context, snapshot) {
        // Show loading screen while initialization is in progress
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo/title
                    const Text(
                      'Puzzle Bazaar',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 60),
                    
                    // Lottie loading animation
                    Lottie.asset(
                      'assets/animations/loading_puzzle_pieces.json',
                      width: 200,
                      height: 200,
                      repeat: true,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Loading text
                    const Text(
                      'Loading your puzzle experience...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Progress indicator
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Show main app after initialization is complete
        return child;
      },
    );
  }
}
