import 'package:get_it/get_it.dart';
import 'package:puzzgame_flutter/core/application/game_use_cases.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/shared_preferences_settings_service.dart';
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';

/// Service locator singleton
final serviceLocator = GetIt.instance;

/// Sets up the dependency injection
void setupDependencies() {
  // Register Settings Service
  serviceLocator.registerSingleton<SettingsService>(SharedPreferencesSettingsService());
  
  // Register Game Module - using PuzzleGameModule for jigsaw puzzle gameplay
  serviceLocator.registerSingleton<GameModule>(PuzzleGameModule());
  
  // Register Use Cases
  serviceLocator.registerFactory(() => StartGameUseCase(serviceLocator()));
  serviceLocator.registerFactory(() => ResumeGameUseCase(serviceLocator()));
  serviceLocator.registerFactory(EndGameUseCase.new);
}
