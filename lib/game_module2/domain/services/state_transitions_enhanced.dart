import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Size;
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'piece_state_machine.dart';
import '../entities/puzzle_piece.dart';
import '../value_objects/puzzle_coordinate.dart';
import '../value_objects/piece_bounds.dart';

/// Logger for state transitions
final _logger = Logger('StateTransitions');

/// Configure logging level
void configureTransitionLogging(Level level) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    final timestamp = record.time.toIso8601String();
    final message = '[$timestamp] ${record.level.name}: ${record.loggerName}: ${record.message}';
    
    if (record.error != null) {
      debugPrint('$message\nError: ${record.error}');
    } else {
      debugPrint(message);
    }
    
    if (record.stackTrace != null) {
      debugPrint('Stack trace:\n${record.stackTrace}');
    }
  });
}

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
  
  @override
  String toString() => 'TransitionRule(id: $id, priority: $priority, enabled: $enabled)';
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
  
  @override
  String toString() => 'TransitionAnimation(duration: ${duration.inMilliseconds}ms, '
      'range: $initialValue-$targetValue, curve: ${curve.runtimeType})';
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
  
  @override
  String toString() => 'CompositeTransition(id: $id, states: ${sequence.length}, '
      'mode: ${parallel ? "parallel" : "sequential"})';
}

/// Transition validation result
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic> metadata;
  final List<String> appliedRules;
  final Duration validationTime;
  
  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.metadata = const {},
    this.appliedRules = const [],
    this.validationTime = Duration.zero,
  });
  
  factory ValidationResult.valid([
    Map<String, dynamic>? metadata,
    List<String>? appliedRules,
    Duration? validationTime,
  ]) {
    return ValidationResult(
      isValid: true,
      metadata: metadata ?? {},
      appliedRules: appliedRules ?? [],
      validationTime: validationTime ?? Duration.zero,
    );
  }
  
  factory ValidationResult.invalid(
    String message, [
    Map<String, dynamic>? metadata,
    List<String>? appliedRules,
    Duration? validationTime,
  ]) {
    return ValidationResult(
      isValid: false,
      errorMessage: message,
      metadata: metadata ?? {},
      appliedRules: appliedRules ?? [],
      validationTime: validationTime ?? Duration.zero,
    );
  }
  
  @override
  String toString() => 'ValidationResult(valid: $isValid, rules: ${appliedRules.length}, '
      'time: ${validationTime.inMicroseconds}μs${errorMessage != null ? ", error: $errorMessage" : ""})';
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
  final String? errorMessage;
  
  TransitionRecord({
    String? id,
    required this.timestamp,
    required this.pieceId,
    required this.fromState,
    required this.toState,
    required this.duration,
    required this.successful,
    Map<String, dynamic>? metadata,
    this.errorMessage,
  }) : 
    id = id ?? '${DateTime.now().millisecondsSinceEpoch}_${pieceId}_${fromState}_$toState',
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
    if (errorMessage != null) 'error': errorMessage,
  };
  
  @override
  String toString() => 'TransitionRecord($id: $fromState→$toState, '
      '${successful ? "SUCCESS" : "FAILED"}, ${duration.inMilliseconds}ms)';
}

/// Main transition validator with rules engine
class TransitionValidator {
  final List<TransitionRule> _rules = [];
  final Map<String, TransitionRule> _ruleMap = {};
  final Map<String, int> _ruleExecutionCount = {};
  final Map<String, Duration> _ruleExecutionTime = {};
  bool debugMode = false;
  bool enableMetrics = true;
  
  TransitionValidator({this.debugMode = false, this.enableMetrics = true}) {
    _logger.info('TransitionValidator initialized (debug: $debugMode, metrics: $enableMetrics)');
    _initializeDefaultRules();
  }
  
