import 'dart:async';
import 'dart:ui' show Size;
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:collection/collection.dart';
import 'piece_state_machine.dart';
import '../entities/puzzle_piece.dart';
import '../value_objects/puzzle_coordinate.dart';
import '../value_objects/piece_bounds.dart';

/// Represents a transition rule
class TransitionRule {
  final String id;
  final String description;
  final bool Function(PieceStateMachine machine, PieceEvent event) condition;
  final int priority;
  final bool enabled;
  
  const TransitionRule({
    required this.id,
    required this.description,
    required this.condition,
    this.priority = 0,
    this.enabled = true,
  });
}

/// Transition animation configuration
class TransitionAnimation {
  final Curve curve;
  final Duration duration;
  final double initialValue;
  final double targetValue;
  final bool reverseOnCancel;
  
  const TransitionAnimation({
    this.curve = Curves.easeInOut,
    this.duration = const Duration(milliseconds: 300),
    this.initialValue = 0.0,
    this.targetValue = 1.0,
    this.reverseOnCancel = true,
  });
}

/// Represents a composite transition combining multiple state changes
class CompositeTransition {
  final String id;
  final List<PieceStateType> sequence;
  final Map<PieceStateType, Duration> durations;
  final bool parallel;
  
  const CompositeTransition({
    required this.id,
    required this.sequence,
    Map<PieceStateType, Duration>? durations,
    this.parallel = false,
  }) : durations = durations ?? const {};
}

/// Transition validation result
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic> metadata;
  
  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.metadata = const {},
  });
  
  factory ValidationResult.valid([Map<String, dynamic>? metadata]) {
    return ValidationResult(isValid: true, metadata: metadata ?? {});
  }
  
  factory ValidationResult.invalid(String message, [Map<String, dynamic>? metadata]) {
    return ValidationResult(
      isValid: false,
      errorMessage: message,
      metadata: metadata ?? {},
    );
  }
}

/// Transition record for analytics
class TransitionRecord {
  final String id;
  final DateTime timestamp;
  final String pieceId;
  final PieceStateType fromState;
  final PieceStateType toState;
  final Duration duration;
  final bool successful;
  final Map<String, dynamic> metadata;
  
  TransitionRecord({
    String? id,
    required this.timestamp,
    required this.pieceId,
    required this.fromState,
    required this.toState,
    required this.duration,
    required this.successful,
    Map<String, dynamic>? metadata,
  }) : 
    id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    metadata = metadata ?? {};
    
  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'pieceId': pieceId,
    'fromState': fromState.toString(),
    'toState': toState.toString(),
    'duration': duration.inMilliseconds,
    'successful': successful,
    'metadata': metadata,
  };
}

/// Main transition validator with rules engine
class TransitionValidator {
  final List<TransitionRule> _rules = [];
  final Map<String, TransitionRule> _ruleMap = {};
  bool debugMode = false;
  
  TransitionValidator({this.debugMode = false}) {
    _initializeDefaultRules();
  }
  
