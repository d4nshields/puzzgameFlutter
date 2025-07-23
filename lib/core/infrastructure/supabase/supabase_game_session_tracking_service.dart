import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:puzzgame_flutter/core/domain/services/game_session_tracking_service.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/entities/user.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_config.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Supabase implementation of game session tracking
class SupabaseGameSessionTrackingService implements GameSessionTrackingService {
  final _client = SupabaseConfig.client;
  
  @override
  Future<void> startGameSession({
    required GameSession gameSession,
    AppUser? user,
    String? gameType,
    Map<String, dynamic>? initialSessionData,
  }) async {
    try {
      // Determine game type from session or use provided one
      final resolvedGameType = gameType ?? _determineGameType(gameSession);
      
      // Prepare session data
      final sessionData = <String, dynamic>{
        ...?initialSessionData,
        'session_id': gameSession.sessionId,
        'started_at': DateTime.now().toIso8601String(),
        'initial_score': gameSession.score,
        'initial_level': gameSession.level,
        'is_active': gameSession.isActive,
      };

      // Add puzzle-specific data if it's a puzzle game session
      if (gameSession is PuzzleGameSession) {
        sessionData.addAll({
          'puzzle_id': gameSession.currentPuzzleId,
          'grid_size': gameSession.gridSize,
          'total_pieces': gameSession.totalPieces,
          'difficulty': gameSession.gridSize, // Assuming grid size correlates with difficulty
          'use_enhanced_rendering': gameSession.useEnhancedRendering,
          'use_memory_optimization': gameSession.useMemoryOptimization,
        });
      }

      // Insert into game_sessions table
      await _client.from('game_sessions').insert({
        'id': gameSession.sessionId,
        'user_id': user?.id,
        'game': resolvedGameType,
        'session_data': sessionData,
        'started_at': DateTime.now().toIso8601String(),
        // Add additional columns for easier querying
        'difficulty': (gameSession is PuzzleGameSession) ? gameSession.gridSize : null,
        'puzzle_id': (gameSession is PuzzleGameSession) ? gameSession.currentPuzzleId : null,
        'grid_size': (gameSession is PuzzleGameSession) ? gameSession.gridSize : null,
      });

      print('SupabaseGameSessionTracking: Started tracking session ${gameSession.sessionId} for game $resolvedGameType');
      
      // Also record app usage
      await recordAppUsage(
        user: user,
        usageData: {
          'action': 'game_started',
          'game_type': resolvedGameType,
          'session_id': gameSession.sessionId,
        },
      );

    } catch (e) {
      print('Error starting game session tracking: $e');
      // Don't rethrow - we don't want to break the game if tracking fails
    }
  }

