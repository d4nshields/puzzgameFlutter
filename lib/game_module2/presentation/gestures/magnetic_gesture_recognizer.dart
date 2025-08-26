import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Advanced gesture recognizer with magnetic field influence for puzzle pieces.
/// Provides smooth, intuitive piece manipulation with magnetic assistance.
class MagneticGestureRecognizer extends OneSequenceGestureRecognizer {
  // Track primary pointer for gesture recognition
  int? _primaryPointer;
  /// Callback when a drag starts with magnetic influence.
  GestureDragStartCallback? onStart;
  
  /// Callback for drag updates with magnetic field adjustments.
  GestureDragUpdateCallback? onUpdate;
  
  /// Callback when drag ends, includes momentum data.
  GestureDragEndCallback? onEnd;
  
  /// Callback when drag is cancelled.
  GestureDragCancelCallback? onCancel;
  
  /// Callback for magnetic field influence notifications.
  ValueChanged<MagneticFieldInfluence>? onMagneticInfluence;
  
  /// Callback for multi-touch gesture events.
  ValueChanged<MultiTouchEvent>? onMultiTouch;

  // Configuration parameters
  final MagneticFieldConfiguration _fieldConfig;
  final GestureVelocityTracker _velocityTracker;
  final MomentumPhysics _momentumPhysics;
  final AdaptiveSensitivity _adaptiveSensitivity;
  
  // State tracking
  _DragState? _state;
  Offset? _initialPosition;
  Offset? _pendingDragOffset;
  Offset? _lastPosition;
  int? _lastTimestamp;
  
  // Multi-touch support
  final Map<int, TouchPoint> _activeTouches = {};
  Timer? _multiTouchTimer;
  
  // Performance monitoring
  final _performanceMonitor = _PerformanceMonitor();
  
  // Debug tools
  final _debugger = _GestureDebugger();
  bool _debugMode = false;

  MagneticGestureRecognizer({
    MagneticFieldConfiguration? fieldConfig,
    GestureVelocityTracker? velocityTracker,
    MomentumPhysics? momentumPhysics,
    AdaptiveSensitivity? adaptiveSensitivity,
    bool debugMode = false,
    Object? debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  })  : _fieldConfig = fieldConfig ?? MagneticFieldConfiguration(),
        _velocityTracker = velocityTracker ?? GestureVelocityTracker(),
        _momentumPhysics = momentumPhysics ?? MomentumPhysics(),
        _adaptiveSensitivity = adaptiveSensitivity ?? AdaptiveSensitivity(),
        _debugMode = debugMode,
        super(debugOwner: debugOwner, supportedDevices: supportedDevices);

  @override
  String get debugDescription => 'magnetic gesture';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Set primary pointer
    _primaryPointer = event.pointer;
    
    final stopwatch = Stopwatch()..start();
    
    // Track touch point for multi-touch support
    _activeTouches[event.pointer] = TouchPoint(
      id: event.pointer,
      position: event.position,
      timestamp: event.timeStamp.inMicroseconds,
      pressure: event.pressure,
      deviceKind: event.kind,
    );
    
    // Handle multi-touch gestures
    if (_activeTouches.length > 1) {
      _handleMultiTouch();
    }
    
    // Start tracking with velocity tracker
    _velocityTracker.addPosition(event.timeStamp, event.position);
    
    // Initialize drag state
    _state = _DragState.ready;
    _initialPosition = event.position;
    _pendingDragOffset = Offset.zero;
    _lastPosition = event.position;
    _lastTimestamp = event.timeStamp.inMicroseconds;
    
    // Start gesture in arena
    startTrackingPointer(event.pointer, event.transform);
    
    // Update adaptive sensitivity based on context
    _adaptiveSensitivity.updateContext(
      position: event.position,
      pressure: event.pressure,
      deviceKind: event.kind,
    );
    
    _performanceMonitor.recordGestureEvent(stopwatch.elapsedMicroseconds);
    
