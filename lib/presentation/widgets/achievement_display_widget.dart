import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/domain/services/achievement_service.dart';
import 'package:puzzgame_flutter/core/domain/entities/user.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/presentation/theme/puzzle_bazaar_theme.dart';

/// Widget to display user achievements and sharing stats
class AchievementDisplayWidget extends StatefulWidget {
  final AppUser user;
  final bool showShareCount;
  final bool compact;

  const AchievementDisplayWidget({
    super.key,
    required this.user,
    this.showShareCount = true,
    this.compact = false,
  });

  @override
  State<AchievementDisplayWidget> createState() => _AchievementDisplayWidgetState();
}

class _AchievementDisplayWidgetState extends State<AchievementDisplayWidget> {
  final _achievementService = serviceLocator<AchievementService>();
  final _sharingService = serviceLocator<SharingTrackingService>();
  
  List<Achievement>? _achievements;
  List<Achievement>? _unlockedAchievements;
  int? _shareCount;
  int? _totalPoints;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final achievements = await _achievementService.getUserAchievements(userId: widget.user.id);
      final unlockedAchievements = await _achievementService.getUnlockedAchievements(userId: widget.user.id);
      final shareCount = widget.showShareCount 
          ? await _sharingService.getUserShareCount(userId: widget.user.id)
          : 0;
      final totalPoints = await _achievementService.getUserAchievementPoints(userId: widget.user.id);

      if (mounted) {
        setState(() {
          _achievements = achievements;
          _unlockedAchievements = unlockedAchievements;
          _shareCount = shareCount;
          _totalPoints = totalPoints;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading achievement data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (widget.compact) {
      return _buildCompactView();
    }

    return _buildFullView();
  }

  Widget _buildCompactView() {
    final unlockedCount = _unlockedAchievements?.length ?? 0;
    final totalCount = _achievements?.length ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PuzzleBazaarTheme.warmCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: PuzzleBazaarTheme.terracotta.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Achievement badge count
          _buildStatItem('🏆', '$unlockedCount/$totalCount'),
          if (widget.showShareCount && _shareCount != null) ...[
            const SizedBox(width: 16),
            _buildStatItem('📤', '$_shareCount'),
          ],
          if (_totalPoints != null && _totalPoints! > 0) ...[
            const SizedBox(width: 16),
            _buildStatItem('⭐', '$_totalPoints'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(
          value,
          style: PuzzleBazaarTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: PuzzleBazaarTheme.darkBrown,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFullView() {
    final unlockedCount = _unlockedAchievements?.length ?? 0;
    final totalCount = _achievements?.length ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PuzzleBazaarTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.military_tech,
                color: PuzzleBazaarTheme.goldenAmber,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Achievements',
                style: PuzzleBazaarTheme.subheadingStyle.copyWith(
                  fontSize: 18,
                  color: PuzzleBazaarTheme.richBrown,
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount/$totalCount',
                style: PuzzleBazaarTheme.bodyStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: PuzzleBazaarTheme.mutedBlue,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Stats row
          Row(
            children: [
              if (widget.showShareCount && _shareCount != null)
                Expanded(
                  child: _buildFullStatCard(
                    '📤',
                    'Shares',
                    '$_shareCount',
                    PuzzleBazaarTheme.mutedBlue,
                  ),
                ),
              if (widget.showShareCount && _shareCount != null && _totalPoints != null)
                const SizedBox(width: 12),
              if (_totalPoints != null)
                Expanded(
                  child: _buildFullStatCard(
                    '⭐',
                    'Points',
                    '$_totalPoints',
                    PuzzleBazaarTheme.goldenAmber,
                  ),
                ),
            ],
          ),
          
          if (_unlockedAchievements?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text(
              'Recent Achievements',
              style: PuzzleBazaarTheme.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: PuzzleBazaarTheme.darkBrown,
              ),
            ),
            const SizedBox(height: 8),
            
            // Show recent achievements
            ..._unlockedAchievements!.take(3).map((achievement) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAchievementItem(achievement),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullStatCard(String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: PuzzleBazaarTheme.subheadingStyle.copyWith(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: PuzzleBazaarTheme.captionStyle.copyWith(
              color: PuzzleBazaarTheme.softGrey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(Achievement achievement) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: PuzzleBazaarTheme.warmCream,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: PuzzleBazaarTheme.terracotta.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            achievement.iconEmoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              achievement.name,
              style: PuzzleBazaarTheme.bodyStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PuzzleBazaarTheme.darkBrown,
              ),
            ),
          ),
          if (achievement.isUnlocked)
            Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green.shade600,
            ),
        ],
      ),
    );
  }
}