  /// Initialize default validation rules
  void _initializeDefaultRules() {
    _logger.fine('Initializing default validation rules');
    
    // Rule: Cannot transition from locked state
    addRule(TransitionRule(
      id: 'no_transition_from_locked',
      description: 'Pieces cannot transition from locked state',
      condition: (machine, event) {
        final result = !machine.isInState(PieceStateType.locked);
        _logger.finest('Rule no_transition_from_locked: $result');
        return result;
      },
      priority: 100,
    ));
    
    // Rule: Cannot drag a placed piece
    addRule(TransitionRule(
      id: 'no_drag_when_placed',
      description: 'Placed pieces cannot be dragged',
      condition: (machine, event) {
        if (event is PieceDragStartEvent) {
          final result = !machine.isInState(PieceStateType.placed);
          _logger.finest('Rule no_drag_when_placed: $result for piece ${machine.pieceId}');
          return result;
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
          final result = machine.isInState(PieceStateType.selected) ||
                 machine.isInState(PieceStateType.hovering);
          _logger.finest('Rule select_before_drag: $result for piece ${machine.pieceId}');
          return result;
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
          final result = machine.isInState(PieceStateType.placed) ||
                 machine.piece.isPlaced;
          _logger.finest('Rule celebrate_only_when_placed: $result');
          return result;
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
          final result = machine.piece.isNearCorrectPosition(threshold: 150.0);
          _logger.finest('Rule magnetize_proximity_check: $result, '
              'distance: ${machine.piece.distanceToCorrect}');
          return result;
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
          final result = velocity < 500.0;
          _logger.finest('Rule snap_velocity_check: $result, velocity: $velocity');
          return result;
        }
        return true;
      },
      priority: 50,
    ));
    
    _logger.info('Initialized ${_rules.length} default validation rules');
  }
  
  /// Add a validation rule
  void addRule(TransitionRule rule) {
    _logger.fine('Adding rule: $rule');
    _rules.add(rule);
    _ruleMap[rule.id] = rule;
    _rules.sort((a, b) => b.priority.compareTo(a.priority));
    _logger.info('Rule added: ${rule.id} (total rules: ${_rules.length})');
  }
  
  /// Remove a rule by ID
  void removeRule(String ruleId) {
    _logger.fine('Removing rule: $ruleId');
    final countBefore = _rules.length;
    _rules.removeWhere((rule) => rule.id == ruleId);
    final removed = countBefore - _rules.length;
    _ruleMap.remove(ruleId);
    _logger.info('Rule removed: $ruleId (removed count: $removed)');
  }
  
  /// Enable or disable a rule
  void setRuleEnabled(String ruleId, bool enabled) {
    _logger.fine('Setting rule $ruleId enabled: $enabled');
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
      _logger.info('Rule $ruleId ${enabled ? "enabled" : "disabled"}');
    } else {
      _logger.warning('Rule $ruleId not found');
    }
  }
  
  /// Validate a transition
  ValidationResult validate(
    PieceStateMachine machine,
    PieceEvent event,
  ) {
    final startTime = DateTime.now();
    final failedRules = <String>[];
    final appliedRules = <String>[];
    
    _logger.fine('Validating transition for ${machine.pieceId} with event ${event.runtimeType}');
    _logger.finer('Current state: ${machine.currentState}');
    
    for (final rule in _rules) {
      if (!rule.enabled) {
        _logger.finest('Skipping disabled rule: ${rule.id}');
        continue;
      }
      
      appliedRules.add(rule.id);
      final ruleStartTime = DateTime.now();
      
      try {
        final passed = rule.condition(machine, event);
        final ruleTime = DateTime.now().difference(ruleStartTime);
        
        if (enableMetrics) {
          _ruleExecutionCount[rule.id] = (_ruleExecutionCount[rule.id] ?? 0) + 1;
          _ruleExecutionTime[rule.id] = (_ruleExecutionTime[rule.id] ?? Duration.zero) + ruleTime;
        }
        
        _logger.finest('Rule ${rule.id}: ${passed ? "PASSED" : "FAILED"} '
            '(${ruleTime.inMicroseconds}μs)');
        
        if (!passed) {
          failedRules.add(rule.description);
          
          if (debugMode) {
            _logger.warning('Validation failed: ${rule.description} '
                'for piece ${machine.pieceId}');
          }
          
          // Return on first high-priority failure
          if (rule.priority >= 100) {
            final validationTime = DateTime.now().difference(startTime);
            final result = ValidationResult.invalid(
              rule.description,
              {'failedRules': failedRules},
              appliedRules,
              validationTime,
            );
            _logger.info('Validation result: $result');
            return result;
          }
        }
      } catch (e, stack) {
        _logger.severe('Error evaluating rule ${rule.id}', e, stack);
        if (debugMode) {
          rethrow;
        }
      }
    }
    
    final validationTime = DateTime.now().difference(startTime);
    
    if (failedRules.isNotEmpty) {
      final result = ValidationResult.invalid(
        failedRules.join(', '),
        {'failedRules': failedRules},
        appliedRules,
        validationTime,
      );
      _logger.info('Validation failed: $result');
      return result;
    }
    
    final result = ValidationResult.valid({}, appliedRules, validationTime);
    _logger.fine('Validation passed: $result');
    return result;
  }
  
  /// Get rule execution metrics
  Map<String, dynamic> getMetrics() {
    final metrics = <String, dynamic>{};
    
    for (final ruleId in _ruleExecutionCount.keys) {
      final count = _ruleExecutionCount[ruleId] ?? 0;
      final totalTime = _ruleExecutionTime[ruleId] ?? Duration.zero;
      final avgTime = count > 0 ? totalTime.inMicroseconds ~/ count : 0;
      
      metrics[ruleId] = {
        'executions': count,
        'totalTime': totalTime.inMicroseconds,
        'averageTime': avgTime,
      };
    }
    
    return metrics;
  }
  
  /// Reset metrics
  void resetMetrics() {
    _logger.info('Resetting validation metrics');
    _ruleExecutionCount.clear();
    _ruleExecutionTime.clear();
  }
}

