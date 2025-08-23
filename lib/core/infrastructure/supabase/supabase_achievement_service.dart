import 'package:puzzgame_flutter/core/domain/services/achievement_service.dart';
import 'package:puzzgame_flutter/core/domain/entities/user.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';


/// Supabase implementation compatible with existing database schema
class SupabaseAchievementService implements AchievementService, SharingTrackingService {
  final _client = SupabaseConfig.client;
  final _uuid = const Uuid();

  // Predefined achievements configuration - adapted for existing schema
  static const List<Map<String, dynamic>> _defaultAchievements = [
    {
      'id': 'first_share',
      'achievement_type': 'firstShare',
      'title': 'First Share',
      'description': 'Share Puzzle Nook for the first time',
      'icon_emoji': '🌟',
      'rarity': 'common',
      'points_value': 10,
      'progress_required': 1,
      'requirements': {'shares': 1},
      'game': 'puzzle_nook',
    },
    {
      'id': 'social_ambassador',
      'achievement_type': 'socialAmbassador',
      'title': 'Puzzle Ambassador',
      'description': 'Get 3 friends to join through your shares',
      'icon_emoji': '🔥',
      'rarity': 'uncommon',
      'points_value': 50,
      'progress_required': 3,
      'requirements': {'referral_conversions': 3},
      'game': 'puzzle_nook',
    },
    {
      'id': 'community_builder',
      'achievement_type': 'communityBuilder',
      'title': 'Community Builder',
      'description': 'Help grow the puzzle community',
      'icon_emoji': '💎',
      'rarity': 'rare',
      'points_value': 100,
      'progress_required': 10,
      'requirements': {'shares': 10, 'referral_conversions': 1},
      'game': 'puzzle_nook',
    },
    {
      'id': 'first_puzzle_complete',
      'achievement_type': 'firstPuzzleComplete',
      'title': 'First Victory',
      'description': 'Complete your first puzzle',
      'icon_emoji': '🧩',
      'rarity': 'common',
      'points_value': 20,
      'progress_required': 1,
      'requirements': {'puzzles_completed': 1},
      'game': 'puzzle_nook',
    },
    {
      'id': 'speed_solver',
      'achievement_type': 'speedSolver',
      'title': 'Speed Solver',
      'description': 'Complete a puzzle in under 5 minutes',
      'icon_emoji': '⚡',
      'rarity': 'uncommon',
      'points_value': 30,
      'progress_required': 1,
      'requirements': {'fast_completion': 1},
      'game': 'puzzle_nook',
    },
    {
      'id': 'daily_player',
      'achievement_type': 'dailyPlayer',
      'title': 'Daily Puzzler',
      'description': 'Play puzzles for 7 consecutive days',
      'icon_emoji': '📅',
      'rarity': 'uncommon',
      'points_value': 40,
      'progress_required': 7,
      'requirements': {'consecutive_days': 7},
      'game': 'puzzle_nook',
    },
    {
      'id': 'puzzle_master',
      'achievement_type': 'puzzleMaster',
      'title': 'Puzzle Master',
      'description': 'Complete 50 puzzles',
      'icon_emoji': '👑',
      'rarity': 'epic',
      'points_value': 200,
      'progress_required': 50,
      'requirements': {'puzzles_completed': 50},
      'game': 'puzzle_nook',
    },
    {
      'id': 'early_adopter',
      'achievement_type': 'earlyAdopter',
      'title': 'Early Adopter',
      'description': 'Join the Puzzle Nook community',
      'icon_emoji': '🚀',
      'rarity': 'common',
      'points_value': 15,
      'progress_required': 1,
      'requirements': {'registered': true},
      'game': 'puzzle_nook',
    },
  ];

