// Complete System Audio Service Implementation
// File: lib/core/infrastructure/system_audio_service.dart

import 'package:flutter/services.dart';
import 'package:puzzgame_flutter/core/domain/services/audio_service.dart';

/// Complete implementation using Flutter's built-in SystemSound
/// This provides immediate audio feedback with zero dependencies
class SystemAudioService implements AudioService {
  bool _enabled = true;
  double _volume = 1.0;
  bool _initialized = false;
  
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Test if system sounds are available
      await SystemSound.play(SystemSoundType.click);
      _initialized = true;
      print('SystemAudioService: Initialized successfully');
    } catch (e) {
      print('SystemAudioService: Failed to initialize - $e');
      _initialized = false;
    }
  }
  
  @override
  Future<void> playPieceCorrect() async {
    if (!_enabled || !_initialized) return;
    
    try {
      // Use click sound for positive feedback
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      print('SystemAudioService: Failed to play piece correct sound - $e');
    }
  }
  
  @override
  Future<void> playPieceIncorrect() async {
    if (!_enabled || !_initialized) return;
    
    try {
      // Use alert sound for negative feedback
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      print('SystemAudioService: Failed to play piece incorrect sound - $e');
    }
  }
  
  @override
  Future<void> playPuzzleCompleted() async {
    if (!_enabled || !_initialized) return;
    
    try {
      // Play a sequence of clicks for celebration
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 150));
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 150));
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      print('SystemAudioService: Failed to play puzzle completed sound - $e');
    }
  }
  
  @override
  Future<void> playPieceSelected() async {
    if (!_enabled || !_initialized) return;
    
    try {
      // Subtle click for piece selection
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      print('SystemAudioService: Failed to play piece selected sound - $e');
    }
  }
  
  @override
  Future<void> playUIClick() async {
    if (!_enabled || !_initialized) return;
    
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      print('SystemAudioService: Failed to play UI click sound - $e');
    }
  }
  
  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    // System sounds don't support volume control directly,
    // but we store the preference for future implementations
    print('SystemAudioService: Volume set to ${(_volume * 100).round()}%');
  }
  
  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    print('SystemAudioService: Audio ${enabled ? 'enabled' : 'disabled'}');
  }
  
  @override
  Future<void> dispose() async {
    // No cleanup needed for system sounds
    _initialized = false;
    print('SystemAudioService: Disposed');
  }
  
  /// Get current audio settings for debugging
  Map<String, dynamic> get debugInfo => {
    'enabled': _enabled,
    'volume': _volume,
    'initialized': _initialized,
  };
}
