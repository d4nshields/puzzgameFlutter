import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/core/domain/services/achievement_service.dart';
import 'package:puzzgame_flutter/presentation/theme/puzzle_bazaar_theme.dart';

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
        
        // Show success message and navigate to sharing encouragement
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome ${user.email}! Thanks for registering for early access.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Navigate to sharing encouragement screen
        Navigator.of(context).pushReplacementNamed('/sharing-encouragement');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: Colors.red,
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
          gradient: PuzzleBazaarTheme.warmGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                // Compact top section with logo and congratulations
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: PuzzleBazaarTheme.warmShadow,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: PuzzleBazaarTheme.warmCream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: PuzzleBazaarTheme.terracotta.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.extension,
                          size: 28,
                          color: PuzzleBazaarTheme.mutedBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Puzzle Nook',
                            style: PuzzleBazaarTheme.subheadingStyle.copyWith(
                              fontSize: 20,
                              color: PuzzleBazaarTheme.richBrown,
                            ),
                          ),
                          Text(
                            '🎉 Puzzle Complete!',
                            style: PuzzleBazaarTheme.bodyStyle.copyWith(
                              color: PuzzleBazaarTheme.goldenAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Main registration card - more compact
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: PuzzleBazaarTheme.cardDecoration,
                    child: Column(
                      children: [
                        Text(
                          'Join the Puzzle Nook',
                          style: PuzzleBazaarTheme.subheadingStyle.copyWith(
                            fontSize: 22,
                            color: PuzzleBazaarTheme.richBrown,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          'Get early access to new puzzles and features:',
                          style: PuzzleBazaarTheme.bodyStyle.copyWith(
                            color: PuzzleBazaarTheme.softGrey,
                          ),
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
                          child: ElevatedButton.icon(
                            onPressed: _isSigningIn ? null : _signInWithGoogle,
                            icon: _isSigningIn 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 20,
                                    height: 20,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.login,
                                      color: Colors.white,
                                    ),
                                  ),
                            label: Text(
                              _isSigningIn ? 'Joining...' : 'Join with Google',
                              style: PuzzleBazaarTheme.buttonTextStyle.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: PuzzleBazaarTheme.primaryButtonStyle,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Compact skip option
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: PuzzleBazaarTheme.textButtonStyle,
                          child: Text(
                            'Continue exploring',
                            style: PuzzleBazaarTheme.bodyStyle.copyWith(
                              color: PuzzleBazaarTheme.mutedBlue,
                              fontSize: 14,
                            ),
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
        color: PuzzleBazaarTheme.warmCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: PuzzleBazaarTheme.terracotta.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
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
              style: PuzzleBazaarTheme.bodyStyle.copyWith(
                color: PuzzleBazaarTheme.darkBrown,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