  /// Initialize default validation rules
  void _initializeDefaultRules() {
    // Rule: Cannot transition from locked state
    addRule(TransitionRule(
      id: 'no_transition_from_locked',
      description: 'Pieces cannot transition from locked state',
      condition: (machine, event) => !machine.isInState(PieceStateType.locked),
      priority: 100,
    ));
    
    // Rule: Cannot drag a placed piece
    addRule(TransitionRule(
      id: 'no_drag_when_placed',
      description: 'Placed pieces cannot be dragged',
      condition: (machine, event) {
        if (event is PieceDragStartEvent) {
          return !machine.isInState(PieceStateType.placed);
        }
        return true;
      },
      priority: 90,
    ));
    
    // Rule: Must be selected before dragging
    addRule(TransitionRule(
      id: 'select_before_drag',
      description: 'Pieces must be selected before dragging',
      condition: (machine, event) {
        if (event is PieceDragStartEvent) {
          return machine.isInState(PieceStateType.selected) ||
                 machine.isInState(PieceStateType.hovering);
        }
        return true;
      },
      priority: 80,
    ));
    
    // Rule: Cannot celebrate if not placed correctly
    addRule(TransitionRule(
      id: 'celebrate_only_when_placed',
      description: 'Can only celebrate when piece is correctly placed',
      condition: (machine, event) {
        if (event is PieceCelebrateEvent) {
          return machine.isInState(PieceStateType.placed) ||
                 machine.piece.isPlaced;
        }
        return true;
      },
      priority: 70,
    ));
    
    // Rule: Magnetization requires proximity
    addRule(TransitionRule(
      id: 'magnetize_proximity_check',
      description: 'Magnetization requires piece to be near correct position',
      condition: (machine, event) {
        if (event is PieceMagnetizeEvent) {
          return machine.piece.isNearCorrectPosition(threshold: 150.0);
        }
        return true;
      },
      priority: 60,
    ));
    
    // Rule: Snap requires drag velocity below threshold
    addRule(TransitionRule(
      id: 'snap_velocity_check',
      description: 'Snapping requires low drag velocity',
      condition: (machine, event) {
        if (event is PieceSnapEvent) {
          final velocity = machine.metadata['lastVelocity'] as double? ?? 0;
          return velocity < 500.0; // pixels per second
        }
        return true;
      },
      priority: 50,
    ));
  }
  
  /// Add a validation rule
  void addRule(TransitionRule rule) {
    _rules.add(rule);
    _ruleMap[rule.id] = rule;
    _rules.sort((a, b) => b.priority.compareTo(a.priority));
  }
  
  /// Remove a rule by ID
  void removeRule(String ruleId) {
    _rules.removeWhere((rule) => rule.id == ruleId);
    _ruleMap.remove(ruleId);
  }
  
  /// Enable or disable a rule
  void setRuleEnabled(String ruleId, bool enabled) {
    final rule = _ruleMap[ruleId];
    if (rule != null) {
      final index = _rules.indexOf(rule);
      _rules[index] = TransitionRule(
        id: rule.id,
        description: rule.description,
        condition: rule.condition,
        priority: rule.priority,
        enabled: enabled,
      );
      _ruleMap[ruleId] = _rules[index];
    }
  }
  
  /// Validate a transition
  ValidationResult validate(
    PieceStateMachine machine,
    PieceEvent event,
  ) {
    final failedRules = <String>[];
    
    for (final rule in _rules) {
      if (!rule.enabled) continue;
      
      try {
        if (!rule.condition(machine, event)) {
          failedRules.add(rule.description);
          
          if (debugMode) {
            debugPrint('Transition validation failed: ${rule.description}');
          }
          
          // Return on first high-priority failure
          if (rule.priority >= 100) {
            return ValidationResult.invalid(
              rule.description,
              {'failedRules': failedRules},
            );
          }
        }
      } catch (e) {
        if (debugMode) {
          debugPrint('Error evaluating rule ${rule.id}: $e');
        }
      }
    }
    
    if (failedRules.isNotEmpty) {
      return ValidationResult.invalid(
        failedRules.join(', '),
        {'failedRules': failedRules},
      );
    }
    
    return ValidationResult.valid();
  }
}

/// Manages transition animations with curves
class TransitionAnimator {
  final Map<String, AnimationController> _controllers = {};
  final Map<String, Animation<double>> _animations = {};
  final TickerProvider tickerProvider;
  
  TransitionAnimator({required this.tickerProvider});
  