    if (_debugMode) {
      _debugger.logPointerDown(event, stopwatch.elapsedMicroseconds);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    final stopwatch = Stopwatch()..start();
    
    assert(_state != null);
    
    if (event is PointerMoveEvent) {
      _handlePointerMove(event);
    } else if (event is PointerUpEvent) {
      _handlePointerUp(event);
    } else if (event is PointerCancelEvent) {
      _handlePointerCancel(event);
    } else if (event is PointerPanZoomUpdateEvent) {
      _handlePanZoomUpdate(event);
    }
    
    _performanceMonitor.recordGestureEvent(stopwatch.elapsedMicroseconds);
    
    if (stopwatch.elapsedMicroseconds > 1000) {
      // Log slow gesture processing
      debugPrint('Warning: Gesture processing took ${stopwatch.elapsedMicroseconds}μs');
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // Update touch point
    if (_activeTouches.containsKey(event.pointer)) {
      _activeTouches[event.pointer] = TouchPoint(
        id: event.pointer,
        position: event.position,
        timestamp: event.timeStamp.inMicroseconds,
        pressure: event.pressure,
        deviceKind: event.kind,
      );
    }
    
    // Add to velocity tracker
    _velocityTracker.addPosition(event.timeStamp, event.position);
    
    final Offset delta = event.delta;
    
    if (_state == _DragState.ready) {
      _pendingDragOffset = _pendingDragOffset! + delta;
      
      // Check if drag threshold is met
      if (_hasSufficientGlobalDistanceToAccept) {
        resolve(GestureDisposition.accepted);
        _startDrag(event);
      }
    } else if (_state == _DragState.accepted) {
      _updateDrag(event);
    }
    
    _lastPosition = event.position;
    _lastTimestamp = event.timeStamp.inMicroseconds;
    
    if (_debugMode) {
      _debugger.logPointerMove(event);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    // Remove touch point
    _activeTouches.remove(event.pointer);
    
    if (_state == _DragState.accepted) {
      _endDrag(event);
    } else {
      stopTrackingPointer(event.pointer);
    }
    
    _reset();
    
    if (_debugMode) {
      _debugger.logPointerUp(event);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activeTouches.remove(event.pointer);
    
    if (_state == _DragState.accepted) {
      _cancelDrag();
    }
    
    stopTrackingPointer(event.pointer);
    _reset();
    
    if (_debugMode) {
      _debugger.logPointerCancel(event);
    }
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    // Handle trackpad/mouse wheel gestures
    if (_state == _DragState.ready) {
      resolve(GestureDisposition.accepted);
      _state = _DragState.accepted;
    }
    
    if (_state == _DragState.accepted) {
      final details = DragUpdateDetails(
        globalPosition: event.position,
        delta: event.panDelta,
        primaryDelta: null,
        localPosition: event.localPosition,
      );
      
      onUpdate?.call(details);
    }
  }

  void _handleMultiTouch() {
    if (_activeTouches.length == 2) {
      final touches = _activeTouches.values.toList();
      final distance = (touches[0].position - touches[1].position).distance;
      
      final multiTouchEvent = MultiTouchEvent(
        type: MultiTouchType.pinch,
        touches: List.from(_activeTouches.values),
        scale: _calculatePinchScale(),
        rotation: _calculateRotation(),
        center: _calculateCenter(),
      );
      
      onMultiTouch?.call(multiTouchEvent);
    } else if (_activeTouches.length > 2) {
      final multiTouchEvent = MultiTouchEvent(
        type: MultiTouchType.multiple,
        touches: List.from(_activeTouches.values),
        scale: 1.0,
        rotation: 0.0,
        center: _calculateCenter(),
      );
      
      onMultiTouch?.call(multiTouchEvent);
    }
  }

  void _startDrag(PointerEvent event) {
    _state = _DragState.accepted;
    
    final details = DragStartDetails(
      globalPosition: _initialPosition!,
      localPosition: event.localPosition,
      sourceTimeStamp: event.timeStamp,
    );
    
    _pendingDragOffset = Offset.zero;
    _lastPosition = details.globalPosition;
    
    onStart?.call(details);
    
    if (_debugMode) {
      _debugger.logDragStart(details);
    }
  }

  void _updateDrag(PointerMoveEvent event) {
    // Apply magnetic field influence
    final magneticOffset = _applyMagneticField(event.position, event.delta);
    
    // Apply adaptive sensitivity
    final sensitivityMultiplier = _adaptiveSensitivity.getSensitivity(
      velocity: _velocityTracker.getVelocity(),
      position: event.position,
    );
    
    // Calculate final delta with magnetic influence and sensitivity
    final adjustedDelta = Offset(
      event.delta.dx * sensitivityMultiplier + magneticOffset.dx,
      event.delta.dy * sensitivityMultiplier + magneticOffset.dy,
    );
    
    // Smooth interpolation for better feel
    final smoothedDelta = _smoothInterpolate(adjustedDelta, event.delta);
    
    final details = DragUpdateDetails(
      globalPosition: event.position,
      delta: smoothedDelta,
      primaryDelta: null,
      localPosition: event.localPosition,
      sourceTimeStamp: event.timeStamp,
    );
    
    onUpdate?.call(details);
    
    // Notify about magnetic field influence if significant
    if (magneticOffset.distance > 0.5) {
      final influence = MagneticFieldInfluence(
        strength: magneticOffset.distance / event.delta.distance,
        direction: magneticOffset,
        source: event.position,
        timestamp: event.timeStamp.inMicroseconds,
      );
      
      onMagneticInfluence?.call(influence);
    }
    
    if (_debugMode) {
      _debugger.logDragUpdate(details, magneticOffset);
    }
  }

  void _endDrag(PointerUpEvent event) {
    final velocity = _velocityTracker.getVelocity();
    
    // Apply momentum physics
    final momentum = _momentumPhysics.calculateMomentum(
      velocity: velocity,
      mass: _adaptiveSensitivity.getEffectiveMass(),
    );
    
    // Determine primary velocity based on the dominant axis
    // primaryVelocity should be null unless movement is primarily along one axis
    double? primaryVelocity;
    if (velocity.pixelsPerSecond.dy == 0 && velocity.pixelsPerSecond.dx != 0) {
      primaryVelocity = velocity.pixelsPerSecond.dx;
    } else if (velocity.pixelsPerSecond.dx == 0 && velocity.pixelsPerSecond.dy != 0) {
      primaryVelocity = velocity.pixelsPerSecond.dy;
    }
    // If movement is along both axes, primaryVelocity remains null
    
    final details = DragEndDetails(
      velocity: velocity,
      primaryVelocity: primaryVelocity,
    );
    
    onEnd?.call(details);
    
    // Start momentum animation if significant
    if (momentum.distance > _momentumPhysics.threshold) {
      _startMomentumAnimation(momentum);
    }
    
    if (_debugMode) {
      _debugger.logDragEnd(details, momentum);
    }
  }

  void _cancelDrag() {
    onCancel?.call();
    
    if (_debugMode) {
      _debugger.logDragCancel();
    }
  }

  Offset _applyMagneticField(Offset position, Offset delta) {
    // Calculate magnetic field influence based on nearby snap points
    final fieldStrength = _fieldConfig.getFieldStrength(position);
    
    if (fieldStrength.distance < _fieldConfig.minimumInfluence) {
      return Offset.zero;
    }
    
    // Apply field gradient
    final gradient = _fieldConfig.calculateGradient(position);
    
    // Calculate magnetic offset
    final magneticOffset = Offset(
      gradient.dx * fieldStrength.distance * _fieldConfig.strength,
      gradient.dy * fieldStrength.distance * _fieldConfig.strength,
    );
    
    // Limit magnetic influence to prevent jarring movements
    final limitedOffset = Offset(
      magneticOffset.dx.clamp(-_fieldConfig.maxInfluence, _fieldConfig.maxInfluence),
      magneticOffset.dy.clamp(-_fieldConfig.maxInfluence, _fieldConfig.maxInfluence),
    );
    
    return limitedOffset;
  }

  Offset _smoothInterpolate(Offset adjusted, Offset original) {
    // Use cubic interpolation for smooth transitions
    const double smoothingFactor = 0.7;
    
    return Offset(
      _cubicInterpolate(original.dx, adjusted.dx, smoothingFactor),
      _cubicInterpolate(original.dy, adjusted.dy, smoothingFactor),
    );
  }

  double _cubicInterpolate(double a, double b, double t) {
    final double t2 = t * t;
    final double t3 = t2 * t;
    return a + (b - a) * (3.0 * t2 - 2.0 * t3);
  }

  void _startMomentumAnimation(Offset momentum) {
    // This would typically trigger an animation controller
    // For now, we'll just notify through a callback
    if (_debugMode) {
      _debugger.logMomentum(momentum);
    }
  }

  bool get _hasSufficientGlobalDistanceToAccept {
    final distance = _pendingDragOffset!.distance;
    // Use kTouchSlop as default threshold
    const double kDefaultTouchSlop = 18.0;
    return distance > kDefaultTouchSlop;
  }

  double _calculatePinchScale() {
    if (_activeTouches.length != 2) return 1.0;
    
    final touches = _activeTouches.values.toList();
    final currentDistance = (touches[0].position - touches[1].position).distance;
    
    // Would need to track initial distance for proper scale
    return 1.0; // Simplified for now
  }

  double _calculateRotation() {
    if (_activeTouches.length != 2) return 0.0;
    
    final touches = _activeTouches.values.toList();
    final vector = touches[1].position - touches[0].position;
    return math.atan2(vector.dy, vector.dx);
  }

  Offset _calculateCenter() {
    if (_activeTouches.isEmpty) return Offset.zero;
    
    var sumX = 0.0;
    var sumY = 0.0;
    
    for (final touch in _activeTouches.values) {
      sumX += touch.position.dx;
      sumY += touch.position.dy;
    }
    
    return Offset(sumX / _activeTouches.length, sumY / _activeTouches.length);
  }

  void _reset() {
    _state = null;
    _initialPosition = null;
    _pendingDragOffset = null;
    _lastPosition = null;
    _lastTimestamp = null;
    _primaryPointer = null;
    _velocityTracker.reset();
    _multiTouchTimer?.cancel();
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    _reset();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    // Clean up when we stop tracking the last pointer
    if (_state == _DragState.accepted) {
      // If we were in the middle of a drag, cancel it
      _cancelDrag();
    }
    _reset();
  }

  @override
  void acceptGesture(int pointer) {
    // Gesture has been accepted
    if (_state == _DragState.ready) {
      _state = _DragState.accepted;
    }
  }

  @override
  void dispose() {
    _multiTouchTimer?.cancel();
    _activeTouches.clear();
    _performanceMonitor.dispose();
    _debugger.dispose();
    super.dispose();
  }

  /// Enable or disable debug mode.
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    _debugger.setEnabled(enabled);
  }

  /// Get performance metrics.
  PerformanceMetrics getPerformanceMetrics() {
    return _performanceMonitor.getMetrics();
  }

  /// Export debug logs.
  List<GestureDebugEvent> exportDebugLogs() {
    return _debugger.exportLogs();
  }
}

/// Drag state enum.
enum _DragState {
  ready,
  accepted,
}

/// Configuration for magnetic field behavior.
class MagneticFieldConfiguration {
  /// Base strength of the magnetic field (0.0 to 1.0).
  final double strength;
  
  /// Minimum distance for field influence to activate.
  final double minimumInfluence;
  
  /// Maximum influence offset in logical pixels.
  final double maxInfluence;
  
  /// Field falloff curve type.
  final FieldFalloffType falloffType;
  
  /// Snap points that generate magnetic fields.
  final List<MagneticSnapPoint> snapPoints;

  MagneticFieldConfiguration({
    this.strength = 0.3,
    this.minimumInfluence = 0.1,
    this.maxInfluence = 5.0,
    this.falloffType = FieldFalloffType.quadratic,
    this.snapPoints = const [],
  });

  /// Calculate field strength at a position.
  Offset getFieldStrength(Offset position) {
    if (snapPoints.isEmpty) return Offset.zero;
    
    Offset totalField = Offset.zero;
    
    for (final snapPoint in snapPoints) {
      final distance = (position - snapPoint.position).distance;
      
      if (distance < snapPoint.radius) {
        final normalizedDistance = distance / snapPoint.radius;
        final falloff = _calculateFalloff(normalizedDistance);
        final direction = (snapPoint.position - position) / distance;
        
        totalField += direction * falloff * snapPoint.strength;
      }
    }
    
    return totalField;
  }

  /// Calculate field gradient at a position.
  Offset calculateGradient(Offset position) {
    const double delta = 0.1;
    
    final fx1 = getFieldStrength(position + const Offset(delta, 0));
    final fx2 = getFieldStrength(position - const Offset(delta, 0));
    final fy1 = getFieldStrength(position + const Offset(0, delta));
    final fy2 = getFieldStrength(position - const Offset(0, delta));
    
    return Offset(
      (fx1.distance - fx2.distance) / (2 * delta),
      (fy1.distance - fy2.distance) / (2 * delta),
    );
  }

  double _calculateFalloff(double normalizedDistance) {
    switch (falloffType) {
      case FieldFalloffType.linear:
        return 1.0 - normalizedDistance;
      case FieldFalloffType.quadratic:
        return math.pow(1.0 - normalizedDistance, 2).toDouble();
      case FieldFalloffType.cubic:
        return math.pow(1.0 - normalizedDistance, 3).toDouble();
      case FieldFalloffType.exponential:
        return math.exp(-normalizedDistance * 3);
    }
  }
}

/// Types of field falloff curves.
enum FieldFalloffType {
  linear,
  quadratic,
  cubic,
  exponential,
}

/// Represents a magnetic snap point in the field.
class MagneticSnapPoint {
  final Offset position;
  final double radius;
  final double strength;

  const MagneticSnapPoint({
    required this.position,
    this.radius = 50.0,
    this.strength = 1.0,
  });
}

/// Tracks gesture velocity with high precision.
class GestureVelocityTracker {
  static const int _historySize = 20;
  static const int _minimumSampleSize = 3;
  
  final _samples = ListQueue<_VelocitySample>(_historySize);

  void addPosition(Duration time, Offset position) {
    final sample = _VelocitySample(time.inMicroseconds, position);
    
    if (_samples.length >= _historySize) {
      _samples.removeFirst();
    }
    
    _samples.add(sample);
  }

  Velocity getVelocity() {
    if (_samples.length < _minimumSampleSize) {
      return Velocity.zero;
    }
    
    // Use least squares regression for velocity calculation
    final regression = _calculateRegression();
    
    return Velocity(
      pixelsPerSecond: regression, // Already in pixels per second
    );
  }

  Offset _calculateRegression() {
    double sumX = 0, sumY = 0, sumT = 0;
    double sumTX = 0, sumTY = 0, sumT2 = 0;
    
    final firstTime = _samples.first.timestamp;
    
    for (final sample in _samples) {
      final t = (sample.timestamp - firstTime) / 1000000.0; // Convert microseconds to seconds
      sumX += sample.position.dx;
      sumY += sample.position.dy;
      sumT += t;
      sumTX += t * sample.position.dx;
      sumTY += t * sample.position.dy;
      sumT2 += t * t;
    }
    
    final n = _samples.length.toDouble();
    final denominator = n * sumT2 - sumT * sumT;
    
    if (denominator.abs() < 0.0000001) {
      return Offset.zero;
    }
    
    final slopeX = (n * sumTX - sumT * sumX) / denominator;
    final slopeY = (n * sumTY - sumT * sumY) / denominator;
    
    // slopeX and slopeY are already in pixels per second
    return Offset(slopeX, slopeY);
  }

  void reset() {
    _samples.clear();
  }
}

class _VelocitySample {
  final int timestamp;
  final Offset position;

  _VelocitySample(this.timestamp, this.position);
}

/// Physics engine for momentum calculations.
class MomentumPhysics {
  final double friction;
  final double mass;
  final double threshold;

  MomentumPhysics({
    this.friction = 0.15,
    this.mass = 1.0,
    this.threshold = 10.0,
  });

  Offset calculateMomentum({
    required Velocity velocity,
    double? mass,
  }) {
    final effectiveMass = mass ?? this.mass;
    final speed = velocity.pixelsPerSecond.distance;
    
    if (speed < threshold) {
      return Offset.zero;
    }
    
    // Apply friction to calculate final momentum
    final momentumMagnitude = speed * effectiveMass * (1.0 - friction);
    final direction = velocity.pixelsPerSecond / speed;
    
    return direction * momentumMagnitude;
  }
}

/// Adaptive sensitivity based on context.
class AdaptiveSensitivity {
  double _baseSensitivity = 1.0;
  double _velocityFactor = 1.0;
  double _pressureFactor = 1.0;
  double _effectiveMass = 1.0;
  
  void updateContext({
    required Offset position,
    required double pressure,
    required PointerDeviceKind deviceKind,
  }) {
    // Adjust sensitivity based on device type
    switch (deviceKind) {
      case PointerDeviceKind.touch:
        _baseSensitivity = 1.0;
        _effectiveMass = 0.8;
        break;
      case PointerDeviceKind.stylus:
        _baseSensitivity = 1.2;
        _effectiveMass = 0.6;
        break;
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.trackpad:
        _baseSensitivity = 0.8;
        _effectiveMass = 1.2;
        break;
      default:
        _baseSensitivity = 1.0;
        _effectiveMass = 1.0;
    }
    
    // Adjust based on pressure (for pressure-sensitive devices)
    _pressureFactor = 0.7 + (pressure * 0.6);
  }

  double getSensitivity({
    required Velocity? velocity,
    required Offset position,
  }) {
    // Adjust sensitivity based on velocity
    if (velocity != null) {
      final speed = velocity.pixelsPerSecond.distance;
      
      // Reduce sensitivity at high speeds for better control
      if (speed > 1000) {
        _velocityFactor = 0.7;
      } else if (speed > 500) {
        _velocityFactor = 0.85;
      } else {
        _velocityFactor = 1.0;
      }
    }
    
    return _baseSensitivity * _velocityFactor * _pressureFactor;
  }

  double getEffectiveMass() => _effectiveMass;
}

/// Represents a touch point for multi-touch tracking.
class TouchPoint {
  final int id;
  final Offset position;
  final int timestamp;
  final double pressure;
  final PointerDeviceKind deviceKind;

  TouchPoint({
    required this.id,
    required this.position,
    required this.timestamp,
    required this.pressure,
    required this.deviceKind,
  });
}

/// Multi-touch event data.
class MultiTouchEvent {
  final MultiTouchType type;
  final List<TouchPoint> touches;
  final double scale;
  final double rotation;
  final Offset center;

  MultiTouchEvent({
    required this.type,
    required this.touches,
    required this.scale,
    required this.rotation,
    required this.center,
  });
}

/// Types of multi-touch gestures.
enum MultiTouchType {
  pinch,
  rotate,
  multiple,
}

/// Magnetic field influence data.
class MagneticFieldInfluence {
  final double strength;
  final Offset direction;
  final Offset source;
  final int timestamp;

  MagneticFieldInfluence({
    required this.strength,
    required this.direction,
    required this.source,
    required this.timestamp,
  });
}

/// Performance monitoring for gesture processing.
class _PerformanceMonitor {
  final _eventTimes = ListQueue<int>();
  static const int _maxEventTimes = 1000;
  int _eventCount = 0;
  int _totalProcessingTime = 0;
  int _maxProcessingTime = 0;
  
  void recordGestureEvent(int microseconds) {
    // Maintain max size manually
    if (_eventTimes.length >= _maxEventTimes) {
      _eventTimes.removeFirst();
    }
    _eventTimes.add(microseconds);
    _eventCount++;
    _totalProcessingTime += microseconds;
    
    if (microseconds > _maxProcessingTime) {
      _maxProcessingTime = microseconds;
    }
  }

  PerformanceMetrics getMetrics() {
    final averageTime = _eventCount > 0 
        ? _totalProcessingTime / _eventCount 
        : 0.0;
    
    return PerformanceMetrics(
      eventCount: _eventCount,
      averageProcessingTime: averageTime,
      maxProcessingTime: _maxProcessingTime,
      droppedEvents: 0, // Would need actual tracking
      samplingRate: _calculateSamplingRate(),
    );
  }

  double _calculateSamplingRate() {
    if (_eventTimes.length < 2) return 0.0;
    
    final duration = _eventTimes.last - _eventTimes.first;
    if (duration == 0) return 0.0;
    
    return (_eventTimes.length * 1000000.0) / duration; // Hz
  }

  void dispose() {
    _eventTimes.clear();
  }
}

/// Performance metrics for gesture processing.
class PerformanceMetrics {
  final int eventCount;
  final double averageProcessingTime; // microseconds
  final int maxProcessingTime; // microseconds
  final int droppedEvents;
  final double samplingRate; // Hz

  PerformanceMetrics({
    required this.eventCount,
    required this.averageProcessingTime,
    required this.maxProcessingTime,
    required this.droppedEvents,
    required this.samplingRate,
  });

  @override
  String toString() {
    return 'PerformanceMetrics('
        'events: $eventCount, '
        'avg: ${averageProcessingTime.toStringAsFixed(1)}μs, '
        'max: ${maxProcessingTime}μs, '
        'dropped: $droppedEvents, '
        'rate: ${samplingRate.toStringAsFixed(1)}Hz)';
  }
}

/// Debug tools for gesture analysis.
class _GestureDebugger {
  bool _enabled = false;
  final _debugEvents = ListQueue<GestureDebugEvent>();
  static const int _maxDebugEvents = 500;
  
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _debugEvents.clear();
    }
  }