  @override
  Future<void> updateGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
    int? score,
    int? level,
    bool? isCompleted,
  }) async {
    try {
      // Prepare update data
      final updateData = <String, dynamic>{};
      
      if (sessionData != null) {
        updateData['session_data'] = sessionData;
      }
      
      // If we have individual fields, merge them into session_data
      if (score != null || level != null || isCompleted != null) {
        // First get current session_data
        final currentSession = await _client
            .from('game_sessions')
            .select('session_data')
            .eq('id', sessionId)
            .single();
            
        final currentData = (currentSession['session_data'] as Map<String, dynamic>?) ?? {};
        
        final mergedData = <String, dynamic>{
          ...currentData,
          ...?sessionData,
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        if (score != null) mergedData['current_score'] = score;
        if (level != null) mergedData['current_level'] = level;
        if (isCompleted != null) mergedData['completed'] = isCompleted;
        
        updateData['session_data'] = mergedData;
      }

      if (updateData.isNotEmpty) {
        await _client
            .from('game_sessions')
            .update(updateData)
            .eq('id', sessionId);
            
        print('SupabaseGameSessionTracking: Updated session $sessionId');
      }

    } catch (e) {
      print('Error updating game session: $e');
      // Don't rethrow - we don't want to break the game if tracking fails
    }
  }

  @override
  Future<void> endGameSession({
    required String sessionId,
    required GameResult gameResult,
    AppUser? user,
    Map<String, dynamic>? finalSessionData,
  }) async {
    try {
      // Prepare final session data
      final sessionData = <String, dynamic>{
        ...?finalSessionData,
        'ended_at': DateTime.now().toIso8601String(),
        'completed': gameResult.completed,
        'final_score': gameResult.finalScore,
        'max_level': gameResult.maxLevel,
        'play_time_seconds': gameResult.playTime.inSeconds,
        'play_time_minutes': gameResult.playTime.inMinutes,
      };

      // Update the session with final data
      await _client
          .from('game_sessions')
          .update({
            'session_data': sessionData,
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      print('SupabaseGameSessionTracking: Ended session $sessionId (completed: ${gameResult.completed}, score: ${gameResult.finalScore})');

      // Update user statistics if user is logged in
      if (user != null) {
        // Get the game type for this session
        final sessionInfo = await _client
            .from('game_sessions')
            .select('game')
            .eq('id', sessionId)
            .single();
            
        final gameType = sessionInfo['game'] as String;
        
        await updateUserGameStats(
          userId: user.id,
          gameType: gameType,
          additionalPlaytime: gameResult.playTime,
          puzzleCompleted: gameResult.completed,
        );
      }

      // Record app usage for session end
      await recordAppUsage(
        user: user,
        usageData: {
          'action': 'game_ended',
          'session_id': sessionId,
          'completed': gameResult.completed,
          'final_score': gameResult.finalScore,
          'play_time_minutes': gameResult.playTime.inMinutes,
        },
      );

    } catch (e) {
      print('Error ending game session: $e');
      // Don't rethrow - we don't want to break the game if tracking fails
    }
  }

  @override
  Future<void> pauseGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
  }) async {
    try {
      final updateData = <String, dynamic>{
        ...?sessionData,
        'paused_at': DateTime.now().toIso8601String(),
        'is_paused': true,
      };

      await updateGameSession(
        sessionId: sessionId,
        sessionData: updateData,
      );

      print('SupabaseGameSessionTracking: Paused session $sessionId');

    } catch (e) {
      print('Error pausing game session: $e');
    }
  }

  @override
  Future<void> resumeGameSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
  }) async {
    try {
      final updateData = <String, dynamic>{
        ...?sessionData,
        'resumed_at': DateTime.now().toIso8601String(),
        'is_paused': false,
      };

      await updateGameSession(
        sessionId: sessionId,
        sessionData: updateData,
      );

      print('SupabaseGameSessionTracking: Resumed session $sessionId');

    } catch (e) {
      print('Error resuming game session: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUserGameSessions({
    required String userId,
    String? gameType,
    int? limit,
    bool? completedOnly,
  }) async {
    try {
      // Build the query step by step without reassigning to same variable
      var baseQuery = _client
          .from('game_sessions')
          .select('*')
          .eq('user_id', userId);

      if (gameType != null) {
        baseQuery = baseQuery.eq('game', gameType);
      }

      if (completedOnly == true) {
        // Use a different approach for JSONB queries
        baseQuery = baseQuery.filter('session_data->completed', 'eq', true);
      }

      // Apply ordering and limit as final operations
      final orderedQuery = baseQuery.order('started_at', ascending: false);
      
      final finalQuery = limit != null 
        ? orderedQuery.limit(limit)
        : orderedQuery;

      final response = await finalQuery;
      return List<Map<String, dynamic>>.from(response);

    } catch (e) {
      print('Error getting user game sessions: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getUserGameStats({
    required String userId,
    String? gameType,
  }) async {
    try {
      var query = _client
          .from('game_stats')
          .select('*')
          .eq('user_id', userId);

      if (gameType != null) {
        query = query.eq('game', gameType);
      }

      final response = await query.maybeSingle();
      return response;

    } catch (e) {
      print('Error getting user game stats: $e');
      return null;
    }
  }

  @override
  Future<void> updateUserGameStats({
    required String userId,
    required String gameType,
    required Duration additionalPlaytime,
    bool? puzzleCompleted,
  }) async {
    try {
      // Get current stats or create new ones
      final currentStats = await getUserGameStats(
        userId: userId,
        gameType: gameType,
      );

      final currentPlaytime = (currentStats?['total_playtime'] as int?) ?? 0;
      final currentCompletedPuzzles = (currentStats?['completed_puzzles'] as int?) ?? 0;

      final newPlaytime = currentPlaytime + additionalPlaytime.inSeconds;
      final newCompletedPuzzles = currentCompletedPuzzles + (puzzleCompleted == true ? 1 : 0);

      // Upsert stats (insert or update)
      await _client.from('game_stats').upsert({
        'user_id': userId,
        'game': gameType,
        'total_playtime': newPlaytime,
        'completed_puzzles': newCompletedPuzzles,
        'last_played': DateTime.now().toIso8601String(),
      });

      print('SupabaseGameSessionTracking: Updated stats for user $userId, game $gameType');
      print('  - Total playtime: ${Duration(seconds: newPlaytime).inMinutes} minutes');
      print('  - Completed puzzles: $newCompletedPuzzles');

    } catch (e) {
      print('Error updating user game stats: $e');
      // Don't rethrow - we don't want to break the game if tracking fails
    }
  }

  @override
  Future<void> recordAppUsage({
    AppUser? user,
    String? deviceId,
    String? appVersion,
    Map<String, dynamic>? usageData,
  }) async {
    try {
      // Get device info if not provided
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      String? resolvedDeviceId = deviceId;
      Map<String, dynamic> deviceMetadata = {};
      
      if (Platform.isAndroid && resolvedDeviceId == null) {
        final androidInfo = await deviceInfo.androidInfo;
        resolvedDeviceId = androidInfo.id; // Android ID
        deviceMetadata = {
          'device_type': 'android',
          'device_model': androidInfo.model,
          'device_brand': androidInfo.brand,
          'android_version': androidInfo.version.release,
        };
      } else if (Platform.isIOS && resolvedDeviceId == null) {
        final iosInfo = await deviceInfo.iosInfo;
        resolvedDeviceId = iosInfo.identifierForVendor; // iOS Identifier for Vendor
        deviceMetadata = {
          'device_type': 'ios',
          'device_model': iosInfo.model,
          'device_name': iosInfo.name,
          'ios_version': iosInfo.systemVersion,
        };
      } else if (kIsWeb && resolvedDeviceId == null) {
        final webInfo = await deviceInfo.webBrowserInfo;
        resolvedDeviceId = webInfo.vendor; // Browser info as device ID
        deviceMetadata = {
          'device_type': 'web',
          'browser': webInfo.browserName.toString(),
          'platform': webInfo.platform.toString(),
        };
      }

      // Create usage record - we can log this even for anonymous users
      await _client.from('app_usage').insert({
        'user_id': user?.id,
        'device_id': resolvedDeviceId,
        'action': (usageData?['action'] as String?) ?? 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
        'app_version': appVersion ?? packageInfo.version,
        'platform': Platform.operatingSystem,
        'device_metadata': deviceMetadata,
        'usage_data': {
          'app_build': packageInfo.buildNumber,
          ...?usageData,
        },
      });

      print('SupabaseGameSessionTracking: Recorded app usage for user ${user?.id ?? "anonymous"}');

    } catch (e) {
      print('Error recording app usage: $e');
      // Don't rethrow - we don't want to break the app if tracking fails
    }
  }

  /// Helper method to determine game type from session
  String _determineGameType(GameSession gameSession) {
    if (gameSession is PuzzleGameSession) {
      return 'puzzle_nook'; // Our main puzzle game
    }
    
    // Default fallback
    return 'unknown';
  }
}