/// Manages transition animations with curves
class TransitionAnimator {
  final Map<String, AnimationController> _controllers = {};
  final Map<String, Animation<double>> _animations = {};
  final Map<String, DateTime> _animationStartTimes = {};
  final TickerProvider tickerProvider;
  bool enableLogging = true;
  
  TransitionAnimator({
    required this.tickerProvider,
    this.enableLogging = true,
  }) {
    _logger.info('TransitionAnimator initialized');
  }
  
  /// Create an animation for a transition
  Future<Animation<double>> animate({
    required String transitionId,
    required TransitionAnimation config,
    VoidCallback? onComplete,
  }) async {
    _logger.fine('Starting animation: $transitionId with config: $config');
    
    // Dispose existing controller if present
    if (_controllers.containsKey(transitionId)) {
      _logger.finer('Disposing existing controller for $transitionId');
      _controllers[transitionId]?.dispose();
    }
    
    // Create new controller
    final controller = AnimationController(
      duration: config.duration,
      vsync: tickerProvider,
    );
    _controllers[transitionId] = controller;
    _animationStartTimes[transitionId] = DateTime.now();
    
    // Create curved animation
    final animation = CurvedAnimation(
      parent: controller,
      curve: config.curve,
    ).drive(Tween<double>(
      begin: config.initialValue,
      end: config.targetValue,
    ));
    _animations[transitionId] = animation;
    
    // Add completion callback with logging
    if (onComplete != null) {
      controller.addStatusListener((status) {
        _logger.finest('Animation $transitionId status: $status');
        if (status == AnimationStatus.completed) {
          final duration = DateTime.now().difference(_animationStartTimes[transitionId]!);
          _logger.fine('Animation $transitionId completed in ${duration.inMilliseconds}ms');
          onComplete();
        } else if (status == AnimationStatus.dismissed && config.reverseOnCancel) {
          _logger.fine('Animation $transitionId dismissed (reversed)');
        }
      });
    }
    
    // Log animation progress in debug mode
    if (enableLogging) {
      animation.addListener(() {
        _logger.finest('Animation $transitionId progress: ${animation.value}');
      });
    }
    
    // Start animation
    _logger.fine('Starting animation forward: $transitionId');
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
    _logger.fine('Starting spring animation: $transitionId '
        '(stiffness: $stiffness, damping: $damping, mass: $mass, target: $target)');
    
    if (_controllers.containsKey(transitionId)) {
      _controllers[transitionId]?.dispose();
    }
    
    final controller = AnimationController(
      vsync: tickerProvider,
    );
    _controllers[transitionId] = controller;
    _animationStartTimes[transitionId] = DateTime.now();
    
    final spring = SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
    
    _logger.finer('Spring parameters - damping ratio: ${spring.damping}, '
        'natural frequency: ${math.sqrt(stiffness / mass)}');
    
    final simulation = SpringSimulation(spring, 0, target, 0);
    
    if (onComplete != null) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          final duration = DateTime.now().difference(_animationStartTimes[transitionId]!);
          _logger.fine('Spring animation $transitionId completed in ${duration.inMilliseconds}ms');
          onComplete();
        }
      });
    }
    
    await controller.animateWith(simulation);
    
    return controller;
  }
  
  /// Get animation for a transition
  Animation<double>? getAnimation(String transitionId) {
    final animation = _animations[transitionId];
    if (animation != null) {
      _logger.finest('Retrieved animation $transitionId (value: ${animation.value})');
    }
    return animation;
  }
  
  /// Stop an animation
  void stopAnimation(String transitionId) {
    _logger.fine('Stopping animation: $transitionId');
    _controllers[transitionId]?.stop();
  }
  
  /// Reverse an animation
  void reverseAnimation(String transitionId) {
    _logger.fine('Reversing animation: $transitionId');
    _controllers[transitionId]?.reverse();
  }
  
  /// Dispose of a specific animation
  void disposeAnimation(String transitionId) {
    _logger.fine('Disposing animation: $transitionId');
    _controllers[transitionId]?.dispose();
    _controllers.remove(transitionId);
    _animations.remove(transitionId);
    _animationStartTimes.remove(transitionId);
  }
  
  /// Get animation status
  Map<String, dynamic> getAnimationStatus() {
    final status = <String, dynamic>{};
    
    for (final entry in _controllers.entries) {
      status[entry.key] = {
        'isAnimating': entry.value.isAnimating,
        'value': entry.value.value,
        'status': entry.value.status.toString(),
        if (_animationStartTimes.containsKey(entry.key))
          'duration': DateTime.now().difference(_animationStartTimes[entry.key]!).inMilliseconds,
      };
    }
    
    return status;
  }
  
  /// Dispose all animations
  void dispose() {
    _logger.info('Disposing all animations (${_controllers.length} controllers)');
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _animations.clear();
    _animationStartTimes.clear();
  }
}

