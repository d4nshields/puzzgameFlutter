import 'package:shared_preferences/shared_preferences.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';

/// Implementation of SettingsService using SharedPreferences
class SharedPreferencesSettingsService implements SettingsService {
  static const String _difficultyKey = 'difficulty';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  
  @override
  Future<int> getDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_difficultyKey) ?? 2; // Default to medium
  }
  
  @override
  Future<void> setDifficulty(int difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_difficultyKey, difficulty);
  }
  
  @override
  Future<bool> getSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? true; // Default enabled
  }
  
  @override
  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }
  
  @override
  Future<bool> getVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationEnabledKey) ?? true; // Default enabled
  }
  
  @override
  Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, enabled);
  }
  
  @override
  int getGridSizeForDifficulty(int difficulty) {
    switch (difficulty) {
      case 1: // Easy
        return 8;
      case 2: // Medium  
        return 16;  // Changed from 12 to 16
      case 3: // Hard
        return 32;  // Changed from 16 to 32
      default:
        return 16; // Default to medium
    }
  }
  
  @override
  int getPieceCountForDifficulty(int difficulty) {
    final gridSize = getGridSizeForDifficulty(difficulty);
    return gridSize * gridSize;
  }
}
