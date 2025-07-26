import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:puzzgame_flutter/presentation/theme/puzzle_bazaar_theme.dart';

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
              body: Container(
                decoration: BoxDecoration(
                  gradient: PuzzleBazaarTheme.warmGradient,
                ),
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // App logo/title with theme styling
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: PuzzleBazaarTheme.warmShadow,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Puzzle',
                                    style: PuzzleBazaarTheme.headingStyle.copyWith(
                                      fontSize: 36,
                                      color: PuzzleBazaarTheme.richBrown,
                                    ),
                                  ),
                                  Text(
                                    'Nook', // Correct app name
                                    style: PuzzleBazaarTheme.headingStyle.copyWith(
                                      fontSize: 36,
                                      color: PuzzleBazaarTheme.mutedBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 60),
                            
                            // Lottie loading animation with themed container
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: PuzzleBazaarTheme.warmShadow,
                              ),
                              child: Lottie.asset(
                                'assets/animations/loading_puzzle_pieces.json',
                                width: 180,
                                height: 180,
                                repeat: true,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 180,
                                    height: 180,
                                    decoration: PuzzleBazaarTheme.iconDecoration,
                                    child: const Icon(
                                      Icons.extension,
                                      size: 80,
                                      color: PuzzleBazaarTheme.mutedBlue,
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Loading text with theme styling
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Preparing your cozy puzzle experience...',
                                style: PuzzleBazaarTheme.bodyStyle,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Progress indicator with theme
                            Container(
                              width: 240,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: PuzzleBazaarTheme.createProgressIndicator(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
