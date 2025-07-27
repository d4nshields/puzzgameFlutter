import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:puzzgame_flutter/presentation/theme/puzzle_bazaar_theme.dart';

/// Screen shown after successful registration to encourage sharing and highlight badge rewards
class SharingEncouragementScreen extends StatefulWidget {
  const SharingEncouragementScreen({super.key});

  @override
  State<SharingEncouragementScreen> createState() => _SharingEncouragementScreenState();
}

class _SharingEncouragementScreenState extends State<SharingEncouragementScreen> {
  bool _isSharing = false;

  Future<void> _shareApp() async {
    setState(() {
      _isSharing = true;
    });

    try {
      await Share.share(
        'I just discovered Puzzle Nook - a cozy puzzle solving game! 🧩 '
        'It\'s perfect for relaxing and challenging your mind. '
        'Download it here: https://play.google.com/store/apps/details?id=com.tinkerplexlabs.puzzlenook '
        'Join me in solving beautiful puzzles! 🎨 '
        '#PuzzleNook #PuzzleGame #CozyGaming',
        subject: 'Check out Puzzle Nook - A Cozy Puzzle Game!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing failed: $e'),
            backgroundColor: Colors.red,
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
          gradient: PuzzleBazaarTheme.warmGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                // Compact top section with logo and welcome
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
                          Icons.celebration,
                          size: 28,
                          color: PuzzleBazaarTheme.goldenAmber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to Puzzle Nook!',
                            style: PuzzleBazaarTheme.subheadingStyle.copyWith(
                              fontSize: 18,
                              color: PuzzleBazaarTheme.richBrown,
                            ),
                          ),
                          Text(
                            '🎉 Registration Complete',
                            style: PuzzleBazaarTheme.bodyStyle.copyWith(
                              color: PuzzleBazaarTheme.goldenAmber,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
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
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: PuzzleBazaarTheme.cardDecoration,
                    child: Column(
                      children: [
                        // Badge icon with decorative background
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                PuzzleBazaarTheme.goldenAmber,
                                PuzzleBazaarTheme.warmAmber,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: PuzzleBazaarTheme.goldenAmber.withOpacity(0.3),
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
                          style: PuzzleBazaarTheme.subheadingStyle.copyWith(
                            fontSize: 24,
                            color: PuzzleBazaarTheme.richBrown,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          'Share Puzzle Nook with friends and earn special badges for your profile:',
                          style: PuzzleBazaarTheme.bodyStyle.copyWith(
                            color: PuzzleBazaarTheme.softGrey,
                          ),
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
                          child: ElevatedButton.icon(
                            onPressed: _isSharing ? null : _shareApp,
                            icon: _isSharing 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.share,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              _isSharing ? 'Sharing...' : 'Share Puzzle Nook',
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
                        
                        // Skip button with less emphasis
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: PuzzleBazaarTheme.textButtonStyle,
                          child: Text(
                            'Continue to puzzles',
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
  
  Widget _buildBadgeReward(String emoji, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: PuzzleBazaarTheme.richBrown.withOpacity(0.1),
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
                  style: PuzzleBazaarTheme.bodyStyle.copyWith(
                    color: PuzzleBazaarTheme.darkBrown,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: PuzzleBazaarTheme.captionStyle.copyWith(
                    color: PuzzleBazaarTheme.softGrey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
