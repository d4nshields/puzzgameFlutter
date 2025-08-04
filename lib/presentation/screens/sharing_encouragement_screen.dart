import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/core/domain/services/achievement_service.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

/// Screen shown after successful registration to encourage sharing and highlight badge rewards
class SharingEncouragementScreen extends StatefulWidget {
  const SharingEncouragementScreen({super.key});

  @override
  State<SharingEncouragementScreen> createState() => _SharingEncouragementScreenState();
}

class _SharingEncouragementScreenState extends State<SharingEncouragementScreen> {
  final _authService = serviceLocator<AuthService>();
  bool _isSharing = false;

  Future<void> _shareApp() async {
    setState(() {
      _isSharing = true;
    });

    try {
      // Record the share event - implement proper tracking when available
      try {
        // TODO: Implement SharingTrackingService when analytics is expanded
      // For now, log the event for debugging
      final user = _authService.currentUser;
      print('Share event: user=${user?.email ?? "anonymous"}, timestamp=${DateTime.now().toIso8601String()}');
      
      // Could also report to error reporting service as a breadcrumb
      // _errorReporting.addBreadcrumb('share_attempted', data: {'user_id': user?.id});
    } catch (e) {
      print('Warning: Failed to log share event: $e');
    }
      
      await Share.share(
        'I just discovered Puzzle Nook - a cozy puzzle solving game! 🧩 '
        'It\'s perfect for relaxing and challenging your mind. '
        'Download it here: https://play.google.com/store/apps/details?id=com.tinkerplexlabs.puzzlenook '
        'Join me in solving beautiful puzzles! 🎨 '
        '#PuzzleNook #PuzzleGame #CozyGaming',
        subject: 'Check out Puzzle Nook - A Cozy Puzzle Game!',
      );
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thanks for sharing Puzzle Nook! 🌟',
              style: CozyPuzzleTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: CozyPuzzleTheme.seafoamMist,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sharing failed: $e',
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
          _isSharing = false;
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
                // Compact top section with logo and welcome
                CozyPuzzleTheme.createThemedContainer(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: CozyPuzzleTheme.coralBlush.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CozyPuzzleTheme.coralBlush,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.celebration,
                          size: 28,
                          color: CozyPuzzleTheme.coralBlush,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to Puzzle Nook!',
                            style: CozyPuzzleTheme.headingSmall,
                          ),
                          Text(
                            '🎉 Registration Complete',
                            style: CozyPuzzleTheme.bodyMedium.copyWith(
                              color: CozyPuzzleTheme.coralBlush,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Main sharing encouragement card
                Expanded(
                  child: CozyPuzzleTheme.createThemedContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Badge icon with decorative background
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                CozyPuzzleTheme.goldenSandbar,
                                CozyPuzzleTheme.goldenSandbar.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: CozyPuzzleTheme.goldenSandbar.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.military_tech,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Text(
                          'Earn Profile Badges!',
                          style: CozyPuzzleTheme.headingMedium,
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          'Share Puzzle Nook with friends and earn special badges for your profile:',
                          style: CozyPuzzleTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Badge rewards list
                        Column(
                          children: [
                            _buildBadgeReward(
                              '🌟', 
                              'First Share', 
                              'Share the app for the first time'
                            ),
                            const SizedBox(height: 12),
                            _buildBadgeReward(
                              '🔥', 
                              'Puzzle Ambassador', 
                              'Get 3 friends to join'
                            ),
                            const SizedBox(height: 12),
                            _buildBadgeReward(
                              '💎', 
                              'Community Builder', 
                              'Help grow the puzzle community'
                            ),
                          ],
                        ),
                        
                        const Spacer(),
                        
                        // Share button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: CozyPuzzleTheme.createThemedButton(
                          text: _isSharing ? 'Sharing...' : 'Share Puzzle Nook',
                          onPressed: _isSharing ? null : _shareApp,
                          icon: _isSharing ? null : Icons.share,
                          isPrimary: true,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Skip button with less emphasis
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Continue to puzzles',
                            style: CozyPuzzleTheme.bodyMedium.copyWith(
                              color: CozyPuzzleTheme.stoneGray,
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
  
  Widget _buildBadgeReward(String emoji, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CozyPuzzleTheme.linenWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CozyPuzzleTheme.seafoamMist.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CozyPuzzleTheme.seafoamMist.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: CozyPuzzleTheme.deepSlate.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CozyPuzzleTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: CozyPuzzleTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