  /// Create an animation for a transition
  Future<Animation<double>> animate({
    required String transitionId,
    required TransitionAnimation config,
    VoidCallback? onComplete,
  }) async {
    // Dispose existing controller if present
    _controllers[transitionId]?.dispose();
    
    // Create new controller
    final controller = AnimationController(
      duration: config.duration,
      vsync: tickerProvider,
    );
    _controllers[transitionId] = controller;
    
    // Create curved animation
    final animation = CurvedAnimation(
      parent: controller,
      curve: config.curve,
    ).drive(Tween<double>(
      begin: config.initialValue,
      end: config.targetValue,
    ));
    _animations[transitionId] = animation;
    
    // Add completion callback
    if (onComplete != null) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          onComplete();
        }
      });
    }
    
    // Start animation
    await controller.forward();
    
    return animation;
  }
  
  /// Animate with spring physics
  Future<Animation<double>> animateSpring({
    required String transitionId,
    required double target,
    double stiffness = 200.0,
    double damping = 15.0,
    double mass = 1.0,
    VoidCallback? onComplete,
  }) async {
    _controllers[transitionId]?.dispose();
    
    final controller = AnimationController(
      vsync: tickerProvider,
    );
    _controllers[transitionId] = controller;
    
    final spring = SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
    
    final simulation = SpringSimulation(spring, 0, target, 0);
    
    if (onComplete != null) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          onComplete();
        }
      });
    }
    
    await controller.animateWith(simulation);
    
    return controller;
  }
  
  /// Get animation for a transition
  Animation<double>? getAnimation(String transitionId) {
    return _animations[transitionId];
  }
  
  /// Stop an animation
  void stopAnimation(String transitionId) {
    _controllers[transitionId]?.stop();
  }
  
  /// Reverse an animation
  void reverseAnimation(String transitionId) {
    _controllers[transitionId]?.reverse();
  }
  
  /// Dispose of a specific animation
  void disposeAnimation(String transitionId) {
    _controllers[transitionId]?.dispose();
    _controllers.remove(transitionId);
    _animations.remove(transitionId);
  }
  
  /// Dispose all animations
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _animations.clear();
  }
}

/// Records transition analytics
class TransitionRecorder {
  final List<TransitionRecord> _records = [];
  final int maxRecords;
  final StreamController<TransitionRecord> _recordStream = 
    StreamController<TransitionRecord>.broadcast();
  
  TransitionRecorder({this.maxRecords = 1000});
  
  /// Record a transition
  void record(TransitionRecord record) {
    _records.add(record);
    
    // Maintain max size
    if (_records.length > maxRecords) {
      _records.removeAt(0);
    }
    
    _recordStream.add(record);
  }
  
  /// Get all records
  List<TransitionRecord> get records => List.unmodifiable(_records);
  
  /// Get records for a specific piece
  List<TransitionRecord> getRecordsForPiece(String pieceId) {
    return _records.where((r) => r.pieceId == pieceId).toList();
  }
  
  /// Get records within a time range
  List<TransitionRecord> getRecordsInRange(DateTime start, DateTime end) {
    return _records.where((r) => 
      r.timestamp.isAfter(start) && r.timestamp.isBefore(end)
    ).toList();
  }
  
  /// Get transition statistics
  Map<String, dynamic> getStatistics() {
    if (_records.isEmpty) {
      return {
        'totalTransitions': 0,
        'successRate': 0.0,
        'averageDuration': 0,
      };
    }
    
    final successful = _records.where((r) => r.successful).length;
    final totalDuration = _records.fold<int>(
      0,
      (sum, r) => sum + r.duration.inMilliseconds,
    );
    
    return {
      'totalTransitions': _records.length,
      'successfulTransitions': successful,
      'failedTransitions': _records.length - successful,
      'successRate': successful / _records.length,
      'averageDuration': totalDuration ~/ _records.length,
      'stateFrequency': _getStateFrequency(),
      'transitionPairs': _getTransitionPairs(),
    };
  }
  
  /// Get frequency of states
  Map<String, int> _getStateFrequency() {
    final frequency = <String, int>{};
    
    for (final record in _records) {
      frequency[record.toState.toString()] = 
        (frequency[record.toState.toString()] ?? 0) + 1;
    }
    
    return frequency;
  }
  
  /// Get common transition pairs
  Map<String, int> _getTransitionPairs() {
    final pairs = <String, int>{};
    
    for (final record in _records) {
      final pair = '${record.fromState} -> ${record.toState}';
      pairs[pair] = (pairs[pair] ?? 0) + 1;
    }
    
    return pairs;
  }
  