  void logPointerDown(PointerDownEvent event, int processingTime) {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'pointer_down',
      timestamp: DateTime.now(),
      position: event.position,
      data: {
        'pressure': event.pressure,
        'device': event.kind.toString(),
        'processing_time': processingTime,
      },
    ));
  }

  void logPointerMove(PointerMoveEvent event) {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'pointer_move',
      timestamp: DateTime.now(),
      position: event.position,
      data: {
        'delta': event.delta.toString(),
        'pressure': event.pressure,
      },
    ));
  }

  void logPointerUp(PointerUpEvent event) {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'pointer_up',
      timestamp: DateTime.now(),
      position: event.position,
      data: {},
    ));
  }

  void logPointerCancel(PointerCancelEvent event) {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'pointer_cancel',
      timestamp: DateTime.now(),
      position: event.position,
      data: {},
    ));
  }

  void logDragStart(DragStartDetails details) {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'drag_start',
      timestamp: DateTime.now(),
      position: details.globalPosition,
      data: {
        'local': details.localPosition.toString(),
      },
    ));
  }

  void logDragUpdate(DragUpdateDetails details, Offset magneticOffset) {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'drag_update',
      timestamp: DateTime.now(),
      position: details.globalPosition,
      data: {
        'delta': details.delta.toString(),
        'magnetic_offset': magneticOffset.toString(),
      },
    ));
  }

  void logDragEnd(DragEndDetails details, Offset momentum) {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'drag_end',
      timestamp: DateTime.now(),
      position: Offset.zero,
      data: {
        'velocity': details.velocity.toString(),
        'momentum': momentum.toString(),
      },
    ));
  }

  void logDragCancel() {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'drag_cancel',
      timestamp: DateTime.now(),
      position: Offset.zero,
      data: {},
    ));
  }

  void logMomentum(Offset momentum) {
    if (!_enabled) return;
    
    // Maintain max size manually
    if (_debugEvents.length >= _maxDebugEvents) {
      _debugEvents.removeFirst();
    }
    
    _debugEvents.add(GestureDebugEvent(
      type: 'momentum',
      timestamp: DateTime.now(),
      position: Offset.zero,
      data: {
        'momentum': momentum.toString(),
      },
    ));
  }

  List<GestureDebugEvent> exportLogs() {
    return _debugEvents.toList();
  }

  void dispose() {
    _debugEvents.clear();
  }
}

/// Debug event for gesture analysis.
class GestureDebugEvent {
  final String type;
  final DateTime timestamp;
  final Offset position;
  final Map<String, dynamic> data;

  GestureDebugEvent({
    required this.type,
    required this.timestamp,
    required this.position,
    required this.data,
  });

  @override
  String toString() {
    return 'GestureDebugEvent($type at ${timestamp.toIso8601String()}, '
        'pos: $position, data: $data)';
  }
}
