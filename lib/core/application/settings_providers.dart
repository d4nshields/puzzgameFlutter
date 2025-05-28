// lib/core/application/settings_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/presentation/screens/game_screen.dart';

/// Provider for the settings service
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return serviceLocator<SettingsService>();
});

/// Provider for difficulty setting with reactive updates
final difficultyProvider = AsyncNotifierProvider<DifficultyNotifier, int>(() {
  return DifficultyNotifier();
});

/// Provider for sound enabled setting
final soundEnabledProvider = AsyncNotifierProvider<SoundEnabledNotifier, bool>(() {
  return SoundEnabledNotifier();
});

/// Provider for vibration enabled setting  
final vibrationEnabledProvider = AsyncNotifierProvider<VibrationEnabledNotifier, bool>(() {
  return VibrationEnabledNotifier();
});

/// Computed provider for grid size based on current difficulty
final gridSizeProvider = Provider<int>((ref) {
  final difficultyAsync = ref.watch(difficultyProvider);
  final settingsService = ref.watch(settingsServiceProvider);
  
  return difficultyAsync.when(
    data: (difficulty) => settingsService.getGridSizeForDifficulty(difficulty),
    loading: () => 16, // Default medium grid size
    error: (_, __) => 16,
  );
});

/// Computed provider for piece count based on current difficulty
final pieceCountProvider = Provider<int>((ref) {
  final difficultyAsync = ref.watch(difficultyProvider);
  final settingsService = ref.watch(settingsServiceProvider);
  
  return difficultyAsync.when(
    data: (difficulty) => settingsService.getPieceCountForDifficulty(difficulty),
    loading: () => 256, // Default medium piece count
    error: (_, __) => 256,
  );
});

/// Notifier class for difficulty setting
class DifficultyNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final settingsService = ref.watch(settingsServiceProvider);
    return await settingsService.getDifficulty();
  }
  
  /// Update difficulty and persist immediately
  Future<void> setDifficulty(int difficulty) async {
    // Set loading state
    state = const AsyncValue.loading();
    
    try {
      final settingsService = ref.read(settingsServiceProvider);
      await settingsService.setDifficulty(difficulty);
      
      // Update state with new value
      state = AsyncValue.data(difficulty);
      
      // Trigger game restart by invalidating game session
      ref.invalidate(gameSessionProvider);
      
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Notifier class for sound enabled setting
class SoundEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final settingsService = ref.watch(settingsServiceProvider);
    return await settingsService.getSoundEnabled();
  }
  
  /// Update sound setting and persist immediately
  Future<void> setSoundEnabled(bool enabled) async {
    state = const AsyncValue.loading();
    
    try {
      final settingsService = ref.read(settingsServiceProvider);
      await settingsService.setSoundEnabled(enabled);
      state = AsyncValue.data(enabled);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Notifier class for vibration enabled setting
class VibrationEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final settingsService = ref.watch(settingsServiceProvider);
    return await settingsService.getVibrationEnabled();
  }
  
  /// Update vibration setting and persist immediately
  Future<void> setVibrationEnabled(bool enabled) async {
    state = const AsyncValue.loading();
    
    try {
      final settingsService = ref.read(settingsServiceProvider);
      await settingsService.setVibrationEnabled(enabled);
      state = AsyncValue.data(enabled);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