  /// Stream of records
  Stream<TransitionRecord> get recordStream => _recordStream.stream;
  
  /// Clear all records
  void clear() {
    _records.clear();
  }
  
  /// Export records as JSON
  List<Map<String, dynamic>> exportJson() {
    return _records.map((r) => r.toJson()).toList();
  }
  
  /// Dispose resources
  void dispose() {
    _recordStream.close();
  }
}

/// Handles batch transitions for multiple pieces
class BatchTransitioner {
  final TransitionValidator validator;
  final TransitionAnimator animator;
  final TransitionRecorder recorder;
  
  BatchTransitioner({
    required this.validator,
    required this.animator,
    required this.recorder,
  });
  
  /// Execute transitions on multiple pieces
  Future<BatchTransitionResult> executeTransitions(
    List<PieceStateMachine> machines,
    PieceEvent Function(String pieceId) eventGenerator, {
    bool parallel = true,
    bool stopOnError = false,
    Duration? staggerDelay,
  }) async {
    final results = <String, bool>{};
    final errors = <String, String>{};
    final startTime = DateTime.now();
    
    if (parallel) {
      // Execute in parallel
      final futures = <Future<bool>>[];
      
      for (final machine in machines) {
        futures.add(_executeTransition(
          machine,
          eventGenerator(machine.pieceId),
          results,
          errors,
        ));
      }
      
      await Future.wait(futures);
    } else {
      // Execute sequentially with optional stagger
      for (final machine in machines) {
        final success = await _executeTransition(
          machine,
          eventGenerator(machine.pieceId),
          results,
          errors,
        );
        
        if (!success && stopOnError) {
          break;
        }
        
        if (staggerDelay != null) {
          await Future.delayed(staggerDelay);
        }
      }
    }
    
    final duration = DateTime.now().difference(startTime);
    
    return BatchTransitionResult(
      results: results,
      errors: errors,
      duration: duration,
      successCount: results.values.where((v) => v).length,
      failureCount: results.values.where((v) => !v).length,
    );
  }
  
  /// Execute a single transition
  Future<bool> _executeTransition(
    PieceStateMachine machine,
    PieceEvent event,
    Map<String, bool> results,
    Map<String, String> errors,
  ) async {
    try {
      // Validate
      final validation = validator.validate(machine, event);
      if (!validation.isValid) {
        results[machine.pieceId] = false;
        errors[machine.pieceId] = validation.errorMessage ?? 'Validation failed';
        return false;
      }
      
      // Execute
      final success = await machine.processEvent(event);
      results[machine.pieceId] = success;
      
      // Record
      if (success) {
        recorder.record(TransitionRecord(
          timestamp: DateTime.now(),
          pieceId: machine.pieceId,
          fromState: machine.stateHistory.lastOrNull ?? PieceStateType.idle,
          toState: machine.currentState,
          duration: Duration.zero, // Will be updated by animation
          successful: true,
        ));
      }
      
      return success;
    } catch (e) {
      results[machine.pieceId] = false;
      errors[machine.pieceId] = e.toString();
      return false;
    }
  }
  
  /// Create a composite transition
  Future<bool> executeComposite(
    PieceStateMachine machine,
    CompositeTransition transition,
  ) async {
    if (transition.parallel) {
      // Execute all transitions in parallel
      final futures = transition.sequence.map((state) async {
        // Create appropriate event for each state
        final event = _createEventForState(machine, state);
        if (event != null) {
          return await machine.processEvent(event);
        }
        return false;
      });
      
      final results = await Future.wait(futures);
      return results.every((r) => r);
    } else {
      // Execute transitions sequentially
      for (int i = 0; i < transition.sequence.length; i++) {
        final state = transition.sequence[i];
        final event = _createEventForState(machine, state);
        
        if (event == null) {
          return false;
        }
        
        final success = await machine.processEvent(event);
        if (!success) {
          return false;
        }
        
        // Wait for duration if specified
        final duration = transition.durations[state];
        if (duration != null) {
          await Future.delayed(duration);
        }
      }
      
      return true;
    }
  }
  
