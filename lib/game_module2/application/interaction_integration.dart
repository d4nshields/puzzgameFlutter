import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/gestures.dart' as gestures;

// Domain imports
import '../domain/entities/puzzle_piece.dart';
import '../domain/entities/puzzle_workspace.dart';
import '../domain/value_objects/puzzle_coordinate.dart';
import '../domain/services/piece_state_machine.dart';
import '../domain/services/state_transitions.dart';

// Presentation imports
import '../presentation/gestures/magnetic_gesture_recognizer.dart';
import '../presentation/gestures/gesture_coordinator.dart';

// Application imports
import 'feedback_controller.dart';

// Infrastructure imports
// Removed unused import - will be needed when haptic patterns are implemented
import '../infrastructure/event_bus.dart' as event_bus;
import '../infrastructure/feature_flags.dart';
import '../infrastructure/configuration_manager.dart';

/// Central integration system that coordinates all interaction components.
/// 
/// This class implements the Event Bus pattern for loose coupling between
/// components while maintaining proper coordination and error boundaries.
class InteractionIntegration with ChangeNotifier {
  // Core dependencies
  final event_bus.EventBus _eventBus;
  final ConfigurationManager _config;
  final FeatureFlagService _featureFlags;
  
  // State management
  final Map<String, PieceStateMachine> _stateMachines = {};
  final Map<String, MagneticGestureRecognizer> _gestureRecognizers = {};
  
  // Controllers
  // TODO: These will be used when full integration is implemented
  // ignore: unused_field
  late final FeedbackController _feedbackController;
  // ignore: unused_field
  late final GestureCoordinator _gestureCoordinator;
  late final TransitionValidator _transitionValidator;
  late final TransitionAnimator _transitionAnimator;
  late final TransitionRecorder _transitionRecorder;
  // ignore: unused_field
  late final BatchTransitioner _batchTransitioner;
  
  // Magnetic field configuration
  late MagneticFieldConfiguration _magneticConfig;
  final List<MagneticSnapPoint> _snapPoints = [];
  
  // Performance monitoring
  final Map<String, LocalPerformanceMetrics> _performanceMetrics = {};
  Timer? _metricsTimer;
  
  // Debug features
  bool _debugMode = false;
  final StreamController<DebugEvent> _debugStream = StreamController.broadcast();
  
  // Error handling
  final List<String> _errorLog = [];
  static const int _maxErrorLogSize = 100;
  
  InteractionIntegration({
    required TickerProvider tickerProvider,
    event_bus.EventBus? eventBus,
    ConfigurationManager? config,
    FeatureFlagService? featureFlags,
    bool debugMode = false,
  }) : _eventBus = eventBus ?? event_bus.EventBus(),
        _config = config ?? ConfigurationManager(),
        _featureFlags = featureFlags ?? FeatureFlagService(),
        _debugMode = debugMode {
    
    _initialize(tickerProvider);
  }
  
  // Getters
  event_bus.EventBus get eventBus => _eventBus;
  Stream<DebugEvent> get debugStream => _debugStream.stream;
  bool get debugMode => _debugMode;
  Map<String, LocalPerformanceMetrics> get performanceMetrics => Map.unmodifiable(_performanceMetrics);
  List<String> get errorLog => List.unmodifiable(_errorLog);
  
  /// Initialize all subsystems
  void _initialize(TickerProvider tickerProvider) {
    // Initialize transition system
    _transitionValidator = TransitionValidator(debugMode: _debugMode);
    _transitionAnimator = TransitionAnimator(tickerProvider: tickerProvider);
    _transitionRecorder = TransitionRecorder();
    _batchTransitioner = BatchTransitioner(
      validator: _transitionValidator,
      animator: _transitionAnimator,
      recorder: _transitionRecorder,
    );
    
    // Initialize feedback controller (simplified constructor)
    _feedbackController = FeedbackController();
    
    // Initialize gesture coordinator
    _gestureCoordinator = GestureCoordinator();
    
    // Set up event bus subscriptions
    _setupEventSubscriptions();
    
    // Start performance monitoring
    if (_featureFlags.isEnabled('performance_monitoring')) {
      _startPerformanceMonitoring();
    }
    
    // Load configuration
    _loadConfiguration();
  }
  
