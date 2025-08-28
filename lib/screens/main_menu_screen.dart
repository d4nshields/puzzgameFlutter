import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/game_module2.dart';
import 'package:puzzgame_flutter/game_module2/infrastructure/feature_flags.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({Key? key}) : super(key: key);
  
  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Beige background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo/Title
                const Icon(
                  Icons.extension,
                  size: 120,
                  color: Color(0xFF8B4513), // Saddle brown
                ),
                const SizedBox(height: 24),
                Text(
                  'Puzzle Nook',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: const Color(0xFF5D4037), // Brown
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A cozy place for puzzles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF795548), // Light brown
                  ),
                ),
                const SizedBox(height: 48),
                
                // Play Button
                _buildMenuButton(
                  context: context,
                  label: 'Play Sample Puzzle',
                  icon: Icons.play_arrow,
                  color: const Color(0xFF4CAF50), // Green
                  onPressed: _isLoading ? null : _startSamplePuzzle,
                ),
                const SizedBox(height: 16),
                
                // Puzzle Library Button
                _buildMenuButton(
                  context: context,
                  label: 'Puzzle Library',
                  icon: Icons.grid_view,
                  color: const Color(0xFF2196F3), // Blue
                  onPressed: _isLoading ? null : _openPuzzleLibrary,
                ),
                const SizedBox(height: 16),
                
                // Settings Button
                _buildMenuButton(
                  context: context,
                  label: 'Settings',
                  icon: Icons.settings,
                  color: const Color(0xFF9E9E9E), // Grey
                  onPressed: _isLoading ? null : _openSettings,
                ),
                const SizedBox(height: 16),
                
                // Debug Info Button (only in debug mode)
                if (const bool.fromEnvironment('dart.vm.product') == false)
                  _buildMenuButton(
                    context: context,
                    label: 'Debug Info',
                    icon: Icons.bug_report,
                    color: const Color(0xFFFF9800), // Orange
                    onPressed: _isLoading ? null : _showDebugInfo,
                  ),
                
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 32.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMenuButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 280,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }
  
  Future<void> _startSamplePuzzle() async {
    setState(() => _isLoading = true);
    
    try {
      // Start the sample puzzle
      await PuzzleGameModule2.instance.startGame(
        difficulty: 1,
        puzzleId: 'sample_puzzle_01',
        forceNewGame: true,
      );
      
      // Navigate to puzzle screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/puzzle');
      }
    } catch (e) {
      print('Error starting puzzle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start puzzle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _openPuzzleLibrary() {
    // TODO: Navigate to puzzle library screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Puzzle Library coming soon!'),
      ),
    );
  }
  
  void _openSettings() {
    // TODO: Navigate to settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings coming soon!'),
      ),
    );
  }
  
  Future<void> _showDebugInfo() async {
    final featureFlags = FeatureFlagService.instance;
    
    final flags = {
      'sample_puzzle': await featureFlags.isEnabled('sample_puzzle'),
      'magnetic_gestures': await featureFlags.isEnabled('magnetic_gestures'),
      'enhanced_feedback': await featureFlags.isEnabled('enhanced_feedback'),
      'smooth_animations': await featureFlags.isEnabled('smooth_animations'),
    };
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Debug Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Environment: ${featureFlags.currentEnvironment}'),
              Text('Flag Source: ${featureFlags.lastSource}'),
              const SizedBox(height: 16),
              const Text('Feature Flags:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...flags.entries.map((e) => Text('${e.key}: ${e.value}')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Force refresh flags from database
                await featureFlags.refresh();
                Navigator.of(context).pop();
                _showDebugInfo(); // Show updated info
              },
              child: const Text('Refresh Flags'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}