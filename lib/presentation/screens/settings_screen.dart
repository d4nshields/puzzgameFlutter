import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/application/settings_providers.dart';

/// Settings screen for the application - now fully reactive
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _getDifficultyDescription(WidgetRef ref, int difficulty) {
    final settingsService = ref.read(settingsServiceProvider);
    final gridSize = settingsService.getGridSizeForDifficulty(difficulty);
    final pieceCount = settingsService.getPieceCountForDifficulty(difficulty);
    return '${gridSize}×$gridSize grid ($pieceCount pieces)';
  }

  String _getPlacementPrecisionHelp(double precision) {
    if (precision <= 0.1) {
      return 'Pieces snap to correct position when dropped anywhere on the puzzle.';
    } else if (precision <= 0.3) {
      return 'Pieces need to be dropped roughly in the right area.';
    } else if (precision <= 0.6) {
      return 'Pieces must be placed fairly close to their correct position.';
    } else if (precision <= 0.9) {
      return 'Pieces require precise placement near their exact location.';
    } else {
      return 'Pieces must be dropped exactly over their correct position.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all settings providers
    final difficultyAsync = ref.watch(difficultyProvider);
    final soundEnabledAsync = ref.watch(soundEnabledProvider);
    final vibrationEnabledAsync = ref.watch(vibrationEnabledProvider);
    final easyPieceSortingAsync = ref.watch(easyPieceSortingProvider);
    final placementPrecisionAsync = ref.watch(placementPrecisionProvider);

    // Show loading state if any setting is loading
    final isLoading = difficultyAsync.isLoading || 
                     soundEnabledAsync.isLoading || 
                     vibrationEnabledAsync.isLoading ||
                     easyPieceSortingAsync.isLoading ||
                     placementPrecisionAsync.isLoading;

    if (isLoading && !difficultyAsync.hasValue && !soundEnabledAsync.hasValue && !vibrationEnabledAsync.hasValue && !easyPieceSortingAsync.hasValue && !placementPrecisionAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle error states
    final hasError = difficultyAsync.hasError || 
                    soundEnabledAsync.hasError || 
                    vibrationEnabledAsync.hasError ||
                    easyPieceSortingAsync.hasError ||
                    placementPrecisionAsync.hasError;

    if (hasError && !difficultyAsync.hasValue && !soundEnabledAsync.hasValue && !vibrationEnabledAsync.hasValue && !easyPieceSortingAsync.hasValue && !placementPrecisionAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load settings'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Refresh all providers
                  ref.invalidate(difficultyProvider);
                  ref.invalidate(soundEnabledProvider);
                  ref.invalidate(vibrationEnabledProvider);
                  ref.invalidate(easyPieceSortingProvider);
                  ref.invalidate(placementPrecisionProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Get the current values
    final difficulty = difficultyAsync.value ?? 2;
    final soundEnabled = soundEnabledAsync.value ?? true;
    final vibrationEnabled = vibrationEnabledAsync.value ?? true;
    final easyPieceSortingEnabled = easyPieceSortingAsync.value ?? false;
    final placementPrecision = placementPrecisionAsync.value ?? 0.0;
    final settingsService = ref.read(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // Add a visual indicator when changes are auto-saving
        actions: [
          if (difficultyAsync.isLoading || soundEnabledAsync.isLoading || vibrationEnabledAsync.isLoading || easyPieceSortingAsync.isLoading || placementPrecisionAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
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
            const SizedBox(height: 8),
            
            // Auto-save indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Settings auto-save',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  RadioListTile<int>(
                    title: const Text('Easy'),
                    subtitle: Text(_getDifficultyDescription(ref, 1)),
                    value: 1,
                    groupValue: difficulty,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      if (value != null) {
                        // Immediately save the new difficulty
                        ref.read(difficultyProvider.notifier).setDifficulty(value);
                        
                        // Show feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Difficulty changed! Game will restart.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<int>(
                    title: const Text('Medium'),
                    subtitle: Text(_getDifficultyDescription(ref, 2)),
                    value: 2,
                    groupValue: difficulty,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(difficultyProvider.notifier).setDifficulty(value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Difficulty changed! Game will restart.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<int>(
                    title: const Text('Hard'),
                    subtitle: Text(_getDifficultyDescription(ref, 3)),
                    value: 3,
                    groupValue: difficulty,
                    activeColor: Colors.red,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(difficultyProvider.notifier).setDifficulty(value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Difficulty changed! Game will restart.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sound settings - now reactive
            SwitchListTile(
              title: const Text('Sound Effects'),
              subtitle: const Text('Enable audio feedback'),
              value: soundEnabled,
              onChanged: (value) {
                // Immediately save the new setting
                ref.read(soundEnabledProvider.notifier).setSoundEnabled(value);
              },
            ),

            // Vibration settings - now reactive
            SwitchListTile(
              title: const Text('Vibration'),
              subtitle: const Text('Enable haptic feedback'),
              value: vibrationEnabled,
              onChanged: (value) {
                // Immediately save the new setting
                ref.read(vibrationEnabledProvider.notifier).setVibrationEnabled(value);
              },
            ),

            // Easy Piece Sorting settings - new feature
            SwitchListTile(
              title: const Text('Easy Piece Sorting'),
              subtitle: const Text('Show corner and edge pieces first in tray'),
              value: easyPieceSortingEnabled,
              onChanged: (value) {
                // Immediately save the new setting
                ref.read(easyPieceSortingProvider.notifier).setEasyPieceSortingEnabled(value);
              },
            ),

            const SizedBox(height: 20),

            // Placement Precision Settings
            const Text(
              'Piece Placement Difficulty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purple[200]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.purple[50],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.precision_manufacturing, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        settingsService.getPlacementPrecisionDescription(placementPrecision),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.games, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text('Easy', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: placementPrecision,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          activeColor: Colors.purple,
                          onChanged: (value) {
                            ref.read(placementPrecisionProvider.notifier).setPlacementPrecision(value);
                          },
                        ),
                      ),
                      const Icon(Icons.my_location, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      const Text('Expert', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPlacementPrecisionHelp(placementPrecision),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Keep the save button for the "elevator door close" effect 😉
            Center(
              child: Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // This button doesn't actually do anything anymore,
                      // but users might expect it, like the elevator close door button!
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings are already saved automatically!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text('Save Settings'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '✨ All changes are saved automatically',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
