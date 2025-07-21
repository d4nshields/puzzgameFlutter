import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Custom loading screen with Lottie animation shown during app initialization
class LoadingScreen extends StatefulWidget {
  final Future<void> initializationFuture;
  final Widget child;

  const LoadingScreen({
    super.key,
    required this.initializationFuture,
    required this.child,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Set up fade-in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    // Start fade-in after a brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // Ensure minimum display time for the animation
    final combinedFuture = Future.wait([
      widget.initializationFuture,
      Future.delayed(const Duration(seconds: 2)), // Minimum animation time
    ]);

    return FutureBuilder<List<void>>(
      future: combinedFuture,
      builder: (context, snapshot) {
        // Show loading screen while initialization is in progress
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black, // Start with black to match native splash
              body: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Black background
                      Container(color: Colors.black),
                      
                      // White loading content that fades in
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // App logo/title
                                const Text(
                                  'Puzzle Nook',
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
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }

        // Show main app after initialization is complete
        return widget.child;
      },
    );
  }
}