/// Records transition analytics
class TransitionRecorder {
  final List<TransitionRecord> _records = [];
  final int maxRecords;
  final StreamController<TransitionRecord> _recordStream = 
    StreamController<TransitionRecord>.broadcast();
  final Map<String, int> _transitionCounts = {};
  final Map<String, Duration> _transitionTotalTime = {};
  bool enableDetailedLogging = false;
  
  TransitionRecorder({
    this.maxRecords = 1000,
    this.enableDetailedLogging = false,
  }) {
    _logger.info('TransitionRecorder initialized (max records: $maxRecords)');
  }
  
  /// Record a transition
  void record(TransitionRecord record) {
    _logger.fine('Recording transition: $record');
    
    _records.add(record);
    
    // Update metrics
    final key = '${record.fromState}->${record.toState}';
    _transitionCounts[key] = (_transitionCounts[key] ?? 0) + 1;
    _transitionTotalTime[key] = (_transitionTotalTime[key] ?? Duration.zero) + record.duration;
    
    // Maintain max size
    if (_records.length > maxRecords) {
      final removed = _records.removeAt(0);
      _logger.finest('Removed oldest record: ${removed.id}');
    }
    
    _recordStream.add(record);
    
    if (enableDetailedLogging) {
      _logger.info('Transition recorded: ${record.pieceId} '
          '${record.fromState} -> ${record.toState} '
          '(${record.successful ? "SUCCESS" : "FAILED"}, ${record.duration.inMilliseconds}ms)');
    }
  }
  
  /// Get all records
  List<TransitionRecord> get records => List.unmodifiable(_records);
  
  /// Get records for a specific piece
  List<TransitionRecord> getRecordsForPiece(String pieceId) {
    final pieceRecords = _records.where((r) => r.pieceId == pieceId).toList();
    _logger.fine('Retrieved ${pieceRecords.length} records for piece $pieceId');
    return pieceRecords;
  }
  
  /// Get records within a time range
  List<TransitionRecord> getRecordsInRange(DateTime start, DateTime end) {
    final rangeRecords = _records.where((r) => 
      r.timestamp.isAfter(start) && r.timestamp.isBefore(end)
    ).toList();
    _logger.fine('Retrieved ${rangeRecords.length} records in range $start to $end');
    return rangeRecords;
  }
  
