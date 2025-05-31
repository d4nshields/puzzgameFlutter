# Puzzle Bazaar Game

A Flutter-based puzzle game application with a hexagonal architecture.

## Project Overview

Puzzle Bazaar is a puzzle game for Android (and eventually iOS) designed for offline entertainment. The game's core logic is being developed separately and will be integrated into this application as a module.

## Architecture

This project follows a hexagonal architecture pattern, which provides clear separation between:

- Core Logic (Domain)
- Application Layer (Use Cases)
- Infrastructure Layer (External Interfaces)
- Presentation Layer (UI)

### Project Structure

```
lib/
├── core/
│   ├── domain/        # Core entities and interfaces
│   ├── application/   # Use cases and business logic
│   └── infrastructure/ # External service implementations
├── game_module/       # Game logic implementation
└── presentation/      # UI components
    ├── screens/       # App screens
    └── widgets/       # Reusable UI components
```

## Dependencies

- **State Management**: Flutter Riverpod
- **Dependency Injection**: GetIt
- **Utility Libraries**:
  - Freezed (for immutable classes)
  - Equatable (for value comparisons)
  - Dartz (for functional programming)
  - UUID (for generating unique IDs)

## Testing

The project includes three levels of testing:

- **Unit Tests**: Testing individual components and classes
- **Widget Tests**: Testing UI components in isolation
- **Integration Tests**: Testing app flows and navigation

## Game Module Integration

The game is designed to be modular, with the core game logic developed separately and integrated into the app through well-defined interfaces. This allows for:

- Clear separation of concerns
- Independent development and testing
- Potential reuse in other applications

## Getting Started

1. Ensure you have Flutter installed and set up
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the application

## Development Guidelines

- Follow Flutter's style guide and best practices
- Use meaningful names for variables, methods, and classes
- Write comments for complex logic
- Write tests for all new features
- Keep UI and business logic separate
- Use the repository pattern for data access

## Future Improvements

- Add persistent storage for game state
- Implement analytics
- Add sound effects
- Add animations
- Support for multiple languages
- High score leaderboard
