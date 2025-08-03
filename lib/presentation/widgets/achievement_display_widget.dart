import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/domain/services/achievement_service.dart';
import 'package:puzzgame_flutter/core/domain/entities/user.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

/// Widget to display user achievements with cozy theme
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
  
  List<Achievement>? _achievements;
  List<Achievement>? _unlockedAchievements;
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
      final totalPoints = await _achievementService.getUserAchievementPoints(userId: widget.user.id);

      if (mounted) {
        setState(() {
          _achievements = achievements;
          _unlockedAchievements = unlockedAchievements;
          _totalPoints = totalPoints;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading achievement data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Set default values for graceful degradation
          _achievements = [];
          _unlockedAchievements = [];
          _totalPoints = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CozyPuzzleTheme.createThemedContainer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: CozyPuzzleTheme.goldenSandbar,
              ),
              const SizedBox(height: 12),
              Text(
                'Loading achievements...',
                style: CozyPuzzleTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (widget.compact) {
      return _buildCompactView();
    } else {
      return _buildFullView();
    }
  }

  Widget _buildCompactView() {
    final unlockedCount = _unlockedAchievements?.length ?? 0;
    final totalCount = _achievements?.length ?? 0;
    final points = _totalPoints ?? 0;

    return CozyPuzzleTheme.createThemedContainer(
      isPrimary: false,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Achievement icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CozyPuzzleTheme.goldenSandbar.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.emoji_events,
              color: CozyPuzzleTheme.goldenSandbar,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Achievement text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  totalCount > 0 ? '$unlockedCount/$totalCount Achievements' : 'No achievements yet',
                  style: CozyPuzzleTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (points > 0)
                  Text(
                    '$points points earned',
                    style: CozyPuzzleTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullView() {
    final unlockedCount = _unlockedAchievements?.length ?? 0;
    final totalCount = _achievements?.length ?? 0;
    final points = _totalPoints ?? 0;
    final progressPercentage = totalCount > 0 ? (unlockedCount / totalCount) : 0.0;

    return CozyPuzzleTheme.createThemedContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and points
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CozyPuzzleTheme.goldenSandbar.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: CozyPuzzleTheme.goldenSandbar,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievements',
                      style: CozyPuzzleTheme.headingSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalCount > 0 ? '$unlockedCount of $totalCount unlocked' : 'No achievements available',
                      style: CozyPuzzleTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (points > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CozyPuzzleTheme.coralBlush.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CozyPuzzleTheme.coralBlush.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    '$points pts',
                    style: CozyPuzzleTheme.labelLarge.copyWith(
                      color: CozyPuzzleTheme.deepSlate,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          if (totalCount > 0) ...[
            const SizedBox(height: 20),
            
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: CozyPuzzleTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                CozyPuzzleTheme.createProgressIndicator(
                  value: progressPercentage,
                  height: 8,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progressPercentage * 100).toInt()}% Complete',
                      style: CozyPuzzleTheme.bodySmall,
                    ),
                    Text(
                      '$unlockedCount/$totalCount',
                      style: CozyPuzzleTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ],
          
          // Recent achievements (if any)
          if (_unlockedAchievements != null && _unlockedAchievements!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Recent Achievements',
              style: CozyPuzzleTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            ...(_unlockedAchievements!.take(3).map((achievement) => 
              _buildAchievementTile(achievement)
            )),
            if (_unlockedAchievements!.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    _showAllAchievements();
                  },
                  child: Text(
                    'View all ${_unlockedAchievements!.length} achievements',
                    style: CozyPuzzleTheme.bodyMedium.copyWith(
                      color: CozyPuzzleTheme.stoneGray,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ] else if (totalCount == 0) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.star_outline,
                    size: 48,
                    color: CozyPuzzleTheme.stoneGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start playing to unlock achievements!',
                    style: CozyPuzzleTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementTile(Achievement achievement) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CozyPuzzleTheme.linenWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CozyPuzzleTheme.weatheredDriftwood.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Achievement icon/emoji
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CozyPuzzleTheme.goldenSandbar.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  achievement.emoji ?? '🏆',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Achievement details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: CozyPuzzleTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (achievement.description.isNotEmpty)
                    Text(
                      achievement.description,
                      style: CozyPuzzleTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            // Points
            if (achievement.points > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CozyPuzzleTheme.coralBlush.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${achievement.points}',
                  style: CozyPuzzleTheme.labelSmall.copyWith(
                    color: CozyPuzzleTheme.deepSlate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAllAchievements() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CozyPuzzleTheme.linenWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Achievements',
              style: CozyPuzzleTheme.headingMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _unlockedAchievements?.length ?? 0,
                itemBuilder: (context, index) {
                  final achievement = _unlockedAchievements![index];
                  return _buildAchievementTile(achievement);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
