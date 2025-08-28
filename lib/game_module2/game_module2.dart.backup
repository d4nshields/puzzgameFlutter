import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/infrastructure/feature_flags.dart';
import 'package:puzzgame_flutter/game_module2/infrastructure/puzzle_asset_manager.dart';
import 'package:puzzgame_flutter/game_module2/infrastructure/system_audio_service.dart';
import 'package:puzzgame_flutter/game_module2/application/workspace_controller.dart';
import 'package:puzzgame_flutter/game_module2/application/interaction_integration.dart';
import 'package:puzzgame_flutter/game_module2/presentation/workspace_widget.dart';

/// Main entry point for the puzzle game module using hexagonal architecture
class PuzzleGameModule2 {
  static final PuzzleGameModule2 instance = PuzzleGameModule2._();
  
  // Infrastructure layer
  late final PuzzleAssetManager _assetManager;
  late final SystemAudioService _audioService;
  late final FeatureFlagService _featureFlags;
  
  // Application layer
  WorkspaceController? _controller;
  InteractionIntegration? _interactionIntegration;
  
  // State
  bool _initialized = false;
  bool _gameStarted = false;
  
  PuzzleGameModule2._();
  
  /// Initialize the game module
  Future<void> initialize() async {
    if (_initialized) {
      print('PuzzleGameModule2: Already initialized');
      return;
    }
    
    print('PuzzleGameModule2: Initializing with hexagonal architecture...');
    
    // Get feature flag service instance (already initialized in main.dart)
    _featureFlags = FeatureFlagService.instance;
    
    // Initialize infrastructure layer
    _assetManager = PuzzleAssetManager();
    await _assetManager.initialize();
    
    _audioService = SystemAudioService();
    await _audioService.initialize();
    
    _initialized = true;
    print('PuzzleGameModule2: Initialization complete');
  }
  
  /// Start a new game with the specified difficulty
  Future<void> startGame({
    required int difficulty,
    String? puzzleId,
    bool forceNewGame = false,
  }) async {
    if (!_initialized) {
      throw StateError('PuzzleGameModule2 not initialized');
    }
    
    // Check if we should show sample puzzle
    final showSamplePuzzle = await _featureFlags.isEnabled('sample_puzzle');
    print('PuzzleGameModule2: sample_puzzle flag = $showSamplePuzzle');
    
    // If sample puzzle is disabled and no specific puzzle is selected, 
    // don't auto-start
    if (!showSamplePuzzle && puzzleId == null) {
      print('PuzzleGameModule2: Sample puzzle disabled, no puzzle specified. Not starting game.');
      return;
    }
    
    print('PuzzleGameModule2: Starting new game with difficulty $difficulty');
    
    // Determine grid size based on difficulty
    final gridSize = _getGridSizeForDifficulty(difficulty);
    print('PuzzleGameModule2: Using ${gridSize}x${gridSize} grid for difficulty $difficulty');
    
    // Use provided puzzleId or default to sample if enabled
    final selectedPuzzleId = puzzleId ?? 
        (showSamplePuzzle ? 'sample_puzzle_01' : null);
    
    if (selectedPuzzleId == null) {
      print('PuzzleGameModule2: No puzzle available to start');
      return;
    }
    
    // Load puzzle assets
    print('PuzzleGameModule2: Loading puzzle assets...');
    final puzzleData = await _assetManager.loadPuzzle(
      selectedPuzzleId,
      gridSize,
    );
    print('PuzzleGameModule2: Puzzle assets loaded');
    
    // Create new controller or reset existing one
    if (_controller == null || forceNewGame) {
      _controller = WorkspaceController(
        puzzleData: puzzleData,
        audioService: _audioService,
      );
      
      // Initialize interaction integration with feature flags
      final magneticGestures = await _featureFlags.isEnabled('magnetic_gestures');
      final enhancedFeedback = await _featureFlags.isEnabled('enhanced_feedback');
      final smoothAnimations = await _featureFlags.isEnabled('smooth_animations');
      
      print('PuzzleGameModule2: Interaction features:');
      print('  - Magnetic gestures: $magneticGestures');
      print('  - Enhanced feedback: $enhancedFeedback');
      print('  - Smooth animations: $smoothAnimations');
      
      _interactionIntegration = InteractionIntegration(
        controller: _controller!,
        enableMagneticGestures: magneticGestures,
        enableEnhancedFeedback: enhancedFeedback,
        enableSmoothAnimations: smoothAnimations,
      );
      await _interactionIntegration!.initialize();
    } else {
      await _controller!.reset();
    }
    
    _gameStarted = true;
  }
  
  /// Get the workspace widget for rendering
  Widget? getWorkspaceWidget() {
    if (!_initialized || _controller == null) {
      return null;
    }
    
    return WorkspaceWidget(
      controller: _controller!,
      interactionIntegration: _interactionIntegration,
    );
  }
  
  /// Check if a game is currently active
  bool get isGameActive => _gameStarted && _controller != null;
  
  /// Get the current controller
  WorkspaceController? get controller => _controller;
  
  /// Get the interaction integration
  InteractionIntegration? get interactionIntegration => _interactionIntegration;
  
  /// Get feature flags service
  FeatureFlagService get featureFlags => _featureFlags;
  
  /// Determine grid size based on difficulty level
  int _getGridSizeForDifficulty(int difficulty) {
    switch (difficulty) {
      case 1:
        return 8;  // 64 pieces
      case 2:
        return 12; // 144 pieces
      case 3:
        return 15; // 225 pieces
      default:
        return 8;
    }
  }
  
  /// Clean up resources
  void dispose() {
    _controller?.dispose();
    _interactionIntegration?.dispose();
    _audioService.dispose();
    _gameStarted = false;
  }
}