  /// Create an event to transition to a specific state
  PieceEvent? _createEventForState(PieceStateMachine machine, PieceStateType targetState) {
    final pieceId = machine.pieceId;
    
    switch (targetState) {
      case PieceStateType.hovering:
        return PieceHoverEvent(pieceId: pieceId);
      case PieceStateType.selected:
        return PieceSelectEvent(
          pieceId: pieceId,
          position: machine.piece.currentPosition ?? PuzzleCoordinate.zero,
        );
      case PieceStateType.idle:
        return PieceDeselectEvent(pieceId: pieceId);
      case PieceStateType.placed:
        return PiecePlaceEvent(pieceId: pieceId, isCorrect: true);
      case PieceStateType.locked:
        return PieceLockEvent(pieceId: pieceId);
      case PieceStateType.celebrating:
        return PieceCelebrateEvent(
          pieceId: pieceId,
          celebrationType: 'success',
        );
      case PieceStateType.invalid:
        return PieceInvalidateEvent(
          pieceId: pieceId,
          reason: 'Transition requested',
        );
      case PieceStateType.returning:
        return PieceReturnEvent(pieceId: pieceId);
      default:
        return null;
    }
  }
}

/// Result of batch transition execution
class BatchTransitionResult {
  final Map<String, bool> results;
  final Map<String, String> errors;
  final Duration duration;
  final int successCount;
  final int failureCount;
  
  BatchTransitionResult({
    required this.results,
    required this.errors,
    required this.duration,
    required this.successCount,
    required this.failureCount,
  });
  
  bool get allSuccessful => failureCount == 0;
  double get successRate => successCount / results.length;
  
  Map<String, dynamic> toJson() => {
    'results': results,
    'errors': errors,
    'duration': duration.inMilliseconds,
    'successCount': successCount,
    'failureCount': failureCount,
    'successRate': successRate,
  };
}

/// Manages rollback functionality
class TransitionRollbackManager {
  final Map<String, List<StateMachineSnapshot>> _snapshots = {};
  final int maxSnapshotsPerPiece;
  
  TransitionRollbackManager({this.maxSnapshotsPerPiece = 10});
  
  /// Save a snapshot before transition
  void saveSnapshot(String pieceId, StateMachineSnapshot snapshot) {
    _snapshots.putIfAbsent(pieceId, () => []);
    _snapshots[pieceId]!.add(snapshot);
    
    // Maintain max size
    if (_snapshots[pieceId]!.length > maxSnapshotsPerPiece) {
      _snapshots[pieceId]!.removeAt(0);
    }
  }
  
  /// Rollback to previous state
  StateMachineSnapshot? rollback(String pieceId) {
    final snapshots = _snapshots[pieceId];
    if (snapshots == null || snapshots.isEmpty) {
      return null;
    }
    
    return snapshots.removeLast();
  }
  
  /// Clear snapshots for a piece
  void clearSnapshots(String pieceId) {
    _snapshots.remove(pieceId);
  }
  
  /// Clear all snapshots
  void clearAll() {
    _snapshots.clear();
  }
}

/// Snapshot of state machine state
class StateMachineSnapshot {
  final DateTime timestamp;
  final PieceStateType state;
  final Map<StateRegion, PieceStateType> parallelStates;
  final Map<String, dynamic> metadata;
  
  StateMachineSnapshot({
    required this.timestamp,
    required this.state,
    required this.parallelStates,
    required this.metadata,
  });
  
  factory StateMachineSnapshot.fromMachine(PieceStateMachine machine) {
    return StateMachineSnapshot(
      timestamp: DateTime.now(),
      state: machine.currentState,
      parallelStates: Map.from(machine.parallelStates),
      metadata: Map.from(machine.metadata),
    );
  }
}