  /// Get transition statistics
  Map<String, dynamic> getStatistics() {
    _logger.fine('Generating statistics from ${_records.length} records');
    
    if (_records.isEmpty) {
      return {
        'totalTransitions': 0,
        'successRate': 0.0,
        'averageDuration': 0,
        'transitionCounts': {},
        'averageTransitionTimes': {},
      };
    }
    
    final successful = _records.where((r) => r.successful).length;
    final totalDuration = _records.fold<int>(
      0,
      (sum, r) => sum + r.duration.inMilliseconds,
    );
    
    // Calculate average times per transition type
    final avgTimes = <String, int>{};
    for (final entry in _transitionCounts.entries) {
      final count = entry.value;
      final totalTime = _transitionTotalTime[entry.key] ?? Duration.zero;
      avgTimes[entry.key] = count > 0 ? totalTime.inMilliseconds ~/ count : 0;
    }
    
    final stats = {
      'totalTransitions': _records.length,
      'successfulTransitions': successful,
      'failedTransitions': _records.length - successful,
      'successRate': successful / _records.length,
      'averageDuration': totalDuration ~/ _records.length,
      'stateFrequency': _getStateFrequency(),
      'transitionPairs': _getTransitionPairs(),
      'transitionCounts': _transitionCounts,
      'averageTransitionTimes': avgTimes,
      'recentFailures': _records
          .where((r) => !r.successful)
          .take(5)
          .map((r) => {
            'pieceId': r.pieceId,
            'transition': '${r.fromState}->${r.toState}',
            'error': r.errorMessage,
          })
          .toList(),
    };
    
    _logger.info('Statistics generated: ${stats['totalTransitions']} transitions, '
        '${((stats['successRate'] as double? ?? 0) * 100).toStringAsFixed(1)}% success rate');
    
    return stats;
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
    _logger.info('Clearing ${_records.length} transition records');
    _records.clear();
    _transitionCounts.clear();
    _transitionTotalTime.clear();
  }
  
  /// Export records as JSON
  List<Map<String, dynamic>> exportJson() {
    _logger.fine('Exporting ${_records.length} records to JSON');
    return _records.map((r) => r.toJson()).toList();
  }
  
  /// Generate detailed report
  String generateReport() {
    final stats = getStatistics();
    final buffer = StringBuffer();
    
    buffer.writeln('=== Transition Analytics Report ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('Summary:');
    buffer.writeln('  Total Transitions: ${stats['totalTransitions']}');
    buffer.writeln('  Success Rate: ${(stats['successRate'] * 100).toStringAsFixed(2)}%');
    buffer.writeln('  Average Duration: ${stats['averageDuration']}ms');
    buffer.writeln('');
    buffer.writeln('Most Common Transitions:');
    
    final sortedPairs = (stats['transitionPairs'] as Map<String, int>).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sortedPairs.take(10)) {
      buffer.writeln('  ${entry.key}: ${entry.value} times');
    }
    
    buffer.writeln('');
    buffer.writeln('State Frequency:');
    final sortedStates = (stats['stateFrequency'] as Map<String, int>).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sortedStates) {
      buffer.writeln('  ${entry.key}: ${entry.value} times');
    }
    
    if ((stats['recentFailures'] as List).isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Recent Failures:');
      for (final failure in stats['recentFailures'] as List) {
        buffer.writeln('  - Piece ${failure['pieceId']}: ${failure['transition']}');
        if (failure['error'] != null) {
          buffer.writeln('    Error: ${failure['error']}');
        }
      }
    }
    
    final report = buffer.toString();
    _logger.info('Generated analytics report (${report.length} characters)');
    return report;
  }
  
  /// Dispose resources
  void dispose() {
    _logger.info('Disposing TransitionRecorder');
    _recordStream.close();
  }
}

/// Handles batch transitions for multiple pieces
class BatchTransitioner {
  final TransitionValidator validator;
  final TransitionAnimator animator;
  final TransitionRecorder recorder;
  bool enableProgressLogging = true;
  
  BatchTransitioner({
    required this.validator,
    required this.animator,
    required this.recorder,
    this.enableProgressLogging = true,
  }) {
    _logger.info('BatchTransitioner initialized');
  }
  