  /// Set up event bus subscriptions for component communication
  void _setupEventSubscriptions() {
    // State machine events
    _eventBus.on<event_bus.StateTransitionEvent>().listen(_handleStateTransition);
    
    // Gesture events
    _eventBus.on<event_bus.GestureEvent>().listen(_handleGestureEvent);
    
    // Feedback events
    _eventBus.on<event_bus.FeedbackRequestEvent>().listen(_handleFeedbackRequest);
    
    // Performance events
    _eventBus.on<event_bus.PerformanceEvent>().listen(_handlePerformanceEvent);
    
    // Error events
    _eventBus.on<event_bus.ErrorEvent>().listen(_handleError);
    
    // Configuration change events
    _eventBus.on<event_bus.ConfigurationChangeEvent>().listen(_handleConfigurationChange);
  }
  
  /// Load configuration from manager
  void _loadConfiguration() {
    // Magnetic field configuration
    final magneticSettings = _config.getSection('magnetic_field');
    _magneticConfig = MagneticFieldConfiguration(
      snapPoints: _snapPoints,
      strength: magneticSettings['strength'] ?? 0.4,
      minimumInfluence: magneticSettings['minimum_influence'] ?? 0.1,
      maxInfluence: magneticSettings['max_influence'] ?? 8.0,
      falloffType: FieldFalloffType.values[magneticSettings['falloff_type'] ?? 1],
    );
    
    // Feedback settings would be configured here
    // Gesture settings would be configured here
  }
  
  /// Initialize interaction system for a puzzle workspace
  void initializeForWorkspace(PuzzleWorkspace workspace) {
    try {
      // Clear existing state
      _clearState();
      
      // Initialize snap points from correct positions
      _initializeSnapPoints(workspace);
      
      // Initialize state machines for all pieces
      for (final piece in workspace.pieces) {
        _initializeStateMachine(piece, workspace);
      }
      
      // Notify listeners
      notifyListeners();
      
      // Emit initialization event
      _eventBus.fire(event_bus.WorkspaceInitializedEvent(
        workspaceId: workspace.id,
        pieceCount: workspace.pieces.length,
      ));
      
    } catch (e, stack) {
      _logError('Failed to initialize workspace', e, stack);
      rethrow;
    }
  }
  
  /// Initialize snap points based on workspace grid
  void _initializeSnapPoints(PuzzleWorkspace workspace) {
    _snapPoints.clear();
    
    final gridSize = workspace.gridSize;
    final dims = gridSize.split('x');
    final rows = int.parse(dims[0]);
    final cols = int.parse(dims[1]);
    
    final cellWidth = workspace.canvasSize.width / cols;
    final cellHeight = workspace.canvasSize.height / rows;
    
    // Create snap points at each correct position
    for (final piece in workspace.pieces) {
      _snapPoints.add(MagneticSnapPoint(
        position: Offset(
          piece.correctPosition.x + cellWidth / 2,
          piece.correctPosition.y + cellHeight / 2,
        ),
        radius: _config.getValue('snap_radius', 50.0),
        strength: 1.0,
      ));
    }
    
    // Update magnetic configuration
    _magneticConfig = MagneticFieldConfiguration(
      snapPoints: _snapPoints,
      strength: _magneticConfig.strength,
      minimumInfluence: _magneticConfig.minimumInfluence,
      maxInfluence: _magneticConfig.maxInfluence,
      falloffType: _magneticConfig.falloffType,
    );
  }
  
  /// Initialize state machine for a piece
  void _initializeStateMachine(PuzzlePiece piece, PuzzleWorkspace workspace) {
    if (_stateMachines.containsKey(piece.id)) return;
    
    final stateMachine = PieceStateMachine(
      pieceId: piece.id,
      piece: piece,
      debugMode: _debugMode,
    );
    
    _stateMachines[piece.id] = stateMachine;
  }
  
