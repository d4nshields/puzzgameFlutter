import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

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
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CozyPuzzleTheme.linenWhite,
                      CozyPuzzleTheme.warmSand.withOpacity(0.5),
                    ],
                  ),
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
                            // App logo/title with cozy theme styling
                            CozyPuzzleTheme.createThemedContainer(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Puzzle',
                                    style: CozyPuzzleTheme.headingLarge.copyWith(
                                      fontSize: 36,
                                    ),
                                  ),
                                  Text(
                                    'Nook',
                                    style: CozyPuzzleTheme.headingLarge.copyWith(
                                      fontSize: 36,
                                      color: CozyPuzzleTheme.goldenSandbar,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 60),
                            
                            // Lottie loading animation with themed container
                            CozyPuzzleTheme.createThemedContainer(
                              isPrimary: false,
                              padding: const EdgeInsets.all(20),
                              child: Lottie.asset(
                                'assets/animations/loading_puzzle_pieces.json',
                                width: 180,
                                height: 180,
                                repeat: true,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: CozyPuzzleTheme.seafoamMist.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: CozyPuzzleTheme.seafoamMist,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.extension,
                                      size: 80,
                                      color: CozyPuzzleTheme.goldenSandbar,
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Loading text with cozy theme styling
                            CozyPuzzleTheme.createThemedContainer(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Text(
                                'Preparing your cozy puzzle experience...',
                                style: CozyPuzzleTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Progress indicator with cozy theme
                            CozyPuzzleTheme.createThemedContainer(
                              padding: const EdgeInsets.all(16),
                              child: SizedBox(
                                width: 240,
                                child: CozyPuzzleTheme.createProgressIndicator(
                                  height: 6,
                                ),
                              ),
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
