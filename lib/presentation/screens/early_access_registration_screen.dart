import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/presentation/theme/puzzle_bazaar_theme.dart';

/// Screen shown after completing the first puzzle to encourage registration
class EarlyAccessRegistrationScreen extends StatefulWidget {
  const EarlyAccessRegistrationScreen({super.key});

  @override
  State<EarlyAccessRegistrationScreen> createState() => _EarlyAccessRegistrationScreenState();
}

class _EarlyAccessRegistrationScreenState extends State<EarlyAccessRegistrationScreen> {
  final _authService = serviceLocator<AuthService>();
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        // Show success message and navigate back to game
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome ${user.email}! Thanks for registering for early access.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Navigate back to the game
        Navigator.of(context).pop();
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
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                
                // App icon/logo area with theme styling
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: PuzzleBazaarTheme.warmShadow,
                    border: Border.all(
                      color: PuzzleBazaarTheme.terracotta.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.extension,
                        size: 60,
                        color: PuzzleBazaarTheme.mutedBlue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Puzzle',
                        style: PuzzleBazaarTheme.captionStyle.copyWith(
                          color: PuzzleBazaarTheme.richBrown,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Nook', // Correct app name
                        style: PuzzleBazaarTheme.captionStyle.copyWith(
                          color: PuzzleBazaarTheme.mutedBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Congratulations text with theme styling
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: PuzzleBazaarTheme.warmShadow,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '🎉 Congratulations!',
                        style: PuzzleBazaarTheme.subheadingStyle.copyWith(
                          color: PuzzleBazaarTheme.goldenAmber,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'You completed your first puzzle!',
                        style: PuzzleBazaarTheme.bodyStyle.copyWith(
                          color: PuzzleBazaarTheme.softGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Early access registration card with theme
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: PuzzleBazaarTheme.cardDecoration,
                  child: Column(
                    children: [
                      Text(
                        'Join the Puzzle Nook',
                        style: PuzzleBazaarTheme.subheadingStyle.copyWith(
                          color: PuzzleBazaarTheme.richBrown,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        'Register for early access and be the first to explore our cozy collection of puzzles:',
                        style: PuzzleBazaarTheme.bodyStyle.copyWith(
                          color: PuzzleBazaarTheme.softGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Features list with themed styling
                      Column(
                        children: [
                          _buildFeatureItem('🧩', 'Exclusive puzzle collections'),
                          _buildFeatureItem('🎨', 'Beautiful custom themes'),
                          _buildFeatureItem('🏆', 'Achievements & progress tracking'),
                          _buildFeatureItem('☁️', 'Sync all games across all your devices'),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Sign in with Google button with theme
                      SizedBox(
                        width: double.infinity,
                        height: 56,
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
                            ),
                          ),
                          style: PuzzleBazaarTheme.primaryButtonStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Skip option with theme
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: PuzzleBazaarTheme.textButtonStyle,
                    child: Text(
                      'Continue exploring for now',
                      style: PuzzleBazaarTheme.bodyStyle.copyWith(
                        color: PuzzleBazaarTheme.mutedBlue,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem(String emoji, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PuzzleBazaarTheme.warmCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PuzzleBazaarTheme.terracotta.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: PuzzleBazaarTheme.mutedBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: PuzzleBazaarTheme.bodyStyle.copyWith(
                color: PuzzleBazaarTheme.darkBrown,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