  /// Execute transitions on multiple pieces
  Future<BatchTransitionResult> executeTransitions(
    List<PieceStateMachine> machines,
    PieceEvent Function(String pieceId) eventGenerator, {
    bool parallel = true,
    bool stopOnError = false,
    Duration? staggerDelay,
  }) async {
    _logger.info('Starting batch transition for ${machines.length} pieces '
        '(mode: ${parallel ? "parallel" : "sequential"}, stopOnError: $stopOnError)');
    
    final results = <String, bool>{};
    final errors = <String, String>{};
    final startTime = DateTime.now();
    int processed = 0;
    
    if (parallel) {
      // Execute in parallel
      _logger.fine('Executing transitions in parallel');
      final futures = <Future<bool>>[];
      
      for (final machine in machines) {
        futures.add(_executeTransition(
          machine,
          eventGenerator(machine.pieceId),
          results,
          errors,
        ).then((result) {
          processed++;
          if (enableProgressLogging) {
            _logger.fine('Progress: $processed/${machines.length} pieces processed');
          }
          return result;
        }));
      }
      
      await Future.wait(futures);
    } else {
      // Execute sequentially with optional stagger
      _logger.fine('Executing transitions sequentially'
          '${staggerDelay != null ? " with ${staggerDelay.inMilliseconds}ms stagger" : ""}');
      
      for (final machine in machines) {
        final success = await _executeTransition(
          machine,
          eventGenerator(machine.pieceId),
          results,
          errors,
        );
        
        processed++;
        if (enableProgressLogging) {
          _logger.fine('Progress: $processed/${machines.length} pieces processed');
        }
        
        if (!success && stopOnError) {
          _logger.warning('Stopping batch transition due to error');
          break;
        }
        
        if (staggerDelay != null) {
          _logger.finest('Stagger delay: ${staggerDelay.inMilliseconds}ms');
          await Future.delayed(staggerDelay);
        }
      }
    }
    
    final duration = DateTime.now().difference(startTime);
    
    final result = BatchTransitionResult(
      results: results,
      errors: errors,
      duration: duration,
      successCount: results.values.where((v) => v).length,
      failureCount: results.values.where((v) => !v).length,
    );
    
    _logger.info('Batch transition completed: $result');
    
    return result;
  }
  
  /// Execute a single transition
  Future<bool> _executeTransition(
    PieceStateMachine machine,
    PieceEvent event,
    Map<String, bool> results,
    Map<String, String> errors,
  ) async {
    final transitionStartTime = DateTime.now();
    
    _logger.fine('Executing transition for piece ${machine.pieceId} with event ${event.runtimeType}');
    
    try {
      // Validate
      final validation = validator.validate(machine, event);
      if (!validation.isValid) {
        results[machine.pieceId] = false;
        errors[machine.pieceId] = validation.errorMessage ?? 'Validation failed';
        
        _logger.warning('Transition validation failed for ${machine.pieceId}: '
            '${validation.errorMessage}');
        
        // Record failed transition
        recorder.record(TransitionRecord(
          timestamp: DateTime.now(),
          pieceId: machine.pieceId,
          fromState: machine.currentState,
          toState: machine.currentState, // No change
          duration: DateTime.now().difference(transitionStartTime),
          successful: false,
          errorMessage: validation.errorMessage,
        ));
        
        return false;
      }
      
      // Execute
      final success = await machine.processEvent(event);
      results[machine.pieceId] = success;
      
      final transitionDuration = DateTime.now().difference(transitionStartTime);
      
      // Record
      if (success) {
        _logger.fine('Transition successful for ${machine.pieceId} '
            '(${transitionDuration.inMilliseconds}ms)');
        
        recorder.record(TransitionRecord(
          timestamp: DateTime.now(),
          pieceId: machine.pieceId,
          fromState: machine.stateHistory.lastOrNull ?? PieceStateType.idle,
          toState: machine.currentState,
          duration: transitionDuration,
          successful: true,
        ));
      } else {
        _logger.warning('Transition failed for ${machine.pieceId}');
        errors[machine.pieceId] = 'Event processing failed';
      }
      
      return success;
    } catch (e, stack) {
      _logger.severe('Exception during transition for ${machine.pieceId}', e, stack);
      results[machine.pieceId] = false;
      errors[machine.pieceId] = e.toString();
      
      // Record exception
      recorder.record(TransitionRecord(
        timestamp: DateTime.now(),
        pieceId: machine.pieceId,
        fromState: machine.currentState,
        toState: machine.currentState,
        duration: DateTime.now().difference(transitionStartTime),
        successful: false,
        errorMessage: 'Exception: $e',
      ));
      
      return false;
    }
  }
  
