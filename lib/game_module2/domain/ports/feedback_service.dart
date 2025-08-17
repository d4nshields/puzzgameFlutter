/// Port interface for providing user feedback (haptic, audio, visual).
/// 
/// This interface defines how the domain layer requests feedback,
/// hiding implementation details about platform-specific APIs.
abstract class FeedbackService {
  /// Provide haptic feedback
  void provideHaptic(HapticIntensity intensity);
  
  /// Play a sound effect
  void playSound(SoundType type);
  
  /// Show a visual hint or indicator
  void showVisualHint(VisualHint hint);
  
  /// Provide proximity-based feedback
  void provideProximityFeedback({
    required double intensity,
    required ProximityType type,
  });
  
  /// Start continuous feedback (e.g., for dragging)
  void startContinuousFeedback(FeedbackType type);
  
  /// Stop continuous feedback
  void stopContinuousFeedback();
  
  /// Check if haptic feedback is available on this device
  Future<bool> isHapticAvailable();
  
  /// Check if audio feedback is enabled
  bool isAudioEnabled();
  
  /// Set audio enabled state
  void setAudioEnabled(bool enabled);
}

/// Intensity levels for haptic feedback
enum HapticIntensity {
  /// Light tap (selection, hover)
  light,
  
  /// Medium tap (near correct position)
  medium,
  
  /// Heavy tap (piece snapped into place)
  heavy,
  
  /// Error vibration (invalid move)
  error,
}

/// Types of sound effects
enum SoundType {
  /// Piece picked up
  pickup,
  
  /// Piece being moved
  move,
  
  /// Piece near correct position
  near,
  
  /// Piece snapped into place
  snap,
  
  /// Puzzle completed
  complete,
  
  /// Invalid move attempted
  error,
  
  /// UI interaction (button press)
  uiTap,
  
  /// Hint requested
  hint,
}

/// Types of visual hints
class VisualHint {
  final HintType type;
  final String? pieceId;
  final Duration? duration;
  final Map<String, dynamic>? data;

  const VisualHint({
    required this.type,
    this.pieceId,
    this.duration,
    this.data,
  });
}

/// Types of visual hints
enum HintType {
  /// Highlight a specific piece
  highlightPiece,
  
  /// Show target position for a piece
  showTarget,
  
  /// Flash the correct position
  flashPosition,
  
  /// Show proximity indicator
  proximityGlow,
  
  /// Show completion animation
  completion,
}

/// Types of proximity feedback
enum ProximityType {
  /// Getting closer to correct position
  approaching,
  
  /// Getting farther from correct position
  receding,
  
  /// Very close to correct position
  veryClose,
  
  /// At snapping distance
  snapReady,
}

/// Types of continuous feedback
enum FeedbackType {
  /// Dragging a piece
  dragging,
  
  /// Piece is near correct position while dragging
  dragNear,
  
  /// Scanning for position (accessibility)
  scanning,
}