  /// Create gesture recognizer for a piece with magnetic assistance
  gestures.GestureRecognizer createGestureRecognizer(
    String pieceId, {
    required void Function(DragStartDetails) onStart,
    required void Function(DragUpdateDetails) onUpdate,
    required void Function(DragEndDetails) onEnd,
  }) {
    try {
      // Check if already exists
      _gestureRecognizers[pieceId]?.dispose();
      
      // Get state machine for coordination
      final stateMachine = _stateMachines[pieceId];
      if (stateMachine == null) {
        throw StateError('No state machine for piece $pieceId');
      }
      
      // Create magnetic gesture recognizer
      final recognizer = MagneticGestureRecognizer(
        debugMode: _debugMode,
      );
      
      // Wrap callbacks with state transitions and feedback
      recognizer.onStart = (details) {
        _handleDragStart(pieceId, details);
        onStart(details);
      };
      
      recognizer.onUpdate = (details) {
        _handleDragUpdate(pieceId, details);
        onUpdate(details);
      };
      
      recognizer.onEnd = (details) {
        _handleDragEnd(pieceId, details);
        onEnd(details);
      };
      
      _gestureRecognizers[pieceId] = recognizer;
      
      return recognizer;
      
    } catch (e, stack) {
      _logError('Failed to create gesture recognizer for $pieceId', e, stack);
      rethrow;
    }
  }
  
  /// Handle drag start with state transition and feedback
  void _handleDragStart(String pieceId, DragStartDetails details) {
    try {
      final stateMachine = _stateMachines[pieceId];
      if (stateMachine == null) return;
      
      // Process drag start event
      stateMachine.processEvent(PieceDragStartEvent(
        pieceId: pieceId,
        startPosition: PuzzleCoordinate(
          x: details.globalPosition.dx,
          y: details.globalPosition.dy,
        ),
      ));
      
      // Emit event
      _eventBus.fire(event_bus.DragStartedEvent(
        pieceId: pieceId,
        position: event_bus.Offset(
          details.globalPosition.dx, 
          details.globalPosition.dy
        ),
      ));
      
    } catch (e, stack) {
      _logError('Error handling drag start for $pieceId', e, stack);
    }
  }
  
  /// Handle drag update with magnetic assistance
  void _handleDragUpdate(String pieceId, DragUpdateDetails details) {
    try {
      final stateMachine = _stateMachines[pieceId];
      if (stateMachine == null) return;
      
      // Check proximity to snap points
      final proximity = _calculateSnapProximity(Offset(
        details.globalPosition.dx,
        details.globalPosition.dy,
      ));
      
      // Process drag update
      stateMachine.processEvent(PieceDragUpdateEvent(
        pieceId: pieceId,
        position: PuzzleCoordinate(
          x: details.globalPosition.dx,
          y: details.globalPosition.dy,
        ),
        delta: PuzzleCoordinate(
          x: details.delta.dx,
          y: details.delta.dy,
        ),
        velocity: details.localPosition.distance,  // Simple velocity approximation
      ));
      
      // Emit event
      _eventBus.fire(event_bus.DragUpdatedEvent(
        pieceId: pieceId,
        position: event_bus.Offset(
          details.globalPosition.dx,
          details.globalPosition.dy,
        ),
        proximity: proximity,
      ));
      
    } catch (e, stack) {
      _logError('Error handling drag update for $pieceId', e, stack);
    }
  }
  
