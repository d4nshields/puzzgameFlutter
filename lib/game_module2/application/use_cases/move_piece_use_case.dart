import '../../domain/entities/puzzle_workspace.dart';
import '../../domain/value_objects/puzzle_coordinate.dart';
import '../../domain/value_objects/move_result.dart';
import '../../domain/ports/feedback_service.dart';
import '../../domain/ports/persistence_repository.dart';

/// Use case for moving a puzzle piece within the workspace.
/// 
/// This use case orchestrates the business logic of moving a piece,
/// providing appropriate feedback, and handling auto-save.
class MovePieceUseCase {
  final PuzzleWorkspace workspace;
  final FeedbackService feedbackService;
  final PersistenceRepository? persistenceRepository;
  
  // Track last feedback to avoid repetition
  ProximityType? _lastProximityType;
  DateTime? _lastFeedbackTime;
  static const _feedbackThrottleMs = 100;

  MovePieceUseCase({
    required this.workspace,
    required this.feedbackService,
    this.persistenceRepository,
  });

  /// Execute the move piece operation
  Future<MoveResult> execute({
    required String pieceId,
    required PuzzleCoordinate newPosition,
    bool provideFeedback = true,
  }) async {
    // Perform the move
    final result = workspace.movePiece(pieceId, newPosition);
    
    // Provide feedback based on result
    if (provideFeedback) {
      await _provideFeedback(result);
    }
    
    // Auto-save if configured and move was successful
    if (workspace.config.autoSave && 
        result.wasSuccessful && 
        persistenceRepository != null) {
      // Throttle auto-saves
      if (_shouldAutoSave()) {
        await _saveProgress();
      }
    }
    
    return result;
  }

  /// Start dragging a piece (provides initial feedback)
  void startDragging(String pieceId) {
    feedbackService.provideHaptic(HapticIntensity.light);
    feedbackService.playSound(SoundType.pickup);
    feedbackService.startContinuousFeedback(FeedbackType.dragging);
    
    // Select the piece
    workspace.selectPiece(pieceId);
  }

  /// Stop dragging (cleans up continuous feedback)
  void stopDragging() {
    feedbackService.stopContinuousFeedback();
    workspace.deselectAll();
    _lastProximityType = null;
  }

  /// Provide feedback based on move result
  Future<void> _provideFeedback(MoveResult result) async {
    // Throttle feedback
    final now = DateTime.now();
    if (_lastFeedbackTime != null) {
      final elapsed = now.difference(_lastFeedbackTime!).inMilliseconds;
      if (elapsed < _feedbackThrottleMs && result.type != MoveResultType.snapped) {
        return;
      }
    }
    _lastFeedbackTime = now;

    switch (result.type) {
      case MoveResultType.snapped:
        // Strong feedback for correct placement
        feedbackService.provideHaptic(HapticIntensity.heavy);
        feedbackService.playSound(SoundType.snap);
        feedbackService.showVisualHint(
          VisualHint(
            type: HintType.flashPosition,
            duration: const Duration(milliseconds: 500),
          ),
        );
        
        // Check if puzzle is completed
        if (workspace.isCompleted) {
          await Future.delayed(const Duration(milliseconds: 300));
          feedbackService.playSound(SoundType.complete);
          feedbackService.showVisualHint(
            const VisualHint(type: HintType.completion),
          );
        }
        break;
        
      case MoveResultType.near:
        // Proximity-based feedback
        final intensity = result.proximityIntensity ?? 0.0;
        
        // Determine proximity type
        ProximityType proximityType;
        if (intensity > 0.8) {
          proximityType = ProximityType.snapReady;
        } else if (intensity > 0.5) {
          proximityType = ProximityType.veryClose;
        } else {
          proximityType = ProximityType.approaching;
        }
        
        // Only provide feedback if proximity changed significantly
        if (proximityType != _lastProximityType) {
          _lastProximityType = proximityType;
          
          // Haptic feedback based on proximity
          final hapticIntensity = intensity > 0.7 
              ? HapticIntensity.medium 
              : HapticIntensity.light;
          feedbackService.provideHaptic(hapticIntensity);
          
          // Audio feedback for very close
          if (intensity > 0.7) {
            feedbackService.playSound(SoundType.near);
          }
          
          // Visual feedback
          feedbackService.provideProximityFeedback(
            intensity: intensity,
            type: proximityType,
          );
        }
        break;
        
      case MoveResultType.moved:
        // Reset proximity tracking when moved away
        if (_lastProximityType != null) {
          _lastProximityType = null;
          feedbackService.provideProximityFeedback(
            intensity: 0.0,
            type: ProximityType.receding,
          );
        }
        break;
        
      case MoveResultType.blocked:
        // Error feedback for blocked moves
        feedbackService.provideHaptic(HapticIntensity.error);
        feedbackService.playSound(SoundType.error);
        break;
    }
  }

  /// Check if we should auto-save (throttled)
  bool _shouldAutoSave() {
    // Save every N moves or after certain time
    const saveInterval = 10; // Save every 10 moves
    return workspace.moveCount % saveInterval == 0;
  }

  /// Save workspace progress
  Future<void> _saveProgress() async {
    if (persistenceRepository == null) return;
    
    try {
      final progress = WorkspaceProgress(
        workspaceId: workspace.id,
        placedPieceIds: workspace.placedPieces.map((p) => p.id).toList(),
        piecePositions: Map.fromEntries(
          workspace.pieces
              .where((p) => !p.isInTray)
              .map((p) => MapEntry(
                p.id,
                PiecePosition(
                  x: p.currentPosition!.x,
                  y: p.currentPosition!.y,
                  isPlaced: p.isPlaced,
                ),
              )),
        ),
        moveCount: workspace.moveCount,
        hintsUsed: workspace.hintsUsed,
        timestamp: DateTime.now(),
      );
      
      await persistenceRepository!.saveProgress(workspace.id, progress);
    } catch (e) {
      // Log error but don't interrupt gameplay
      print('Failed to auto-save progress: $e');
    }
  }
}
