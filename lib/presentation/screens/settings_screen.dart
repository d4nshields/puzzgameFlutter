import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/domain/services/settings_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';

/// Settings screen for the application
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsService _settingsService;
  int _difficulty = 2; // Default to medium difficulty
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _settingsService = serviceLocator<SettingsService>();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final difficulty = await _settingsService.getDifficulty();
      final soundEnabled = await _settingsService.getSoundEnabled();
      final vibrationEnabled = await _settingsService.getVibrationEnabled();
      
      setState(() {
        _difficulty = difficulty;
        _soundEnabled = soundEnabled;
        _vibrationEnabled = vibrationEnabled;
        _isLoading = false;
      });
    } catch (e) {
      // Handle error, use defaults
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    try {
      await _settingsService.setDifficulty(_difficulty);
      await _settingsService.setSoundEnabled(_soundEnabled);
      await _settingsService.setVibrationEnabled(_vibrationEnabled);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  String _getDifficultyDescription(int difficulty) {
    final gridSize = _settingsService.getGridSizeForDifficulty(difficulty);
    final pieceCount = _settingsService.getPieceCountForDifficulty(difficulty);
    return '${gridSize}x$gridSize grid ($pieceCount pieces)';
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Difficulty setting
            const Text(
              'Difficulty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            RadioListTile<int>(
              title: const Text('Easy'),
              subtitle: Text(_getDifficultyDescription(1)),
              value: 1,
              groupValue: _difficulty,
              onChanged: (value) {
                setState(() {
                  _difficulty = value!;
                });
              },
            ),
            RadioListTile<int>(
              title: const Text('Medium'),
              subtitle: Text(_getDifficultyDescription(2)),
              value: 2,
              groupValue: _difficulty,
              onChanged: (value) {
                setState(() {
                  _difficulty = value!;
                });
              },
            ),
            RadioListTile<int>(
              title: const Text('Hard'),
              subtitle: Text(_getDifficultyDescription(3)),
              value: 3,
              groupValue: _difficulty,
              onChanged: (value) {
                setState(() {
                  _difficulty = value!;
                });
              },
            ),
            
            const SizedBox(height: 20),
            
            // Sound settings
            SwitchListTile(
              title: const Text('Sound Effects'),
              value: _soundEnabled,
              onChanged: (value) {
                setState(() {
                  _soundEnabled = value;
                });
              },
            ),
            
            // Vibration settings
            SwitchListTile(
              title: const Text('Vibration'),
              value: _vibrationEnabled,
              onChanged: (value) {
                setState(() {
                  _vibrationEnabled = value;
                });
              },
            ),
            
            const Spacer(),
            
            // Save button
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
                onPressed: _saveSettings,
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