  /// Handle drag end with placement logic
  void _handleDragEnd(String pieceId, DragEndDetails details) {
    try {
      final stateMachine = _stateMachines[pieceId];
      if (stateMachine == null) return;
      
      // Process drag end
      stateMachine.processEvent(PieceDragEndEvent(
        pieceId: pieceId,
        endPosition: PuzzleCoordinate(
          x: details.velocity.pixelsPerSecond.dx,
          y: details.velocity.pixelsPerSecond.dy,
        ),
        velocity: details.velocity.pixelsPerSecond.distance,
      ));
      
      // Check if piece should snap to position
      final snapPoint = _findNearestSnapPoint(Offset(
        details.velocity.pixelsPerSecond.dx,
        details.velocity.pixelsPerSecond.dy,
      ));
      
      // Emit event
      _eventBus.fire(event_bus.DragEndedEvent(
        pieceId: pieceId,
        velocity: event_bus.Velocity(
          pixelsPerSecond: event_bus.Offset(
            details.velocity.pixelsPerSecond.dx,
            details.velocity.pixelsPerSecond.dy,
          ),
        ),
        wasPlaced: snapPoint != null,
      ));
      
    } catch (e, stack) {
      _logError('Error handling drag end for $pieceId', e, stack);
    }
  }
  
