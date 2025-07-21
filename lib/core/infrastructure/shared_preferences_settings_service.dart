import 'package:shared_preferences/shared_preferences.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';

/// Implementation of SettingsService using SharedPreferences
class SharedPreferencesSettingsService implements SettingsService {
  static const String _difficultyKey = 'difficulty';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _easyPieceSortingKey = 'easy_piece_sorting_enabled';
  static const String _placementPrecisionKey = 'placement_precision';
  
  @override
  Future<int> getDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_difficultyKey) ?? 1; // Default to easy for onboarding
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
      case 2: // Medium (Hard in your assets)
        return 12;
      case 3: // Hard (Advanced in your assets)
        return 15;
      default:
        return 8; // Default to easy
    }
  }
  
  @override
  int getPieceCountForDifficulty(int difficulty) {
    final gridSize = getGridSizeForDifficulty(difficulty);
    return gridSize * gridSize;
  }
  
  @override
  Future<bool> getEasyPieceSortingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_easyPieceSortingKey) ?? true; // Default enabled for onboarding
  }
  
  @override
  Future<void> setEasyPieceSortingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_easyPieceSortingKey, enabled);
  }
  
  @override
  Future<double> getPlacementPrecision() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_placementPrecisionKey) ?? 0.0; // Default to drop anywhere
  }
  
  @override
  Future<void> setPlacementPrecision(double precision) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_placementPrecisionKey, precision.clamp(0.0, 1.0));
  }
  
  @override
  String getPlacementPrecisionDescription(double precision) {
    if (precision <= 0.1) {
      return 'Drop Anywhere (Very Easy)';
    } else if (precision <= 0.3) {
      return 'Forgiving (Easy)';
    } else if (precision <= 0.6) {
      return 'Moderate (Medium)';
    } else if (precision <= 0.9) {
      return 'Precise (Hard)';
    } else {
      return 'Exact Placement (Expert)';
    }
  }
}
