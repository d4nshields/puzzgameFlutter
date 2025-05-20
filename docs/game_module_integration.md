# Game Module Integration Guide

This document outlines how to integrate an external game module with the Nook game application using the hexagonal architecture approach.

## Overview

The application is designed with a clear separation between the core application and the game module using a hexagonal architecture (also known as ports and adapters). This approach allows for:

1. Independent development of the game module
2. Clear interface boundaries
3. Easy testing and mocking
4. Flexibility in implementation details

## Integration Approaches

There are several ways to integrate your game module:

### 1. Direct Implementation

The simplest approach is to directly implement the interfaces defined in `lib/core/domain/game_module_interface.dart`. This is suitable if:

- The game module is developed alongside the main application
- There are no complex platform-specific dependencies
- You want to keep all code in a single project

#### Steps:
1. Update the existing `NookGameModule` class in `lib/game_module/nook_game_module.dart`
2. Implement all required methods with your game logic
3. No changes needed to the dependency injection setup

### 2. Local Package

For more separation, you can develop the game as a separate Dart package within the same repository:

#### Steps:
1. Create a new directory for your game module (e.g., `packages/nook_game_module`)
2. Initialize it as a Dart package
3. Implement the same interfaces defined in the main app
4. Update `pubspec.yaml` to include the local package:
   ```yaml
   dependencies:
     nook_game_module:
       path: ./packages/nook_game_module
   ```
5. Update the service locator to use your implementation

### 3. Published Package

If the game module should be reusable across multiple apps or developed by a separate team:

#### Steps:
1. Create a separate Dart package project
2. Publish it to a private or public repository
3. Add it to `pubspec.yaml`:
   ```yaml
   dependencies:
     nook_game_module: ^1.0.0
   ```
4. Update the service locator to use your implementation

## Interface Requirements

Your game module must implement these interfaces:

1. `GameModule` - The main entry point to your game
2. `GameSession` - Represents an active game session

The key methods to implement are:

```dart
// GameModule
Future<bool> initialize();
Future<GameSession> startGame({required int difficulty});
Future<GameSession?> resumeGame({required String sessionId});
String get version;

// GameSession
String get sessionId;
int get score;
int get level;
bool get isActive;
Future<void> pauseGame();
Future<void> resumeSession();
Future<GameResult> endGame();
Future<bool> saveGame();
```

## Dependency Injection

The application uses GetIt for dependency injection. To register your game module:

```dart
// In lib/core/infrastructure/service_locator.dart
void setupDependencies() {
  // Register your game module implementation
  serviceLocator.registerSingleton<GameModule>(YourGameModuleImplementation());
  
  // The rest remains the same
  serviceLocator.registerFactory(() => StartGameUseCase(serviceLocator()));
  serviceLocator.registerFactory(() => ResumeGameUseCase(serviceLocator()));
  serviceLocator.registerFactory(() => EndGameUseCase());
}
```

## UI Integration

The application already has a placeholder UI in `lib/presentation/screens/game_screen.dart`. When your game requires a custom UI:

1. Create your custom game UI components in `lib/presentation/widgets/`
2. Update `GameScreen` to use your custom widgets
3. Pass the `GameSession` object to your widgets to interact with the game

## Example: Basic Integration

Here's a minimal example of implementing the game module with custom game logic:

```dart
class MyNookGameModule implements GameModule {
  // Your game logic implementation
  final MyGameEngine _gameEngine = MyGameEngine();
  
  @override
  Future<bool> initialize() async {
    return await _gameEngine.initialize();
  }
  
  @override
  Future<GameSession> startGame({required int difficulty}) async {
    final gameState = await _gameEngine.createNewGame(difficulty: difficulty);
    return MyGameSession(gameState: gameState);
  }
  
  // Implement other methods...
}

class MyGameSession implements GameSession {
  final MyGameState _gameState;
  
  MyGameSession({required MyGameState gameState}) : _gameState = gameState;
  
  // Implement methods to interact with your game state
}
```

## Testing

When developing your game module, write tests for:

1. Unit tests for game logic
2. Integration tests for the module interface
3. Widget tests for any custom UI components

The main application already includes test files that can serve as examples.

## Best Practices

1. Keep the game logic and UI separate
2. Use the domain interfaces for communication
3. Handle errors gracefully and provide meaningful feedback
4. Consider performance implications, especially for mobile devices
5. Document your game module's specific requirements and behaviors
