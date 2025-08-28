import 'dart:async';

/// Event bus for decoupled component communication.
/// 
/// Implements a simple publish-subscribe pattern for loose coupling
/// between interaction layer components.
class EventBus {
  final Map<Type, List<StreamController>> _controllers = {};
  final Map<Type, List<Function>> _handlers = {};
  
  /// Fire an event to all registered listeners
  void fire(dynamic event) {
    final type = event.runtimeType;
    
    // Notify stream listeners
    final controllers = _controllers[type];
    if (controllers != null) {
      for (final controller in controllers) {
        if (!controller.isClosed) {
          controller.add(event);
        }
      }
    }
    
    // Notify function handlers
    final handlers = _handlers[type];
    if (handlers != null) {
      for (final handler in handlers) {
        try {
          handler(event);
        } catch (e) {
          print('EventBus: Error in handler for $type: $e');
        }
      }
    }
  }
  
  /// Listen to events of a specific type
  Stream<T> on<T>() {
    final controller = StreamController<T>.broadcast();
    final type = T;
    
    _controllers.putIfAbsent(type, () => []).add(controller);
    
    // Clean up closed controllers periodically
    controller.onCancel = () {
      Future.delayed(Duration.zero, () {
        _controllers[type]?.removeWhere((c) => c.isClosed);
      });
    };
    
    return controller.stream;
  }
  
  /// Register a handler function for an event type
  void subscribe<T>(void Function(T) handler) {
    final type = T;
    _handlers.putIfAbsent(type, () => []).add(handler);
  }
  
  /// Unregister a handler function
  void unsubscribe<T>(void Function(T) handler) {
    final type = T;
    _handlers[type]?.remove(handler);
  }
  
  /// Clear all subscriptions for a type
  void clear<T>() {
    final type = T;
    
    // Close all stream controllers
    final controllers = _controllers[type];
    if (controllers != null) {
      for (final controller in controllers) {
        controller.close();
      }
      _controllers.remove(type);
    }
    
    // Clear function handlers
    _handlers.remove(type);
  }
  
  /// Dispose of all resources
  void dispose() {
    for (final controllers in _controllers.values) {
      for (final controller in controllers) {
        controller.close();
      }
    }
    _controllers.clear();
    _handlers.clear();
  }
}

// Event definitions for the interaction system

/// Base class for all events
abstract class InteractionEvent {
  final DateTime timestamp;
  
  InteractionEvent() : timestamp = DateTime.now();
}

/// State transition request event
class StateTransitionEvent extends InteractionEvent {
  final String pieceId;
  final dynamic targetState;
  
  StateTransitionEvent({
    required this.pieceId,
    required this.targetState,
  });
}

/// Gesture event base class
abstract class GestureEvent extends InteractionEvent {
  final String pieceId;
  
  GestureEvent({required this.pieceId});
}

/// Drag started event
class DragStartedEvent extends GestureEvent {
  final Offset position;
  
  DragStartedEvent({
    required String pieceId,
    required this.position,
  }) : super(pieceId: pieceId);
}

/// Drag updated event
class DragUpdatedEvent extends GestureEvent {
  final Offset position;
  final double proximity;
  
  DragUpdatedEvent({
    required String pieceId,
    required this.position,
    required this.proximity,
  }) : super(pieceId: pieceId);
}

/// Drag ended event
class DragEndedEvent extends GestureEvent {
  final Velocity velocity;
  final bool wasPlaced;
  
  DragEndedEvent({
    required String pieceId,
    required this.velocity,
    required this.wasPlaced,
  }) : super(pieceId: pieceId);
}

/// Feedback request event
class FeedbackRequestEvent extends InteractionEvent {
  final dynamic pattern;
  final dynamic context;
  
  FeedbackRequestEvent({
    required this.pattern,
    required this.context,
  });
}

/// Piece state changed event
class PieceStateChangedEvent extends InteractionEvent {
  final String pieceId;
  final dynamic newState;
  
  PieceStateChangedEvent({
    required this.pieceId,
    required this.newState,
  });
}

/// Workspace initialized event
class WorkspaceInitializedEvent extends InteractionEvent {
  final String workspaceId;
  final int pieceCount;
  
  WorkspaceInitializedEvent({
    required this.workspaceId,
    required this.pieceCount,
  });
}

/// Puzzle completed event
class PuzzleCompletedEvent extends InteractionEvent {}

/// Performance event
class PerformanceEvent extends InteractionEvent {
  final String componentId;
  final dynamic metrics;
  
  PerformanceEvent({
    required this.componentId,
    required this.metrics,
  });
}

/// Metrics collected event
class MetricsCollectedEvent extends InteractionEvent {
  final Map<String, dynamic> metrics;
  
  MetricsCollectedEvent({
    required this.metrics,
    required DateTime timestamp,
  });
}

/// Configuration change event
class ConfigurationChangeEvent extends InteractionEvent {
  final String section;
  final Map<String, dynamic> changes;
  
  ConfigurationChangeEvent({
    required this.section,
    required this.changes,
  });
}

/// Error event
class ErrorEvent extends InteractionEvent {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;
  
  ErrorEvent({
    required this.message,
    required this.error,
    this.stackTrace,
  });
}

// Flutter-specific types for compilation
class Offset {
  final double dx;
  final double dy;
  
  const Offset(this.dx, this.dy);
  
  double get distance => (dx * dx + dy * dy);
  
  Offset operator -(Offset other) => Offset(dx - other.dx, dy - other.dy);
}

class Velocity {
  final Offset pixelsPerSecond;
  
  const Velocity({required this.pixelsPerSecond});
}