  @override
  Future<void> initializeUserAchievements({required String userId}) async {
    try {
      // Check if user already has achievements initialized
      final existing = await _client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId)
          .limit(1);

      if (existing.isNotEmpty) {
        print('User $userId already has achievements initialized');
        return;
      }

      // First, ensure all achievement definitions exist in the achievements table
      await _ensureAchievementDefinitionsExist();

      // Insert user achievement progress records
      final userAchievements = _defaultAchievements.map((config) {
        return {
          'user_id': userId,
          'achievement_id': config['id'], // Use the string ID from our config
          'game': config['game'],
          'achievement_type': config['achievement_type'],
          'name': config['title'], // Map title to name field
          'description': config['description'],
          'icon_emoji': config['icon_emoji'],
          'rarity': config['rarity'],
          'points_value': config['points_value'],
          'progress_current': 0,
          'progress_required': config['progress_required'],
          'requirements': config['requirements'],
          'is_hidden': false,
          'unlocked_at': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _client.from('user_achievements').insert(userAchievements);
      
      // Award early adopter achievement immediately
      await _unlockAchievement(
        userId: userId, 
        achievementType: AchievementType.earlyAdopter,
      );

      print('Initialized ${userAchievements.length} achievements for user $userId');
    } catch (e) {
      print('Error initializing user achievements: $e');
    }
  }

  Future<void> _ensureAchievementDefinitionsExist() async {
    try {
      // Check if achievements already exist
      final existing = await _client
          .from('achievements')
          .select('id')
          .limit(1);

      if (existing.isNotEmpty) {
        return; // Achievements already defined
      }

      // Insert achievement definitions
      final achievementDefs = _defaultAchievements.map((config) {
        return {
          'id': config['id'],
          'game': config['game'],
          'title': config['title'],
          'description': config['description'],
          'icon_url': null, // We're using emoji instead
          'criteria': config['requirements'],
          'achievement_type': config['achievement_type'],
          'icon_emoji': config['icon_emoji'],
          'rarity': config['rarity'],
          'points_value': config['points_value'],
          'progress_required': config['progress_required'],
          'requirements': config['requirements'],
          'is_hidden': false,
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _client.from('achievements').insert(achievementDefs);
      print('Created ${achievementDefs.length} achievement definitions');
    } catch (e) {
      print('Error ensuring achievement definitions exist: $e');
    }
  }

  @override
  Future<List<Achievement>> getUserAchievements({required String userId}) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('*')
          .eq('user_id', userId)
          .order('created_at');

      return response.map<Achievement>((json) => _mapToAchievement(json)).toList();
    } catch (e) {
      print('Error getting user achievements: $e');
      return [];
    }
  }

  @override
  Future<List<Achievement>> getUnlockedAchievements({required String userId}) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('*')
          .eq('user_id', userId)
          .not('unlocked_at', 'is', null)
          .order('unlocked_at', ascending: false);

      return response.map<Achievement>((json) => _mapToAchievement(json)).toList();
    } catch (e) {
      print('Error getting unlocked achievements: $e');
      return [];
    }
  }

  @override
  Future<List<Achievement>> recordEvent({
    required String eventType,
    AppUser? user,
    String? deviceId,
    String? sessionId,
    Map<String, dynamic>? eventData,
  }) async {
    final newlyUnlocked = <Achievement>[];
    
    try {
      // Record the event
      await _client.from('user_events').insert({
        'id': _uuid.v4(),
        'user_id': user?.id,
        'event_type': eventType,
        'timestamp': DateTime.now().toIso8601String(),
        'event_data': eventData ?? {},
        'device_id': deviceId,
        'session_id': sessionId,
      });

      // If user is not logged in, we can't check achievements
      if (user?.id == null) return newlyUnlocked;

      // Check relevant achievements based on event type
      final achievementsToCheck = _getRelevantAchievements(eventType);
      
      for (final achievementType in achievementsToCheck) {
        final achievement = await checkAchievementProgress(
          userId: user!.id,
          achievementType: achievementType,
        );
        
        if (achievement != null && achievement.isUnlocked) {
          newlyUnlocked.add(achievement);
        }
      }

      print('Recorded event $eventType for user ${user?.id}, unlocked ${newlyUnlocked.length} achievements');
    } catch (e) {
      print('Error recording event: $e');
    }

    return newlyUnlocked;
  }

  @override
  Future<Achievement?> checkAchievementProgress({
    required String userId,
    required AchievementType achievementType,
  }) async {
    try {
      // Get current achievement state
      final response = await _client
          .from('user_achievements')
          .select('*')
          .eq('user_id', userId)
          .eq('achievement_type', achievementType.name)
          .single();

      final achievement = _mapToAchievement(response);
      
      // If already unlocked, return as-is
      if (achievement.isUnlocked) return achievement;

      // Calculate current progress based on achievement type
      final newProgress = await _calculateProgress(userId, achievementType);
      
      // Update progress in database
      final updatedData = <String, dynamic>{
        'progress_current': newProgress,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if achievement should be unlocked
      if (newProgress >= achievement.progressRequired) {
        updatedData['unlocked_at'] = DateTime.now().toIso8601String();
      }

      await _client
          .from('user_achievements')
          .update(updatedData)
          .eq('user_id', userId)
          .eq('achievement_type', achievementType.name);

      return achievement.copyWith(
        progressCurrent: newProgress,
        unlockedAt: newProgress >= achievement.progressRequired 
            ? DateTime.now() 
            : null,
      );
    } catch (e) {
      print('Error checking achievement progress: $e');
      return null;
    }
  }

  @override
  Future<int> getUserAchievementPoints({required String userId}) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('points_value')
          .eq('user_id', userId)
          .not('unlocked_at', 'is', null);

      return response.fold<int>(0, (sum, achievement) => 
          sum + ((achievement['points_value'] as num?)?.toInt() ?? 0));
    } catch (e) {
      print('Error getting user achievement points: $e');
      return 0;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAchievementLeaderboard({int limit = 10}) async {
    try {
      // This would require a more complex query or a view in Supabase
      // For now, return empty list - implement if needed
      return [];
    } catch (e) {
      print('Error getting achievement leaderboard: $e');
      return [];
    }
  }

  // Sharing tracking implementation
  @override
  Future<void> recordShare({
    AppUser? user,
    String? deviceId,
    String? sessionId,
    String shareType = 'app_share',
    Map<String, dynamic>? shareData,
  }) async {
    try {
      // Record the share event
      await recordEvent(
        eventType: 'share',
        user: user,
        deviceId: deviceId,
        sessionId: sessionId,
        eventData: {
          'share_type': shareType,
          ...?shareData,
        },
      );

      print('Recorded share for user ${user?.id}');
    } catch (e) {
      print('Error recording share: $e');
    }
  }

  @override
  Future<int> getUserShareCount({required String userId}) async {
    try {
      final response = await _client
          .from('user_events')
          .select('id')
          .eq('user_id', userId)
          .eq('event_type', 'share');

      return response.length;
    } catch (e) {
      print('Error getting user share count: $e');
      return 0;
    }
  }

  @override
  Future<int> getTotalShareCount() async {
    try {
      final response = await _client
          .from('user_events')
          .select('id')
          .eq('event_type', 'share');

      return response.length;
    } catch (e) {
      print('Error getting total share count: $e');
      return 0;
    }
  }

  @override
  Future<void> recordShareVisit({
    String? referrerUserId,
    String? deviceId,
    Map<String, dynamic>? visitData,
  }) async {
    try {
      await _client.from('user_events').insert({
        'id': _uuid.v4(),
        'user_id': null, // Visitor might not be registered yet
        'event_type': 'share_visit',
        'timestamp': DateTime.now().toIso8601String(),
        'event_data': {
          'referrer_user_id': referrerUserId,
          ...?visitData,
        },
        'device_id': deviceId,
      });
    } catch (e) {
      print('Error recording share visit: $e');
    }
  }

  @override
  Future<void> recordShareConversion({
    String? referrerUserId,
    String? newUserId,
    String? deviceId,
    Map<String, dynamic>? conversionData,
  }) async {
    try {
      await _client.from('user_events').insert({
        'id': _uuid.v4(),
        'user_id': newUserId,
        'event_type': 'share_conversion',
        'timestamp': DateTime.now().toIso8601String(),
        'event_data': {
          'referrer_user_id': referrerUserId,
          ...?conversionData,
        },
        'device_id': deviceId,
      });

      // Update referrer's achievement progress
      if (referrerUserId != null) {
        await recordEvent(
          eventType: 'referral_conversion',
          user: AppUser(
            id: referrerUserId, 
            email: '', 
            createdAt: DateTime.now(),
          ),
          deviceId: deviceId,
          eventData: {
            'new_user_id': newUserId,
          },
        );
      }
    } catch (e) {
      print('Error recording share conversion: $e');
    }
  }

  // Helper methods
  Achievement _mapToAchievement(Map<String, dynamic> json) {
    return Achievement(
      id: json['achievement_id'] as String? ?? json['id'] as String,
      type: AchievementType.values.firstWhere(
        (e) => e.name == json['achievement_type'],
        orElse: () => AchievementType.firstShare,
      ),
      name: json['name'] as String? ?? json['title'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      iconEmoji: json['icon_emoji'] as String? ?? '🏆',
      rarity: AchievementRarity.values.firstWhere(
        (e) => e.name == json['rarity'],
        orElse: () => AchievementRarity.common,
      ),
      requirements: (json['requirements'] as Map<String, dynamic>?) ?? {},
      pointsValue: (json['points_value'] as num?)?.toInt() ?? 0,
      isHidden: (json['is_hidden'] as bool?) ?? false,
      unlockedAt: json['unlocked_at'] != null 
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
      progressCurrent: (json['progress_current'] as num?)?.toInt() ?? 0,
      progressRequired: (json['progress_required'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> _unlockAchievement({
    required String userId,
    required AchievementType achievementType,
  }) async {
    try {
      await _client
          .from('user_achievements')
          .update({
            'unlocked_at': DateTime.now().toIso8601String(),
            'progress_current': 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('achievement_type', achievementType.name);
    } catch (e) {
      print('Error unlocking achievement: $e');
    }
  }

  List<AchievementType> _getRelevantAchievements(String eventType) {
    switch (eventType) {
      case 'share':
        return [AchievementType.firstShare, AchievementType.communityBuilder];
      case 'puzzle_completed':
        return [AchievementType.firstPuzzleComplete, AchievementType.puzzleMaster];
      case 'referral_conversion':
        return [AchievementType.socialAmbassador, AchievementType.communityBuilder];
      default:
        return [];
    }
  }

  Future<int> _calculateProgress(String userId, AchievementType achievementType) async {
    switch (achievementType) {
      case AchievementType.firstShare:
      case AchievementType.communityBuilder:
        return await getUserShareCount(userId: userId);
      
      case AchievementType.socialAmbassador:
        // Count referral conversions
        final response = await _client
            .from('user_events')
            .select('id')
            .eq('user_id', userId)
            .eq('event_type', 'referral_conversion');
        return response.length;
      
      case AchievementType.firstPuzzleComplete:
      case AchievementType.puzzleMaster:
        // Count completed puzzles
        final response = await _client
            .from('user_events')
            .select('id')
            .eq('user_id', userId)
            .eq('event_type', 'puzzle_completed');
        return response.length;
      
      default:
        return 0;
    }
  }
}
