import 'package:flutter/services.dart';
import '../../domain/ports/feedback_service.dart';
import '../../../core/domain/services/audio_service.dart';
import '../../../core/infrastructure/service_locator.dart';

/// Flutter implementation of the FeedbackService port.
/// 
/// This adapter provides haptic, audio, and visual feedback using
/// Flutter's platform APIs and the existing audio service.
class FlutterFeedbackAdapter implements FeedbackService {
  late final AudioService _audioService;
  bool _isInitialized = false;
  bool _audioEnabled = true;
  // ignore: unused_field
  bool _continuousFeedbackActive = false;
  // ignore: unused_field
  FeedbackType? _currentFeedbackType;
  
  // Track last feedback time to throttle
  DateTime? _lastHapticTime;
  static const _hapticThrottleMs = 50;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _audioService = serviceLocator<AudioService>();
      await _audioService.initialize();
      _isInitialized = true;
    } catch (e) {
      print('FlutterFeedbackAdapter: Failed to initialize audio service: $e');
      // Continue without audio rather than failing completely
      _audioEnabled = false;
      _isInitialized = true;
    }
  }

  @override
  void provideHaptic(HapticIntensity intensity) {
    // Throttle haptic feedback
    final now = DateTime.now();
    if (_lastHapticTime != null) {
      final elapsed = now.difference(_lastHapticTime!).inMilliseconds;
      if (elapsed < _hapticThrottleMs) return;
    }
    _lastHapticTime = now;
    
    // Provide haptic feedback based on intensity
    switch (intensity) {
      case HapticIntensity.light:
        HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticIntensity.error:
        HapticFeedback.vibrate();
        break;
    }
  }

  @override
  void playSound(SoundType type) {
    if (!_audioEnabled || !_isInitialized) return;
    
    // Map sound types to audio service methods
    switch (type) {
      case SoundType.pickup:
        _audioService.playPieceSelected();
        break;
      case SoundType.move:
        // Use UI click for move sound
        _audioService.playUIClick();
        break;
      case SoundType.near:
        // Use a soft sound for proximity
        _audioService.playUIClick();
        break;
      case SoundType.snap:
        _audioService.playPieceCorrect();
        break;
      case SoundType.complete:
        _audioService.playPuzzleCompleted();
        break;
      case SoundType.error:
        _audioService.playPieceIncorrect();
        break;
      case SoundType.uiTap:
        _audioService.playUIClick();
        break;
      case SoundType.hint:
        _audioService.playUIClick();
        break;
    }
  }

  @override
  void showVisualHint(VisualHint hint) {
    // Visual hints would be handled by the UI layer
    // This is a notification that the UI should show something
    // For now, we'll just log it
    print('Visual hint requested: ${hint.type} for piece ${hint.pieceId}');
    
    // In a complete implementation, this would emit an event
    // that the UI layer listens to
  }

  @override
  void provideProximityFeedback({
    required double intensity,
    required ProximityType type,
  }) {
    // Provide feedback based on proximity
    if (intensity > 0.8) {
      // Very close - strong feedback
      provideHaptic(HapticIntensity.medium);
    } else if (intensity > 0.5) {
      // Getting closer - light feedback
      provideHaptic(HapticIntensity.light);
    }
    
    // Audio feedback for very close
    if (type == ProximityType.snapReady && _audioEnabled) {
      _audioService.playUIClick();
    }
  }

  @override
  void startContinuousFeedback(FeedbackType type) {
    _continuousFeedbackActive = true;
    _currentFeedbackType = type;
    
    // Start appropriate continuous feedback
    switch (type) {
      case FeedbackType.dragging:
        // Light haptic on start
        provideHaptic(HapticIntensity.light);
        break;
      case FeedbackType.dragNear:
        // Medium haptic when near
        provideHaptic(HapticIntensity.medium);
        break;
      case FeedbackType.scanning:
        // Periodic haptic for scanning
        _startScanningFeedback();
        break;
    }
  }

  @override
  void stopContinuousFeedback() {
    _continuousFeedbackActive = false;
    _currentFeedbackType = null;
    _stopScanningFeedback();
  }

  @override
  Future<bool> isHapticAvailable() async {
    // On mobile platforms, haptic is generally available
    // This could be enhanced with platform-specific checks
    return true;
  }

  @override
  bool isAudioEnabled() => _audioEnabled;

  @override
  void setAudioEnabled(bool enabled) {
    _audioEnabled = enabled;
    if (_audioEnabled && _isInitialized) {
      _audioService.initialize();
    }
  }

  // Private helper methods
  
  void _startScanningFeedback() {
    // This would start a periodic timer for scanning feedback
    // For simplicity, we'll just provide initial feedback
    provideHaptic(HapticIntensity.light);
  }
  
  void _stopScanningFeedback() {
    // Stop any periodic timers
  }
}
