import 'package:get_it/get_it.dart';
import 'package:puzzgame_flutter/core/application/game_use_cases.dart';
import 'package:puzzgame_flutter/core/domain/game_module_interface.dart';
import 'package:puzzgame_flutter/game_module/nook_game_module.dart';

/// Service locator singleton
final serviceLocator = GetIt.instance;

/// Sets up the dependency injection
void setupDependencies() {
  // Register Game Module
  serviceLocator.registerSingleton<GameModule>(NookGameModule());
  
  // Register Use Cases
  serviceLocator.registerFactory(() => StartGameUseCase(serviceLocator()));
  serviceLocator.registerFactory(() => ResumeGameUseCase(serviceLocator()));
  serviceLocator.registerFactory(() => EndGameUseCase());
}
