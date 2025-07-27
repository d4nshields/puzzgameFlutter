import 'package:puzzgame_flutter/core/domain/entities/user.dart';

/// Achievement types that can be unlocked
enum AchievementType {
  firstShare,
  firstPuzzleComplete,
  speedSolver,
  dailyPlayer,
  weeklyStreak,
  puzzleMaster,
  socialAmbassador,
  communityBuilder,
  earlyAdopter,
  perfectionist,
}

/// Achievement rarity levels
enum AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

/// Data class representing an achievement
class Achievement {
  final String id;
  final AchievementType type;
  final String name;
  final String description;
  final String iconEmoji;
  final AchievementRarity rarity;
  final Map<String, dynamic> requirements;
  final int pointsValue;
  final bool isHidden; // Some achievements are hidden until unlocked
  final DateTime? unlockedAt; // null if not unlocked
  final int progressCurrent;
  final int progressRequired;

  const Achievement({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.iconEmoji,
    required this.rarity,
    required this.requirements,
    required this.pointsValue,
    this.isHidden = false,
    this.unlockedAt,
    this.progressCurrent = 0,
    this.progressRequired = 1,
  });

  bool get isUnlocked => unlockedAt != null;
  bool get isComplete => progressCurrent >= progressRequired;
  double get progressPercentage => 
      progressRequired > 0 ? (progressCurrent / progressRequired).clamp(0.0, 1.0) : 1.0;

  Achievement copyWith({
    String? id,
    AchievementType? type,
    String? name,
    String? description,
    String? iconEmoji,
    AchievementRarity? rarity,
    Map<String, dynamic>? requirements,
    int? pointsValue,
    bool? isHidden,
    DateTime? unlockedAt,
    int? progressCurrent,
    int? progressRequired,
  }) {
    return Achievement(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      rarity: rarity ?? this.rarity,
      requirements: requirements ?? this.requirements,
      pointsValue: pointsValue ?? this.pointsValue,
      isHidden: isHidden ?? this.isHidden,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressRequired: progressRequired ?? this.progressRequired,
    );
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      type: AchievementType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AchievementType.firstShare,
      ),
      name: json['name'] as String,
      description: json['description'] as String,
      iconEmoji: json['icon_emoji'] as String,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'description': description,
      'icon_emoji': iconEmoji,
      'rarity': rarity.name,
      'requirements': requirements,
      'points_value': pointsValue,
      'is_hidden': isHidden,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'progress_current': progressCurrent,
      'progress_required': progressRequired,
    };
  }
}

/// Data class for tracking user events
class UserEvent {
  final String id;
  final String? userId;
  final String eventType;
  final DateTime timestamp;
  final Map<String, dynamic> eventData;
  final String? deviceId;
  final String? sessionId; // Now UUID string, but we'll handle as string in Dart

  const UserEvent({
    required this.id,
    this.userId,
    required this.eventType,
    required this.timestamp,
    required this.eventData,
    this.deviceId,
    this.sessionId,
  });

  factory UserEvent.fromJson(Map<String, dynamic> json) {
    return UserEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      eventType: json['event_type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      eventData: (json['event_data'] as Map<String, dynamic>?) ?? {},
      deviceId: json['device_id'] as String?,
      sessionId: json['session_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_type': eventType,
      'timestamp': timestamp.toIso8601String(),
      'event_data': eventData,
      'device_id': deviceId,
      'session_id': sessionId,
    };
  }
}

/// Service interface for tracking achievements and user events
abstract class AchievementService {
  /// Initialize achievements for a user (called after registration)
  Future<void> initializeUserAchievements({required String userId});
  
  /// Get all achievements for a user
  Future<List<Achievement>> getUserAchievements({required String userId});
  
  /// Get unlocked achievements for a user
  Future<List<Achievement>> getUnlockedAchievements({required String userId});
  
  /// Record a user event and check for achievement progress
  Future<List<Achievement>> recordEvent({
    required String eventType,
    AppUser? user,
    String? deviceId,
    String? sessionId,
    Map<String, dynamic>? eventData,
  });
  
  /// Check and update achievement progress for a specific achievement
  Future<Achievement?> checkAchievementProgress({
    required String userId,
    required AchievementType achievementType,
  });
  
  /// Get user's total achievement points
  Future<int> getUserAchievementPoints({required String userId});
  
  /// Get leaderboard of users by achievement points
  Future<List<Map<String, dynamic>>> getAchievementLeaderboard({
    int limit = 10,
  });
}

/// Service interface for tracking sharing and social features
abstract class SharingTrackingService {
  /// Record a share event
  Future<void> recordShare({
    AppUser? user,
    String? deviceId,
    String? sessionId,
    String shareType = 'app_share',
    Map<String, dynamic>? shareData,
  });
  
  /// Get share count for a user
  Future<int> getUserShareCount({required String userId});
  
  /// Get total app shares (for analytics)
  Future<int> getTotalShareCount();
  
  /// Record when someone visits from a shared link
  Future<void> recordShareVisit({
    String? referrerUserId,
    String? deviceId,
    Map<String, dynamic>? visitData,
  });
  
  /// Record when someone installs from a shared link
  Future<void> recordShareConversion({
    String? referrerUserId,
    String? newUserId,
    String? deviceId,
    Map<String, dynamic>? conversionData,
  });
}