  /// Calculate proximity to nearest snap point
  double _calculateSnapProximity(Offset position) {
    double minDistance = double.infinity;
    
    for (final snapPoint in _snapPoints) {
      final distance = (snapPoint.position - position).distance;
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    // Normalize to 0-1 range
    return (minDistance / _magneticConfig.maxInfluence).clamp(0.0, 1.0);
  }
  
  /// Find nearest snap point if within threshold
  MagneticSnapPoint? _findNearestSnapPoint(Offset velocity) {
    // Implementation would check proximity and velocity
    // This is simplified for the example
    return null;
  }
  
  /// Check if puzzle is complete and trigger celebration
  // TODO: Will be used when completion detection is implemented
  // ignore: unused_element
  void _checkCompletion() {
    final allPlaced = _stateMachines.values.every(
      (machine) => machine.currentState == PieceStateType.placed ||
                   machine.currentState == PieceStateType.locked,
    );
    
    if (allPlaced) {
      // Emit completion event
      _eventBus.fire(event_bus.PuzzleCompletedEvent());
    }
  }
  
  /// Handle state transition events from event bus
  void _handleStateTransition(event_bus.StateTransitionEvent event) {
    try {
      final stateMachine = _stateMachines[event.pieceId];
      if (stateMachine != null) {
        // Process appropriate event based on target state
        // This is a simplified mapping
      }
    } catch (e, stack) {
      _logError('Failed to handle state transition', e, stack);
    }
  }
  
  /// Handle gesture events from event bus
  void _handleGestureEvent(event_bus.GestureEvent event) {
    try {
      // Handle gesture event
    } catch (e, stack) {
      _logError('Failed to handle gesture event', e, stack);
    }
  }
  
  /// Handle feedback requests from event bus
  void _handleFeedbackRequest(event_bus.FeedbackRequestEvent event) {
    try {
      // Trigger feedback through controller
    } catch (e, stack) {
      _logError('Failed to handle feedback request', e, stack);
    }
  }
  
  /// Handle performance events
  void _handlePerformanceEvent(event_bus.PerformanceEvent event) {
    // Store metrics - adapt to local type
    _performanceMetrics[event.componentId] = LocalPerformanceMetrics(
      averageFrameTime: 0.0,
      maxFrameTime: 0.0,
      droppedFrames: 0,
      memoryUsage: 0.0,
      custom: event.metrics as Map<String, dynamic>,
    );
    
    if (_debugMode) {
      _debugStream.add(DebugEvent(
        type: DebugEventType.performance,
        data: {
          'componentId': event.componentId,
          'metrics': event.metrics,
        },
      ));
    }
  }
  
  /// Handle configuration changes
  void _handleConfigurationChange(event_bus.ConfigurationChangeEvent event) {
    _loadConfiguration();
    notifyListeners();
  }
  
  /// Handle errors from event bus
  void _handleError(event_bus.ErrorEvent event) {
    _logError(event.message, event.error, event.stackTrace);
  }
  
  /// Start performance monitoring timer
  void _startPerformanceMonitoring() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _collectPerformanceMetrics();
    });
  }
  
  /// Collect performance metrics from all components
  void _collectPerformanceMetrics() {
    // Collect from gesture recognizers
    for (final entry in _gestureRecognizers.entries) {
      final metrics = entry.value.getPerformanceMetrics();
      _performanceMetrics['gesture_${entry.key}'] = LocalPerformanceMetrics(
        averageFrameTime: metrics.averageProcessingTime,
        maxFrameTime: metrics.maxProcessingTime.toDouble(),
        droppedFrames: metrics.droppedEvents,
        memoryUsage: 0.0,  // Not available in gesture metrics
      );
    }
    
    // Emit metrics event
    _eventBus.fire(event_bus.MetricsCollectedEvent(
      metrics: _performanceMetrics.map((k, v) => MapEntry(k, v.toJson())),
      timestamp: DateTime.now(),
    ));
  }
  
  /// Clear all state
  void _clearState() {
    // Dispose gesture recognizers
    for (final recognizer in _gestureRecognizers.values) {
      recognizer.dispose();
    }
    _gestureRecognizers.clear();
    
    // Clear state machines
    _stateMachines.clear();
    
    // Clear snap points
    _snapPoints.clear();
    
    // Clear metrics
    _performanceMetrics.clear();
  }
  
  /// Log error with bounded buffer
  void _logError(String message, dynamic error, StackTrace? stack) {
    final errorMessage = '$message: $error';
    _errorLog.add(errorMessage);
    
    // Keep error log bounded
    while (_errorLog.length > _maxErrorLogSize) {
      _errorLog.removeAt(0);
    }
    
    // Log to debug stream
    if (_debugMode) {
      _debugStream.add(DebugEvent(
        type: DebugEventType.error,
        data: {
          'message': message,
          'error': error.toString(),
          'stack': stack?.toString(),
        },
      ));
    }
    
    // Log to console in debug mode
    if (_debugMode) {
      print('InteractionIntegration Error: $errorMessage');
      if (stack != null) {
        print(stack);
      }
    }
  }
  
  /// Toggle debug mode
  void toggleDebugMode() {
    _debugMode = !_debugMode;
    
    // TODO: Implement debug mode toggle on state machines
    // for (final machine in _stateMachines.values) {
    //   machine.setDebugMode(_debugMode);
    // }
    _stateMachines.values.toList(); // Temporary: just reference the collection
    
    notifyListeners();
  }
  
  /// Export debug information
  Map<String, dynamic> exportDebugInfo() {
    return {
      'stateMachines': _stateMachines.map((id, machine) => MapEntry(
        id,
        {
          'currentState': machine.currentState.toString(),
          'history': machine.stateHistory.map((e) => e.toString()).toList(),
        },
      )),
      'performanceMetrics': _performanceMetrics.map((id, metrics) => MapEntry(
        id,
        metrics.toJson(),
      )),
      'errorLog': _errorLog,
      'configuration': _config.toJson(),
      'featureFlags': _featureFlags.getAllFlags(),
    };
  }
  
  @override
  void dispose() {
    _metricsTimer?.cancel();
    _debugStream.close();
    _clearState();
    super.dispose();
  }
}

/// Local performance metrics container (to avoid conflict with MagneticGestureRecognizer's)
class LocalPerformanceMetrics {
  final double averageFrameTime;
  final double maxFrameTime;
  final int droppedFrames;
  final double memoryUsage;
  final Map<String, dynamic> custom;
  
  LocalPerformanceMetrics({
    required this.averageFrameTime,
    required this.maxFrameTime,
    required this.droppedFrames,
    required this.memoryUsage,
    Map<String, dynamic>? custom,
  }) : custom = custom ?? {};
  
  Map<String, dynamic> toJson() => {
    'averageFrameTime': averageFrameTime,
    'maxFrameTime': maxFrameTime,
    'droppedFrames': droppedFrames,
    'memoryUsage': memoryUsage,
    'custom': custom,
  };
}

/// Debug event types
enum DebugEventType {
  stateChange,
  performance,
  error,
  configuration,
  gesture,
  feedback,
}

/// Debug event for monitoring
class DebugEvent {
  final DebugEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  DebugEvent({
    required this.type,
    required this.data,
  }) : timestamp = DateTime.now();
}