  /// Create a composite transition
  Future<bool> executeComposite(
    PieceStateMachine machine,
    CompositeTransition transition,
  ) async {
    _logger.info('Executing composite transition ${transition.id} for piece ${machine.pieceId}');
    _logger.fine('Composite details: $transition');
    
    final startTime = DateTime.now();
    
    if (transition.parallel) {
      // Execute all transitions in parallel
      _logger.fine('Executing ${transition.sequence.length} states in parallel');
      
      final futures = transition.sequence.map((state) async {
        // Create appropriate event for each state
        final event = _createEventForState(machine, state);
        if (event != null) {
          _logger.finest('Processing event for state $state');
          return await machine.processEvent(event);
        }
        _logger.warning('Could not create event for state $state');
        return false;
      });
      
      final results = await Future.wait(futures);
      final allSuccessful = results.every((r) => r);
      
      final duration = DateTime.now().difference(startTime);
      _logger.info('Composite transition ${transition.id} completed: '
          '${allSuccessful ? "SUCCESS" : "FAILED"} (${duration.inMilliseconds}ms)');
      
      return allSuccessful;
    } else {
      // Execute transitions sequentially
      _logger.fine('Executing ${transition.sequence.length} states sequentially');
      
      for (int i = 0; i < transition.sequence.length; i++) {
        final state = transition.sequence[i];
        final event = _createEventForState(machine, state);
        
        if (event == null) {
          _logger.warning('Could not create event for state $state');
          return false;
        }
        
        _logger.finest('Processing state $i/${transition.sequence.length}: $state');
        final success = await machine.processEvent(event);
        
        if (!success) {
          _logger.warning('Composite transition failed at state $state');
          return false;
        }
        
        // Wait for duration if specified
        final duration = transition.durations[state];
        if (duration != null) {
          _logger.finest('Waiting ${duration.inMilliseconds}ms before next state');
          await Future.delayed(duration);
        }
      }
      
      final totalDuration = DateTime.now().difference(startTime);
      _logger.info('Composite transition ${transition.id} completed successfully '
          '(${totalDuration.inMilliseconds}ms)');
      
      return true;
    }
  }
  
  /// Create an event to transition to a specific state
  PieceEvent? _createEventForState(PieceStateMachine machine, PieceStateType targetState) {
    final pieceId = machine.pieceId;
    
    _logger.finest('Creating event for state $targetState');
    
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
        _logger.warning('No event mapping for state $targetState');
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
  double get successRate => results.isEmpty ? 0 : successCount / results.length;
  
  Map<String, dynamic> toJson() => {
    'results': results,
    'errors': errors,
    'duration': duration.inMilliseconds,
    'successCount': successCount,
    'failureCount': failureCount,
    'successRate': successRate,
  };
  
  @override
  String toString() => 'BatchTransitionResult(pieces: ${results.length}, '
      'success: $successCount, failed: $failureCount, '
      'rate: ${(successRate * 100).toStringAsFixed(1)}%, '
      'duration: ${duration.inMilliseconds}ms)';
}

/// Manages rollback functionality
class TransitionRollbackManager {
  final Map<String, List<StateMachineSnapshot>> _snapshots = {};
  final int maxSnapshotsPerPiece;
  int _totalSnapshots = 0;
  
  TransitionRollbackManager({this.maxSnapshotsPerPiece = 10}) {
    _logger.info('TransitionRollbackManager initialized (max snapshots: $maxSnapshotsPerPiece)');
  }
  
  /// Save a snapshot before transition
  void saveSnapshot(String pieceId, StateMachineSnapshot snapshot) {
    _logger.fine('Saving snapshot for piece $pieceId at state ${snapshot.state}');
    
    _snapshots.putIfAbsent(pieceId, () => []);
    _snapshots[pieceId]!.add(snapshot);
    _totalSnapshots++;
    
    // Maintain max size
    if (_snapshots[pieceId]!.length > maxSnapshotsPerPiece) {
      final removed = _snapshots[pieceId]!.removeAt(0);
      _totalSnapshots--;
      _logger.finest('Removed oldest snapshot for $pieceId (was at state ${removed.state})');
    }
    
    _logger.finer('Total snapshots in memory: $_totalSnapshots');
  }
  
  /// Rollback to previous state
  StateMachineSnapshot? rollback(String pieceId) {
    final snapshots = _snapshots[pieceId];
    if (snapshots == null || snapshots.isEmpty) {
      _logger.warning('No snapshots available for rollback of piece $pieceId');
      return null;
    }
    
    final snapshot = snapshots.removeLast();
    _totalSnapshots--;
    
    _logger.info('Rolling back piece $pieceId to state ${snapshot.state} '
        'from ${snapshot.timestamp.toIso8601String()}');
    
    return snapshot;
  }
  
  /// Get rollback history for a piece
  List<StateMachineSnapshot> getHistory(String pieceId) {
    final history = _snapshots[pieceId] ?? [];
    _logger.fine('Retrieved ${history.length} snapshots for piece $pieceId');
    return List.unmodifiable(history);
  }
  