/// Testing utilities for state transitions
class TransitionTestUtils {
  /// Create a mock state machine for testing
  static PieceStateMachine createMockMachine({
    String pieceId = 'test_piece',
    PieceStateType initialState = PieceStateType.idle,
  }) {
    final piece = PuzzlePiece(
      id: pieceId,
      correctRow: 0,
      correctCol: 0,
      correctPosition: PuzzleCoordinate(x: 100, y: 100),
      bounds: PieceBounds(
        contentBounds: const ContentRect(
          left: 0,
          top: 0,
          right: 50,
          bottom: 50,
        ),
        paddedSize: const Size(60, 60),
        targetBounds: const ContentRect(
          left: 100,
          top: 100,
          right: 150,
          bottom: 150,
        ),
      ),
    );
    
    return PieceStateMachine(
      pieceId: pieceId,
      piece: piece,
      initialState: initialState,
      debugMode: true,
    );
  }
  
  /// Create a sequence of events for testing
  static List<PieceEvent> createEventSequence(String pieceId, List<Type> eventTypes) {
    return eventTypes.map((type) {
      if (type == PieceHoverEvent) {
        return PieceHoverEvent(pieceId: pieceId);
      } else if (type == PieceSelectEvent) {
        return PieceSelectEvent(
          pieceId: pieceId,
          position: PuzzleCoordinate(x: 50, y: 50),
        );
      } else if (type == PieceDragStartEvent) {
        return PieceDragStartEvent(
          pieceId: pieceId,
          startPosition: PuzzleCoordinate(x: 50, y: 50),
        );
      } else if (type == PieceDragEndEvent) {
        return PieceDragEndEvent(
          pieceId: pieceId,
          endPosition: PuzzleCoordinate(x: 100, y: 100),
          velocity: 100.0,
        );
      } else if (type == PiecePlaceEvent) {
        return PiecePlaceEvent(pieceId: pieceId, isCorrect: true);
      } else if (type == PieceLockEvent) {
        return PieceLockEvent(pieceId: pieceId);
      } else {
        return PieceDeselectEvent(pieceId: pieceId);
      }
    }).toList();
  }
  
  /// Verify a state sequence
  static bool verifyStateSequence(
    PieceStateMachine machine,
    List<PieceStateType> expectedSequence,
  ) {
    final history = machine.stateHistory;
    if (history.length < expectedSequence.length - 1) {
      // -1 because we also need to check current state
      return false;
    }
    
    // Build full history including current state
    final fullHistory = [...history, machine.currentState];
    
    // Get the last N elements to match expected sequence
    final relevantHistory = fullHistory.length >= expectedSequence.length
        ? fullHistory.skip(fullHistory.length - expectedSequence.length).toList()
        : fullHistory;
    
    return const ListEquality().equals(relevantHistory, expectedSequence);
  }
  
  /// Simulate drag gesture
  static Future<void> simulateDrag(
    PieceStateMachine machine,
    PuzzleCoordinate start,
    PuzzleCoordinate end,
    int steps,
  ) async {
    await machine.processEvent(PieceSelectEvent(
      pieceId: machine.pieceId,
      position: start,
    ));
    
    await machine.processEvent(PieceDragStartEvent(
      pieceId: machine.pieceId,
      startPosition: start,
    ));
    
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final position = PuzzleCoordinate(
        x: start.x + (end.x - start.x) * t,
        y: start.y + (end.y - start.y) * t,
      );
      
      await machine.processEvent(PieceDragUpdateEvent(
        pieceId: machine.pieceId,
        position: position,
        delta: PuzzleCoordinate(
          x: (end.x - start.x) / steps,
          y: (end.y - start.y) / steps,
        ),
        velocity: 100.0,
      ));
      
      await Future.delayed(const Duration(milliseconds: 16));
    }
    
    await machine.processEvent(PieceDragEndEvent(
      pieceId: machine.pieceId,
      endPosition: end,
      velocity: 0.0,
    ));
  }
}
