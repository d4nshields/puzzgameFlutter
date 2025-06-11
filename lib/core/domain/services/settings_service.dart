/// Settings service for managing game settings
abstract class SettingsService {
  /// Get the current difficulty level (1=Easy, 2=Medium, 3=Hard)
  Future<int> getDifficulty();
  
  /// Set the difficulty level
  Future<void> setDifficulty(int difficulty);
  
  /// Get sound enabled setting
  Future<bool> getSoundEnabled();
  
  /// Set sound enabled setting
  Future<void> setSoundEnabled(bool enabled);
  
  /// Get vibration enabled setting
  Future<bool> getVibrationEnabled();
  
  /// Set vibration enabled setting
  Future<void> setVibrationEnabled(bool enabled);
  
  /// Get grid size based on difficulty
  int getGridSizeForDifficulty(int difficulty);
  
  /// Get piece count for difficulty
  int getPieceCountForDifficulty(int difficulty);
  
  /// Get easy piece sorting enabled setting
  Future<bool> getEasyPieceSortingEnabled();
  
  /// Set easy piece sorting enabled setting
  Future<void> setEasyPieceSortingEnabled(bool enabled);
}