  /// Clear snapshots for a piece
  void clearSnapshots(String pieceId) {
    final count = _snapshots[pieceId]?.length ?? 0;
    _snapshots.remove(pieceId);
    _totalSnapshots -= count;
    _logger.info('Cleared $count snapshots for piece $pieceId');
  }
  
  /// Clear all snapshots
  void clearAll() {
    _logger.info('Clearing all snapshots ($_totalSnapshots total)');
    _snapshots.clear();
    _totalSnapshots = 0;
  }
  
  /// Get memory usage estimate
  int getMemoryUsage() {
    // Rough estimate: ~500 bytes per snapshot
    return _totalSnapshots * 500;
  }
  
  /// Get statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalSnapshots': _totalSnapshots,
      'piecesTracked': _snapshots.length,
      'estimatedMemoryBytes': getMemoryUsage(),
      'snapshotsPerPiece': _snapshots.map((key, value) => MapEntry(key, value.length)),
    };
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
  
  @override
  String toString() => 'Snapshot(state: $state, time: ${timestamp.toIso8601String()})';
}

/// Testing utilities for state transitions
class TransitionTestUtils {
  static final _testLogger = Logger('TransitionTestUtils');
  
  /// Create a mock state machine for testing
  static PieceStateMachine createMockMachine({
    String pieceId = 'test_piece',
    PieceStateType initialState = PieceStateType.idle,
  }) {
    _testLogger.info('Creating mock machine: $pieceId with initial state $initialState');
    
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
    _testLogger.fine('Creating event sequence for $pieceId: ${eventTypes.length} events');
    
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
    
    _testLogger.fine('Verifying state sequence for ${machine.pieceId}');
    _testLogger.finer('Expected: $expectedSequence');
    _testLogger.finer('Actual history: $history');
    
    if (history.length < expectedSequence.length) {
      _testLogger.warning('History too short: ${history.length} < ${expectedSequence.length}');
      return false;
    }
    
    final relevantHistory = history.skip(
      history.length - expectedSequence.length
    ).toList();
    
    final matches = const ListEquality().equals(relevantHistory, expectedSequence);
    
    if (matches) {
      _testLogger.info('State sequence verified successfully');
    } else {
      _testLogger.warning('State sequence mismatch');
      _testLogger.warning('Expected: $expectedSequence');
      _testLogger.warning('Got: $relevantHistory');
    }
    
    return matches;
  }
  
  /// Simulate drag gesture
  static Future<void> simulateDrag(
    PieceStateMachine machine,
    PuzzleCoordinate start,
    PuzzleCoordinate end,
    int steps,
  ) async {
    _testLogger.info('Simulating drag for ${machine.pieceId}: '
        '$start -> $end in $steps steps');
    
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
      
      _testLogger.finest('Drag step $i/$steps: $position');
      
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
    
    _testLogger.info('Drag simulation completed');
  }
  
  /// Measure transition performance
  static Future<Map<String, dynamic>> measurePerformance(
    PieceStateMachine machine,
    List<PieceEvent> events,
  ) async {
    _testLogger.info('Measuring performance for ${events.length} events');
    
    final results = <String, dynamic>{
      'events': events.length,
      'transitions': <Map<String, dynamic>>[],
      'totalTime': 0,
      'averageTime': 0,
      'minTime': double.infinity,
      'maxTime': 0.0,
    };
    
    final totalStart = DateTime.now();
    
    for (final event in events) {
      final start = DateTime.now();
      final success = await machine.processEvent(event);
      final duration = DateTime.now().difference(start);
      
      results['transitions'].add({
        'event': event.runtimeType.toString(),
        'success': success,
        'duration': duration.inMicroseconds,
      });
      
      final micros = duration.inMicroseconds;
      if (micros < results['minTime']) results['minTime'] = micros;
      if (micros > results['maxTime']) results['maxTime'] = micros;
    }
    
    final totalDuration = DateTime.now().difference(totalStart);
    results['totalTime'] = totalDuration.inMicroseconds;
    results['averageTime'] = totalDuration.inMicroseconds ~/ events.length;
    
    _testLogger.info('Performance measurement complete: '
        'avg ${results['averageTime']}μs, '
        'min ${results['minTime']}μs, '
        'max ${results['maxTime']}μs');
    
    return results;
  }
}

/// Initialize logging for the transition system
void initializeTransitionLogging({
  Level level = Level.INFO,
  bool includeStackTraces = false,
}) {
  configureTransitionLogging(level);
  _logger.info('Transition system logging initialized at level ${level.name}');
}
