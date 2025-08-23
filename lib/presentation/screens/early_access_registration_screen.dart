import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/core/domain/services/achievement_service.dart';
// import 'package:puzzgame_flutter/core/configuration/build_config.dart'; // Not used
import 'package:puzzgame_flutter/core/configuration/feature_aware_navigation.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

/// Screen shown after completing the first puzzle to encourage registration
class EarlyAccessRegistrationScreen extends StatefulWidget {
  const EarlyAccessRegistrationScreen({super.key});

  @override
  State<EarlyAccessRegistrationScreen> createState() => _EarlyAccessRegistrationScreenState();
}

class _EarlyAccessRegistrationScreenState extends State<EarlyAccessRegistrationScreen> {
  final _authService = serviceLocator<AuthService>();
  final _achievementService = serviceLocator<AchievementService>();
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        // Initialize achievements for new user
        await _achievementService.initializeUserAchievements(userId: user.id);
        
        // Navigate using feature-aware navigation
        FeatureAwareNavigationService.handlePostRegistrationNavigation(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign in failed: $e',
              style: CozyPuzzleTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: CozyPuzzleTheme.coralBlush,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CozyPuzzleTheme.linenWhite,
              CozyPuzzleTheme.warmSand.withOpacity(0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                // Compact top section with logo and congratulations
                CozyPuzzleTheme.createThemedContainer(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: CozyPuzzleTheme.goldenSandbar.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CozyPuzzleTheme.goldenSandbar,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.extension,
                          size: 28,
                          color: CozyPuzzleTheme.goldenSandbar,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Puzzle Nook',
                            style: CozyPuzzleTheme.headingSmall,
                          ),
                          Text(
                            '🎉 Coming Soon!',
                            style: CozyPuzzleTheme.bodyMedium.copyWith(
                              color: CozyPuzzleTheme.goldenSandbar,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Main registration card
                Expanded(
                  child: CozyPuzzleTheme.createThemedContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Join the Puzzle Nook',
                          style: CozyPuzzleTheme.headingMedium,
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          'Get early access to new puzzles and features:',
                          style: CozyPuzzleTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Compact features list - 2 columns
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _buildCompactFeatureItem('🧩', 'New puzzle packs'),
                                  const SizedBox(height: 8),
                                  _buildCompactFeatureItem('🏆', 'Progress tracking'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildCompactFeatureItem('🎨', 'Custom themes'),
                                  const SizedBox(height: 8),
                                  _buildCompactFeatureItem('☁️', 'Cloud sync'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const Spacer(),
                        
                        // Prominent sign-in button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: CozyPuzzleTheme.createThemedButton(
                            text: _isSigningIn ? 'Joining...' : 'Join with Google',
                            onPressed: _isSigningIn ? () {} : _signInWithGoogle,
                            icon: _isSigningIn 
                                ? null 
                                : Icons.login,
                            isPrimary: true,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Browse Puzzle Library button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: CozyPuzzleTheme.createThemedButton(
                            text: '🧩 Browse Puzzle Library',
                            onPressed: () => Navigator.of(context).pushNamed('/puzzle-library'),
                            isPrimary: false,
                          ),
                        ),
                        
                        // Extra bottom padding to avoid gesture navigation
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCompactFeatureItem(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CozyPuzzleTheme.linenWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CozyPuzzleTheme.seafoamMist.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: CozyPuzzleTheme.seafoamMist.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: CozyPuzzleTheme.bodySmall.copyWith(
                color: CozyPuzzleTheme.deepSlate,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
