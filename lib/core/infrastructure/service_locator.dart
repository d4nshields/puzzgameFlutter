import 'package:get_it/get_it.dart';
import 'package:puzzgame_flutter/core/application/game_use_cases.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/domain/services/audio_service.dart';
import 'package:puzzgame_flutter/core/domain/services/zoom_service.dart';
import 'package:puzzgame_flutter/core/domain/services/error_reporting_service.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/core/domain/services/game_session_tracking_service.dart';
import 'package:puzzgame_flutter/core/domain/services/achievement_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/shared_preferences_settings_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/system_audio_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/sentry_error_reporting_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_auth_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_game_session_tracking_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_achievement_service.dart';

import 'package:puzzgame_flutter/game_module2/puzzle_game_module2.dart';

/// Service locator singleton
final serviceLocator = GetIt.instance;

/// Sets up the dependency injection
void setupDependencies() {
  // Register Error Reporting Service
  serviceLocator.registerSingleton<ErrorReportingService>(SentryErrorReportingService());
  
  // Register Auth Service
  serviceLocator.registerSingleton<AuthService>(SupabaseAuthService());
  
  // Register Game Session Tracking Service
  serviceLocator.registerSingleton<GameSessionTrackingService>(SupabaseGameSessionTrackingService());
  
  // Register Achievement and Sharing Service
  final achievementService = SupabaseAchievementService();
  serviceLocator.registerSingleton<AchievementService>(achievementService);
  serviceLocator.registerSingleton<SharingTrackingService>(achievementService);
  
  // Register Settings Service
  serviceLocator.registerSingleton<SettingsService>(SharedPreferencesSettingsService());
  
  // Register Audio Service
  serviceLocator.registerSingleton<AudioService>(SystemAudioService());
  
  // Register Zoom Service Factory (each game session gets its own zoom state)
  serviceLocator.registerFactory<ZoomService>(() => DefaultZoomService());
  
  // Register Game Module - using PuzzleGameModule for jigsaw puzzle gameplay
  serviceLocator.registerSingleton<GameModule>(PuzzleGameModule2());
  
  // Register Use Cases
  serviceLocator.registerFactory(() => StartGameUseCase(serviceLocator()));
  serviceLocator.registerFactory(() => ResumeGameUseCase(serviceLocator()));
  serviceLocator.registerFactory(EndGameUseCase.new);
}
