import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzgame_flutter/core/application/settings_providers.dart';
import 'package:puzzgame_flutter/presentation/widgets/user_profile_widget.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

/// Settings screen for the application - now fully reactive with cozy theme
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _getDifficultyDescription(WidgetRef ref, int difficulty) {
    final settingsService = ref.read(settingsServiceProvider);
    final gridSize = settingsService.getGridSizeForDifficulty(difficulty);
    final pieceCount = settingsService.getPieceCountForDifficulty(difficulty);
    return '${gridSize}×$gridSize grid ($pieceCount pieces)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all settings providers
    final difficultyAsync = ref.watch(difficultyProvider);
    final soundEnabledAsync = ref.watch(soundEnabledProvider);
    final vibrationEnabledAsync = ref.watch(vibrationEnabledProvider);
    final easyPieceSortingAsync = ref.watch(easyPieceSortingProvider);

    // Show loading state if any setting is loading
    final isLoading = difficultyAsync.isLoading || 
                     soundEnabledAsync.isLoading || 
                     vibrationEnabledAsync.isLoading ||
                     easyPieceSortingAsync.isLoading;

    if (isLoading && !difficultyAsync.hasValue && !soundEnabledAsync.hasValue && !vibrationEnabledAsync.hasValue && !easyPieceSortingAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: CozyPuzzleTheme.goldenSandbar,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading settings...',
                style: CozyPuzzleTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Handle error states
    final hasError = difficultyAsync.hasError || 
                    soundEnabledAsync.hasError || 
                    vibrationEnabledAsync.hasError ||
                    easyPieceSortingAsync.hasError;

    if (hasError && !difficultyAsync.hasValue && !soundEnabledAsync.hasValue && !vibrationEnabledAsync.hasValue && !easyPieceSortingAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: Center(
          child: CozyPuzzleTheme.createThemedContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline, 
                  color: CozyPuzzleTheme.coralBlush, 
                  size: 48
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load settings',
                  style: CozyPuzzleTheme.headingSmall,
                ),
                const SizedBox(height: 16),
                CozyPuzzleTheme.createThemedButton(
                  text: 'Retry',
                  onPressed: () {
                    // Refresh all providers
                    ref.invalidate(difficultyProvider);
                    ref.invalidate(soundEnabledProvider);
                    ref.invalidate(vibrationEnabledProvider);
                    ref.invalidate(easyPieceSortingProvider);
                  },
                  isPrimary: true,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Get the current values
    final difficulty = difficultyAsync.value ?? 2;
    final soundEnabled = soundEnabledAsync.value ?? true;
    final vibrationEnabled = vibrationEnabledAsync.value ?? true;
    final easyPieceSortingEnabled = easyPieceSortingAsync.value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // Add a visual indicator when changes are auto-saving
        actions: [
          if (difficultyAsync.isLoading || soundEnabledAsync.isLoading || vibrationEnabledAsync.isLoading || easyPieceSortingAsync.isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CozyPuzzleTheme.goldenSandbar,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CozyPuzzleTheme.linenWhite,
              CozyPuzzleTheme.warmSand.withOpacity(0.2),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile section
              const UserProfileWidget(),
              const SizedBox(height: 32),
              
              // Game Settings Header
              Text(
                'Game Settings',
                style: CozyPuzzleTheme.headingMedium,
              ),
              const SizedBox(height: 8),
              
              // Auto-save indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: CozyPuzzleTheme.seafoamMist.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CozyPuzzleTheme.seafoamMist),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome, 
                      size: 16, 
                      color: CozyPuzzleTheme.deepSlate,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Settings auto-save',
                      style: CozyPuzzleTheme.labelLarge.copyWith(
                        color: CozyPuzzleTheme.deepSlate,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Difficulty setting
              Text(
                'Puzzle Difficulty',
                style: CozyPuzzleTheme.headingSmall,
              ),
              const SizedBox(height: 12),

              CozyPuzzleTheme.createThemedContainer(
                child: Column(
                  children: [
                    _buildDifficultyOption(
                      ref: ref,
                      title: 'Easy',
                      subtitle: _getDifficultyDescription(ref, 1),
                      value: 1,
                      groupValue: difficulty,
                      color: CozyPuzzleTheme.seafoamMist,
                      icon: Icons.sentiment_satisfied,
                    ),
                    Divider(color: CozyPuzzleTheme.weatheredDriftwood.withOpacity(0.5)),
                    _buildDifficultyOption(
                      ref: ref,
                      title: 'Medium',
                      subtitle: _getDifficultyDescription(ref, 2),
                      value: 2,
                      groupValue: difficulty,
                      color: CozyPuzzleTheme.goldenSandbar,
                      icon: Icons.sentiment_neutral,
                    ),
                    Divider(color: CozyPuzzleTheme.weatheredDriftwood.withOpacity(0.5)),
                    _buildDifficultyOption(
                      ref: ref,
                      title: 'Hard',
                      subtitle: _getDifficultyDescription(ref, 3),
                      value: 3,
                      groupValue: difficulty,
                      color: CozyPuzzleTheme.coralBlush,
                      icon: Icons.sentiment_very_satisfied,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Audio & Feedback Settings
              Text(
                'Audio & Feedback',
                style: CozyPuzzleTheme.headingSmall,
              ),
              const SizedBox(height: 12),
              
              CozyPuzzleTheme.createThemedContainer(
                child: Column(
                  children: [
                    _buildSwitchTile(
                      title: 'Sound Effects',
                      subtitle: 'Enable audio feedback for interactions',
                      value: soundEnabled,
                      icon: Icons.volume_up,
                      onChanged: (value) {
                        ref.read(soundEnabledProvider.notifier).setSoundEnabled(value);
                      },
                    ),
                    Divider(color: CozyPuzzleTheme.weatheredDriftwood.withOpacity(0.5)),
                    _buildSwitchTile(
                      title: 'Vibration',
                      subtitle: 'Enable haptic feedback for actions',
                      value: vibrationEnabled,
                      icon: Icons.vibration,
                      onChanged: (value) {
                        ref.read(vibrationEnabledProvider.notifier).setVibrationEnabled(value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Gameplay Assistance
              Text(
                'Gameplay Assistance',
                style: CozyPuzzleTheme.headingSmall,
              ),
              const SizedBox(height: 12),
              
              CozyPuzzleTheme.createThemedContainer(
                child: _buildSwitchTile(
                  title: 'Easy Piece Sorting',
                  subtitle: 'Show corner and edge pieces first in the tray',
                  value: easyPieceSortingEnabled,
                  icon: Icons.sort,
                  onChanged: (value) {
                    ref.read(easyPieceSortingProvider.notifier).setEasyPieceSortingEnabled(value);
                  },
                ),
              ),

              const SizedBox(height: 40),

              // Decorative save button (for familiarity)
              Center(
                child: Column(
                  children: [
                    CozyPuzzleTheme.createThemedButton(
                      text: 'Save Settings',
                      onPressed: () {
                        // This button doesn't actually do anything anymore,
                        // but users might expect it!
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Settings are already saved automatically!',
                              style: CozyPuzzleTheme.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: CozyPuzzleTheme.seafoamMist,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      icon: Icons.save,
                      isPrimary: true,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '✨ All changes are saved automatically',
                      style: CozyPuzzleTheme.labelLarge.copyWith(
                        color: CozyPuzzleTheme.seafoamMist,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyOption({
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required int value,
    required int groupValue,
    required Color color,
    required IconData icon,
  }) {
    return RadioListTile<int>(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      title: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: CozyPuzzleTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Text(
          subtitle,
          style: CozyPuzzleTheme.bodyMedium,
        ),
      ),
      value: value,
      groupValue: groupValue,
      activeColor: color,
      onChanged: (selectedValue) {
        if (selectedValue != null) {
          ref.read(difficultyProvider.notifier).setDifficulty(selectedValue);
          
          // Show contextual feedback
          final context = ref.context;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Difficulty changed to $title! Game will restart.',
                style: CozyPuzzleTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: color,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      title: Row(
        children: [
          Icon(
            icon, 
            color: CozyPuzzleTheme.stoneGray, 
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: CozyPuzzleTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Text(
          subtitle,
          style: CozyPuzzleTheme.bodyMedium,
        ),
      ),
      value: value,
      activeColor: CozyPuzzleTheme.goldenSandbar,
      activeTrackColor: CozyPuzzleTheme.goldenSandbar.withOpacity(0.3),
      inactiveThumbColor: CozyPuzzleTheme.weatheredDriftwood,
      inactiveTrackColor: CozyPuzzleTheme.weatheredDriftwood.withOpacity(0.3),
      onChanged: onChanged,
    );
  }
}
