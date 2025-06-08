// Audio Service Interface and Simple Implementation
// File: lib/core/domain/services/audio_service.dart

/// Abstract interface for game audio feedback
/// This allows us to defer audio implementation decisions while providing
/// a consistent interface for the game mechanics
abstract class AudioService {
  /// Initialize the audio service
  Future<void> initialize();
  
  /// Play sound when a piece is correctly placed
  Future<void> playPieceCorrect();
  
  /// Play sound when a piece placement is incorrect/rejected
  Future<void> playPieceIncorrect();
  
  /// Play sound when puzzle is completed
  Future<void> playPuzzleCompleted();
  
  /// Play ambient/background sound for piece selection
  Future<void> playPieceSelected();
  
  /// Play sound for UI interactions (buttons, menu items)
  Future<void> playUIClick();
  
  /// Set master volume (0.0 to 1.0)
  Future<void> setVolume(double volume);
  
  /// Enable/disable all audio
  Future<void> setEnabled(bool enabled);
  
  /// Clean up resources
  Future<void> dispose();
}
