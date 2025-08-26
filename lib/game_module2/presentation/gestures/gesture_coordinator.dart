import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Main gesture coordination system for managing all input types.
/// Handles gesture conflicts, priorities, composition, and accessibility.
class GestureCoordinator {
  // Singleton instance
  static final GestureCoordinator _instance = GestureCoordinator._internal();
  factory GestureCoordinator() => _instance;
  GestureCoordinator._internal();

  // Core components
  final _gestureArena = GestureArena();
  final _gestureSequencer = GestureSequencer();
  final _accessibilityAdapter = AccessibilityGestureAdapter();
  final _gestureRecorder = GestureRecorder();
  final _inputManager = UnifiedInputManager();
  final _customizationManager = GestureCustomizationManager();

  // Active gestures and state
  final Set<GestureType> _enabledGestures = Set.from(GestureType.values);
  
  // Callbacks
  final _gestureCallbacks = <GestureType, List<GestureCallback>>{};
  final _conflictResolvers = <ConflictResolver>[];
  
  // Platform-specific optimizations
  PlatformOptimizer? _platformOptimizer;
  
  // Debug and metrics
  bool _debugMode = false;
  final _metrics = GestureMetrics();

  /// Initialize the gesture coordinator.
  Future<void> initialize({
    required BuildContext context,
    GestureConfiguration? config,
  }) async {
    // Initialize platform-specific optimizations only if not already initialized
    _platformOptimizer ??= PlatformOptimizer(
      platform: defaultTargetPlatform,
    );
    
    // Apply configuration
    if (config != null) {
      _customizationManager.applyConfiguration(config);
    }
    
    // Initialize input systems
    await _inputManager.initialize();
    
    // Set up accessibility
    await _accessibilityAdapter.initialize(context);
    
    // Start recording if enabled
    if (config?.recordGestures ?? false) {
      _gestureRecorder.startRecording();
    }
  }

  /// Register a gesture recognizer with the coordinator.
  void registerGesture({
    required GestureType type,
    required GestureRecognizer recognizer,
    int priority = 0,
    GestureCallback? callback,
  }) {
    final gesture = ActiveGesture(
      type: type,
      recognizer: recognizer,
      priority: priority,
      callback: callback,
    );
    
    _gestureArena.addGesture(gesture);
    
    if (callback != null) {
      _gestureCallbacks.putIfAbsent(type, () => []).add(callback);
    }
    
    if (_debugMode) {
      debugPrint('Registered gesture: $type with priority $priority');
    }
  }

  /// Handle an incoming pointer event.
  void handlePointerEvent(PointerEvent event) {
    final stopwatch = Stopwatch()..start();
    
    // Record event if recording
    if (_gestureRecorder.isRecording) {
      _gestureRecorder.recordPointerEvent(event);
    }
    
    // Check for accessibility override
    if (_accessibilityAdapter.shouldOverride(event)) {
      _accessibilityAdapter.handlePointerEvent(event);
      return;
    }
    
    // Process through gesture arena
    _gestureArena.handlePointerEvent(event);
    
    // Update metrics
    _metrics.recordEventProcessing(stopwatch.elapsedMicroseconds);
  }

  /// Handle keyboard input.
  void handleKeyEvent(KeyEvent event) {
    _inputManager.handleKeyEvent(event);
    
    if (_gestureRecorder.isRecording) {
      _gestureRecorder.recordKeyEvent(event);
    }
  }

  /// Handle gamepad input.
  void handleGamepadEvent(GamepadEvent event) {
    _inputManager.handleGamepadEvent(event);
    
    if (_gestureRecorder.isRecording) {
      _gestureRecorder.recordGamepadEvent(event);
    }
  }

  /// Compose multiple gestures into a complex gesture.
  ComposedGesture composeGestures({
    required List<GestureType> types,
    required ComposedGestureCallback callback,
  }) {
    return _gestureSequencer.composeGestures(
      types: types,
      callback: callback,
    );
  }

  /// Add a conflict resolver.
  void addConflictResolver(ConflictResolver resolver) {
    _conflictResolvers.add(resolver);
    _gestureArena.addConflictResolver(resolver);
  }

  /// Enable or disable specific gesture types.
  void setGestureEnabled(GestureType type, bool enabled) {
    if (enabled) {
      _enabledGestures.add(type);
    } else {
      _enabledGestures.remove(type);
    }
  }

  /// Get current gesture customization.
  GestureCustomization getCustomization() {
    return _customizationManager.currentCustomization;
  }

  /// Apply gesture customization.
  void applyCustomization(GestureCustomization customization) {
    _customizationManager.applyCustomization(customization);
  }

  /// Start recording gestures.
  void startRecording() {
    _gestureRecorder.startRecording();
  }

  /// Stop recording and get recorded gestures.
  RecordedGestures stopRecording() {
    return _gestureRecorder.stopRecording();
  }

  /// Replay recorded gestures.
  Future<void> replayGestures(RecordedGestures gestures) async {
    await _gestureRecorder.replay(gestures, onEvent: handlePointerEvent);
  }

  /// Get current metrics.
  GestureMetrics getMetrics() => _metrics.clone();

  /// Enable or disable debug mode.
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    _gestureArena.setDebugMode(enabled);
  }

  /// Dispose of resources.
  void dispose() {
    _gestureArena.dispose();
    _gestureSequencer.dispose();
    _accessibilityAdapter.dispose();
    _gestureRecorder.dispose();
    _inputManager.dispose();
  }
}

/// Gesture arena for managing gesture conflicts and priorities.
class GestureArena {
  final Map<int, _GestureEntry> _entries = {};
  final List<ConflictResolver> _resolvers = [];
  bool _debugMode = false;
  
  /// Add a gesture to the arena.
  void addGesture(ActiveGesture gesture) {
    _entries[gesture.hashCode] = _GestureEntry(gesture);
  }

  /// Handle a pointer event.
  void handlePointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _handlePointerDown(event);
    } else if (event is PointerMoveEvent) {
      _handlePointerMove(event);
    } else if (event is PointerUpEvent) {
      _handlePointerUp(event);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Find eligible gestures
    final eligible = <_GestureEntry>[];
    
    for (final entry in _entries.values) {
      final recognizer = entry.gesture.recognizer;
      if (recognizer is OneSequenceGestureRecognizer ||
          recognizer is MultiDragGestureRecognizer ||
          recognizer is TapGestureRecognizer ||
          recognizer is DoubleTapGestureRecognizer ||
          recognizer is LongPressGestureRecognizer ||
          recognizer is PanGestureRecognizer ||
          recognizer is ScaleGestureRecognizer) {
        eligible.add(entry);
      }
    }
    
    // Sort by priority
    eligible.sort((a, b) => b.gesture.priority.compareTo(a.gesture.priority));
    
    if (_debugMode) {
      debugPrint('Arena: ${eligible.length} gestures competing for pointer ${event.pointer}');
    }
    
    // Check for conflicts
    if (eligible.length > 1) {
      _resolveConflicts(eligible, event);
    }
    
    // Dispatch to eligible gestures
    for (final entry in eligible) {
      if (entry.isActive) {
        final recognizer = entry.gesture.recognizer;
        if (recognizer is TapGestureRecognizer) {
          recognizer.addPointer(event);
        } else if (recognizer is DoubleTapGestureRecognizer) {
          recognizer.addPointer(event);
        } else if (recognizer is LongPressGestureRecognizer) {
          recognizer.addPointer(event);
        } else if (recognizer is PanGestureRecognizer) {
          recognizer.addPointer(event);
        } else if (recognizer is ScaleGestureRecognizer) {
          recognizer.addPointer(event);
        } else if (recognizer is MultiDragGestureRecognizer) {
          recognizer.addPointer(event);
        } else if (recognizer is OneSequenceGestureRecognizer) {
          // For other OneSequenceGestureRecognizers, use reflection or skip
          // Since addAllowedPointer is protected, we can't call it directly
          recognizer.addPointer(event);
        }
        // Track pointer for this gesture
        entry.startTracking(event.pointer);
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // Dispatch to active gestures
    for (final entry in _entries.values) {
      if (entry.isActive && entry.isTracking(event.pointer)) {
        // Only certain recognizers have handleEvent method
        // For others, we need to handle differently
        final recognizer = entry.gesture.recognizer;
        if (recognizer is OneSequenceGestureRecognizer) {
          // OneSequenceGestureRecognizer handles events internally
          // through the pointer router, not directly
        } else if (recognizer is MultiDragGestureRecognizer) {
          // MultiDragGestureRecognizer also uses pointer router
        }
        // The recognizer will receive events through the pointer router
        // which was set up when we called addAllowedPointer
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    // Dispatch to active gestures
    for (final entry in _entries.values) {
      if (entry.isActive && entry.isTracking(event.pointer)) {
        // Similar to move, recognizers handle events through pointer router
        final recognizer = entry.gesture.recognizer;
        if (recognizer is OneSequenceGestureRecognizer) {
          // Already tracking through pointer router
        }
      }
    }
  }

  void _resolveConflicts(List<_GestureEntry> eligible, PointerDownEvent event) {
    // Use custom resolvers first
    for (final resolver in _resolvers) {
      final resolution = resolver(
        eligible.map((e) => e.gesture).toList(),
        event,
      );
      
      if (resolution != null) {
        // Apply resolution
        for (final entry in eligible) {
          if (!resolution.allowedGestures.contains(entry.gesture.type)) {
            entry.isActive = false;
          }
        }
        return;
      }
    }
    
    // Default resolution: highest priority wins
    if (eligible.isNotEmpty) {
      for (int i = 1; i < eligible.length; i++) {
        if (eligible[i].gesture.priority < eligible[0].gesture.priority) {
          eligible[i].isActive = false;
        }
      }
    }
  }

  /// Add a conflict resolver.
  void addConflictResolver(ConflictResolver resolver) {
    _resolvers.add(resolver);
  }

  /// Set debug mode.
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  /// Dispose of resources.
  void dispose() {
    _entries.clear();
    _resolvers.clear();
  }
}

/// Entry in the gesture arena.
class _GestureEntry {
  final ActiveGesture gesture;
  bool isActive = true;
  final Set<int> _trackingPointers = {};

  _GestureEntry(this.gesture);

  bool isTracking(int pointer) => _trackingPointers.contains(pointer);
  void startTracking(int pointer) => _trackingPointers.add(pointer);
  void stopTracking(int pointer) => _trackingPointers.remove(pointer);
}

/// Gesture sequencer for managing complex gesture combinations.
class GestureSequencer {
  final List<_SequenceEntry> _sequences = [];
  final Map<String, ComposedGesture> _composedGestures = {};
  
  /// Compose multiple gestures into a complex gesture.
  ComposedGesture composeGestures({
    required List<GestureType> types,
    required ComposedGestureCallback callback,
  }) {
    final id = types.map((t) => t.toString()).join('_');
    
    if (_composedGestures.containsKey(id)) {
      return _composedGestures[id]!;
    }
    
    final composed = ComposedGesture(
      id: id,
      types: types,
      callback: callback,
    );
    
    _composedGestures[id] = composed;
    
    // Create sequence entry
    _sequences.add(_SequenceEntry(
      gestures: types,
      callback: callback,
      composed: composed,
    ));
    
    return composed;
  }

  /// Check if a sequence is being performed.
  void checkSequence(GestureType type, GestureState state) {
    for (final sequence in _sequences) {
      sequence.update(type, state);
      
      if (sequence.isComplete) {
        sequence.callback(sequence.composed);
        sequence.reset();
      }
    }
  }

  /// Dispose of resources.
  void dispose() {
    _sequences.clear();
    _composedGestures.clear();
  }
}

/// Entry for tracking gesture sequences.
class _SequenceEntry {
  final List<GestureType> gestures;
  final ComposedGestureCallback callback;
  final ComposedGesture composed;
  int _currentIndex = 0;
  DateTime? _lastGestureTime;
  
  static const _sequenceTimeout = Duration(milliseconds: 500);

  _SequenceEntry({
    required this.gestures,
    required this.callback,
    required this.composed,
  });

  void update(GestureType type, GestureState state) {
    if (state != GestureState.recognized) return;
    
    // Check timeout
    if (_lastGestureTime != null) {
      if (DateTime.now().difference(_lastGestureTime!) > _sequenceTimeout) {
        reset();
      }
    }
    
    // Check if this is the expected gesture
    if (_currentIndex < gestures.length && gestures[_currentIndex] == type) {
      _currentIndex++;
      _lastGestureTime = DateTime.now();
    } else {
      reset();
    }
  }

  bool get isComplete => _currentIndex >= gestures.length;

  void reset() {
    _currentIndex = 0;
    _lastGestureTime = null;
  }
}

/// Accessibility gesture adapter for supporting assistive technologies.
class AccessibilityGestureAdapter {
  BuildContext? _context;
  bool _voiceOverEnabled = false;
  bool _switchControlEnabled = false;
  
  // Accessibility gesture mappings
  final Map<AccessibilityGesture, VoidCallback> _gestureMap = {};
  
  /// Initialize accessibility support.
  Future<void> initialize(BuildContext context) async {
    _context = context;
    
    // Check accessibility settings
    final mediaQuery = MediaQuery.of(context);
    _voiceOverEnabled = mediaQuery.accessibleNavigation;
    
    // Platform-specific initialization
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _initializeiOSAccessibility();
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await _initializeAndroidAccessibility();
    }
  }

  Future<void> _initializeiOSAccessibility() async {
    // iOS-specific accessibility setup
    // VoiceOver, Switch Control, etc.
  }

  Future<void> _initializeAndroidAccessibility() async {
    // Android-specific accessibility setup
    // TalkBack, Switch Access, etc.
  }

  /// Check if accessibility should override normal gestures.
  bool shouldOverride(PointerEvent event) {
    if (!_voiceOverEnabled && !_switchControlEnabled) {
      return false;
    }
    
    // Check for accessibility-specific gestures
    if (_voiceOverEnabled) {
      // VoiceOver uses different gesture patterns
      return _isVoiceOverGesture(event);
    }
    
    if (_switchControlEnabled) {
      // Switch control has specific requirements
      return _isSwitchControlGesture(event);
    }
    
    return false;
  }

  bool _isVoiceOverGesture(PointerEvent event) {
    // VoiceOver typically uses:
    // - Single tap to focus
    // - Double tap to activate
    // - Three-finger swipe for navigation
    return false; // Simplified for now
  }

  bool _isSwitchControlGesture(PointerEvent event) {
    // Switch control uses simplified input
    return false; // Simplified for now
  }

  /// Handle pointer event with accessibility adaptations.
  void handlePointerEvent(PointerEvent event) {
    if (_voiceOverEnabled) {
      _handleVoiceOverEvent(event);
    } else if (_switchControlEnabled) {
      _handleSwitchControlEvent(event);
    }
  }

  void _handleVoiceOverEvent(PointerEvent event) {
    // Transform event for VoiceOver
    // This would integrate with the platform's accessibility API
  }

  void _handleSwitchControlEvent(PointerEvent event) {
    // Handle switch control input
  }

  /// Register an accessibility gesture.
  void registerGesture(AccessibilityGesture gesture, VoidCallback callback) {
    _gestureMap[gesture] = callback;
  }

  /// Announce a message for screen readers.
  void announce(String message, {TextDirection? textDirection}) {
    if (_context != null) {
      SemanticsService.announce(message, textDirection ?? TextDirection.ltr);
    }
  }

  /// Dispose of resources.
  void dispose() {
    _gestureMap.clear();
  }
}

/// Gesture recorder for recording and replaying gesture sequences.
class GestureRecorder {
  bool _isRecording = false;
  final _recordedEvents = <RecordedEvent>[];
  DateTime? _recordingStartTime;
  
  /// Check if recording is active.
  bool get isRecording => _isRecording;

  /// Start recording gestures.
  void startRecording() {
    _isRecording = true;
    _recordedEvents.clear();
    _recordingStartTime = DateTime.now();
  }

  /// Stop recording and return recorded gestures.
  RecordedGestures stopRecording() {
    _isRecording = false;
    
    final gestures = RecordedGestures(
      events: List.from(_recordedEvents),
      duration: _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero,
    );
    
    _recordedEvents.clear();
    _recordingStartTime = null;
    
    return gestures;
  }

  /// Record a pointer event.
  void recordPointerEvent(PointerEvent event) {
    if (!_isRecording || _recordingStartTime == null) return;
    
    _recordedEvents.add(RecordedEvent.pointer(
      timestamp: DateTime.now().difference(_recordingStartTime!),
      event: event,
    ));
  }

  /// Record a key event.
  void recordKeyEvent(KeyEvent event) {
    if (!_isRecording || _recordingStartTime == null) return;
    
    _recordedEvents.add(RecordedEvent.key(
      timestamp: DateTime.now().difference(_recordingStartTime!),
      event: event,
    ));
  }

  /// Record a gamepad event.
  void recordGamepadEvent(GamepadEvent event) {
    if (!_isRecording || _recordingStartTime == null) return;
    
    _recordedEvents.add(RecordedEvent.gamepad(
      timestamp: DateTime.now().difference(_recordingStartTime!),
      event: event,
    ));
  }

  /// Replay recorded gestures.
  Future<void> replay(
    RecordedGestures gestures, {
    required Function(PointerEvent) onEvent,
    double speed = 1.0,
  }) async {
    final events = gestures.events;
    if (events.isEmpty) return;
    
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      
      // Wait for the appropriate time
      if (i > 0) {
        final delay = event.timestamp - events[i - 1].timestamp;
        await Future.delayed(Duration(milliseconds: (delay.inMilliseconds ~/ speed).toInt()));
      }
      
      // Dispatch event
      if (event.type == RecordedEventType.pointer) {
        onEvent(event.pointerEvent!);
      }
      // Handle other event types as needed
    }
  }

  /// Dispose of resources.
  void dispose() {
    _recordedEvents.clear();
  }
}

/// Unified input manager for keyboard and gamepad support.
class UnifiedInputManager {
  // Input mappings
  final Map<LogicalKeyboardKey, GestureAction> _keyMappings = {};
  final Map<GamepadButton, GestureAction> _gamepadMappings = {};
  
  // Callbacks
  final Map<GestureAction, VoidCallback> _actionCallbacks = {};
  
  // State tracking
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final Set<GamepadButton> _pressedButtons = {};
  
  /// Initialize the input manager.
  Future<void> initialize() async {
    // Set up default key mappings
    _setupDefaultKeyMappings();
    
    // Set up default gamepad mappings
    _setupDefaultGamepadMappings();
  }

  void _setupDefaultKeyMappings() {
    // Arrow keys for movement
    _keyMappings[LogicalKeyboardKey.arrowUp] = GestureAction.moveUp;
    _keyMappings[LogicalKeyboardKey.arrowDown] = GestureAction.moveDown;
    _keyMappings[LogicalKeyboardKey.arrowLeft] = GestureAction.moveLeft;
    _keyMappings[LogicalKeyboardKey.arrowRight] = GestureAction.moveRight;
    
    // Space/Enter for selection
    _keyMappings[LogicalKeyboardKey.space] = GestureAction.select;
    _keyMappings[LogicalKeyboardKey.enter] = GestureAction.select;
    
    // Escape for cancel
    _keyMappings[LogicalKeyboardKey.escape] = GestureAction.cancel;
    
    // Tab for navigation
    _keyMappings[LogicalKeyboardKey.tab] = GestureAction.nextFocus;
  }

  void _setupDefaultGamepadMappings() {
    // D-pad for movement
    _gamepadMappings[GamepadButton.dpadUp] = GestureAction.moveUp;
    _gamepadMappings[GamepadButton.dpadDown] = GestureAction.moveDown;
    _gamepadMappings[GamepadButton.dpadLeft] = GestureAction.moveLeft;
    _gamepadMappings[GamepadButton.dpadRight] = GestureAction.moveRight;
    
    // A button for selection
    _gamepadMappings[GamepadButton.buttonA] = GestureAction.select;
    
    // B button for cancel
    _gamepadMappings[GamepadButton.buttonB] = GestureAction.cancel;
    
    // Shoulder buttons for rotation
    _gamepadMappings[GamepadButton.leftShoulder] = GestureAction.rotateLeft;
    _gamepadMappings[GamepadButton.rightShoulder] = GestureAction.rotateRight;
  }

  /// Handle a keyboard event.
  void handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _handleKeyDown(event);
    } else if (event is KeyUpEvent) {
      _handleKeyUp(event);
    }
  }

  void _handleKeyDown(KeyDownEvent event) {
    final key = event.logicalKey;
    
    if (_pressedKeys.contains(key)) return;
    _pressedKeys.add(key);
    
    // Check for mapped action
    final action = _keyMappings[key];
    if (action != null) {
      _triggerAction(action);
    }
    
    // Check for key combinations
    _checkKeyboardCombinations();
  }

  void _handleKeyUp(KeyUpEvent event) {
    _pressedKeys.remove(event.logicalKey);
  }

  void _checkKeyboardCombinations() {
    // Check for Ctrl+Z (undo)
    if (_pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.controlRight)) {
      if (_pressedKeys.contains(LogicalKeyboardKey.keyZ)) {
        _triggerAction(GestureAction.undo);
      }
    }
  }

  /// Handle a gamepad event.
  void handleGamepadEvent(GamepadEvent event) {
    if (event.type == GamepadEventType.buttonDown) {
      _handleGamepadButtonDown(event);
    } else if (event.type == GamepadEventType.buttonUp) {
      _handleGamepadButtonUp(event);
    } else if (event.type == GamepadEventType.analog) {
      _handleGamepadAnalog(event);
    }
  }

  void _handleGamepadButtonDown(GamepadEvent event) {
    final button = event.button!;
    
    if (_pressedButtons.contains(button)) return;
    _pressedButtons.add(button);
    
    // Check for mapped action
    final action = _gamepadMappings[button];
    if (action != null) {
      _triggerAction(action);
    }
  }

  void _handleGamepadButtonUp(GamepadEvent event) {
    _pressedButtons.remove(event.button);
  }

  void _handleGamepadAnalog(GamepadEvent event) {
    // Handle analog stick input
    if (event.analogStick == AnalogStick.left) {
      _handleLeftStick(event.x!, event.y!);
    } else if (event.analogStick == AnalogStick.right) {
      _handleRightStick(event.x!, event.y!);
    }
  }

  void _handleLeftStick(double x, double y) {
    // Convert analog input to discrete actions
    const threshold = 0.5;
    
    if (x.abs() > threshold) {
      _triggerAction(x > 0 ? GestureAction.moveRight : GestureAction.moveLeft);
    }
    
    if (y.abs() > threshold) {
      _triggerAction(y > 0 ? GestureAction.moveDown : GestureAction.moveUp);
    }
  }

  void _handleRightStick(double x, double y) {
    // Right stick for rotation/camera
    const threshold = 0.5;
    
    if (x.abs() > threshold) {
      _triggerAction(x > 0 ? GestureAction.rotateRight : GestureAction.rotateLeft);
    }
  }

  void _triggerAction(GestureAction action) {
    final callback = _actionCallbacks[action];
    callback?.call();
  }

  /// Register an action callback.
  void registerAction(GestureAction action, VoidCallback callback) {
    _actionCallbacks[action] = callback;
  }

  /// Customize key mapping.
  void setKeyMapping(LogicalKeyboardKey key, GestureAction action) {
    _keyMappings[key] = action;
  }

  /// Customize gamepad mapping.
  void setGamepadMapping(GamepadButton button, GestureAction action) {
    _gamepadMappings[button] = action;
  }

  /// Dispose of resources.
  void dispose() {
    _keyMappings.clear();
    _gamepadMappings.clear();
    _actionCallbacks.clear();
    _pressedKeys.clear();
    _pressedButtons.clear();
  }
}

/// Gesture customization manager.
class GestureCustomizationManager {
  GestureCustomization _currentCustomization = GestureCustomization.defaults();
  
  /// Get the current customization.
  GestureCustomization get currentCustomization => _currentCustomization;

  /// Apply a configuration.
  void applyConfiguration(GestureConfiguration config) {
    _currentCustomization = _currentCustomization.copyWith(
      dragThreshold: config.dragThreshold,
      longPressTimeout: config.longPressTimeout,
      doubleTapTimeout: config.doubleTapTimeout,
    );
  }

  /// Apply a customization.
  void applyCustomization(GestureCustomization customization) {
    _currentCustomization = customization;
  }

  /// Reset to defaults.
  void resetToDefaults() {
    _currentCustomization = GestureCustomization.defaults();
  }
}

/// Platform-specific optimizer for gesture handling.
class PlatformOptimizer {
  final TargetPlatform platform;
  
  PlatformOptimizer({required this.platform});

  /// Get optimized settings for the current platform.
  PlatformSettings getOptimizedSettings() {
    switch (platform) {
      case TargetPlatform.iOS:
        return _getiOSSettings();
      case TargetPlatform.android:
        return _getAndroidSettings();
      case TargetPlatform.windows:
        return _getWindowsSettings();
      case TargetPlatform.macOS:
        return _getMacOSSettings();
      case TargetPlatform.linux:
        return _getLinuxSettings();
      default:
        return _getDefaultSettings();
    }
  }

  PlatformSettings _getiOSSettings() {
    return PlatformSettings(
      touchSlop: 18.0,
      dragStartDelay: Duration.zero,
      supportsPressure: true,
      supportsHaptics: true,
      maxSimultaneousTouches: 10,
    );
  }

  PlatformSettings _getAndroidSettings() {
    return PlatformSettings(
      touchSlop: 18.0,
      dragStartDelay: Duration.zero,
      supportsPressure: true,
      supportsHaptics: true,
      maxSimultaneousTouches: 10,
    );
  }

  PlatformSettings _getWindowsSettings() {
    return PlatformSettings(
      touchSlop: 8.0,
      dragStartDelay: const Duration(milliseconds: 100),
      supportsPressure: false,
      supportsHaptics: false,
      maxSimultaneousTouches: 1,
    );
  }

  PlatformSettings _getMacOSSettings() {
    return PlatformSettings(
      touchSlop: 8.0,
      dragStartDelay: Duration.zero,
      supportsPressure: true,
      supportsHaptics: false,
      maxSimultaneousTouches: 1,
    );
  }

  PlatformSettings _getLinuxSettings() {
    return PlatformSettings(
      touchSlop: 8.0,
      dragStartDelay: Duration.zero,
      supportsPressure: false,
      supportsHaptics: false,
      maxSimultaneousTouches: 1,
    );
  }

  PlatformSettings _getDefaultSettings() {
    return PlatformSettings(
      touchSlop: 18.0,
      dragStartDelay: Duration.zero,
      supportsPressure: false,
      supportsHaptics: false,
      maxSimultaneousTouches: 1,
    );
  }
}

/// Metrics for gesture performance monitoring.
class GestureMetrics {
  int _eventCount = 0;
  int _totalProcessingTime = 0;
  int _maxProcessingTime = 0;
  final _processingTimes = ListQueue<int>();
  static const _maxSamples = 1000;

  void recordEventProcessing(int microseconds) {
    _eventCount++;
    _totalProcessingTime += microseconds;
    
    if (microseconds > _maxProcessingTime) {
      _maxProcessingTime = microseconds;
    }
    
    if (_processingTimes.length >= _maxSamples) {
      _processingTimes.removeFirst();
    }
    _processingTimes.add(microseconds);
  }

  double get averageProcessingTime {
    return _eventCount > 0 ? _totalProcessingTime / _eventCount : 0.0;
  }

  int get maxProcessingTime => _maxProcessingTime;
  int get eventCount => _eventCount;

  GestureMetrics clone() {
    final metrics = GestureMetrics();
    metrics._eventCount = _eventCount;
    metrics._totalProcessingTime = _totalProcessingTime;
    metrics._maxProcessingTime = _maxProcessingTime;
    return metrics;
  }
}

// Data classes and enums

/// Types of gestures that can be recognized.
enum GestureType {
  tap,
  doubleTap,
  longPress,
  drag,
  scale,
  rotate,
  magnetic,
  swipe,
  fling,
  custom,
}

/// States of a gesture.
enum GestureState {
  possible,
  began,
  changed,
  recognized,
  failed,
  cancelled,
}

/// Actions that can be triggered by input.
enum GestureAction {
  select,
  cancel,
  moveUp,
  moveDown,
  moveLeft,
  moveRight,
  rotateLeft,
  rotateRight,
  zoomIn,
  zoomOut,
  undo,
  redo,
  nextFocus,
  previousFocus,
}

/// Accessibility gestures.
enum AccessibilityGesture {
  tap,
  doubleTap,
  tripleTap,
  longPress,
  swipeLeft,
  swipeRight,
  swipeUp,
  swipeDown,
  twoFingerTap,
  threeFingerTap,
  escape,
}

/// Gamepad buttons.
enum GamepadButton {
  buttonA,
  buttonB,
  buttonX,
  buttonY,
  leftShoulder,
  rightShoulder,
  leftTrigger,
  rightTrigger,
  select,
  start,
  leftStick,
  rightStick,
  dpadUp,
  dpadDown,
  dpadLeft,
  dpadRight,
  home,
}

/// Analog sticks.
enum AnalogStick {
  left,
  right,
}

/// Gamepad event types.
enum GamepadEventType {
  buttonDown,
  buttonUp,
  analog,
}

/// Type of recorded event.
enum RecordedEventType {
  pointer,
  key,
  gamepad,
}

/// Active gesture in the arena.
class ActiveGesture {
  final GestureType type;
  final GestureRecognizer recognizer;
  final int priority;
  final GestureCallback? callback;

  ActiveGesture({
    required this.type,
    required this.recognizer,
    this.priority = 0,
    this.callback,
  });
}

/// Composed gesture from multiple gestures.
class ComposedGesture {
  final String id;
  final List<GestureType> types;
  final ComposedGestureCallback callback;

  ComposedGesture({
    required this.id,
    required this.types,
    required this.callback,
  });
}

/// Recorded event for replay.
class RecordedEvent {
  final Duration timestamp;
  final RecordedEventType type;
  final PointerEvent? pointerEvent;
  final KeyEvent? keyEvent;
  final GamepadEvent? gamepadEvent;

  RecordedEvent.pointer({
    required this.timestamp,
    required PointerEvent event,
  })  : type = RecordedEventType.pointer,
        pointerEvent = event,
        keyEvent = null,
        gamepadEvent = null;

  RecordedEvent.key({
    required this.timestamp,
    required KeyEvent event,
  })  : type = RecordedEventType.key,
        pointerEvent = null,
        keyEvent = event,
        gamepadEvent = null;

  RecordedEvent.gamepad({
    required this.timestamp,
    required GamepadEvent event,
  })  : type = RecordedEventType.gamepad,
        pointerEvent = null,
        keyEvent = null,
        gamepadEvent = event;
}

/// Collection of recorded gestures.
class RecordedGestures {
  final List<RecordedEvent> events;
  final Duration duration;

  RecordedGestures({
    required this.events,
    required this.duration,
  });
}

/// Gamepad event.
class GamepadEvent {
  final GamepadEventType type;
  final GamepadButton? button;
  final AnalogStick? analogStick;
  final double? x;
  final double? y;
  final double? pressure;

  GamepadEvent({
    required this.type,
    this.button,
    this.analogStick,
    this.x,
    this.y,
    this.pressure,
  });
}

/// Gesture configuration.
class GestureConfiguration {
  final double? dragThreshold;
  final Duration? longPressTimeout;
  final Duration? doubleTapTimeout;
  final bool recordGestures;

  GestureConfiguration({
    this.dragThreshold,
    this.longPressTimeout,
    this.doubleTapTimeout,
    this.recordGestures = false,
  });
}

/// Gesture customization settings.
class GestureCustomization {
  final double dragThreshold;
  final Duration longPressTimeout;
  final Duration doubleTapTimeout;
  final double scaleSensitivity;
  final double rotationSensitivity;
  final Map<GestureType, bool> enabledGestures;

  GestureCustomization({
    required this.dragThreshold,
    required this.longPressTimeout,
    required this.doubleTapTimeout,
    required this.scaleSensitivity,
    required this.rotationSensitivity,
    required this.enabledGestures,
  });

  factory GestureCustomization.defaults() {
    return GestureCustomization(
      dragThreshold: 18.0,
      longPressTimeout: const Duration(milliseconds: 500),
      doubleTapTimeout: const Duration(milliseconds: 300),
      scaleSensitivity: 1.0,
      rotationSensitivity: 1.0,
      enabledGestures: Map.fromIterables(
        GestureType.values,
        List.filled(GestureType.values.length, true),
      ),
    );
  }

  GestureCustomization copyWith({
    double? dragThreshold,
    Duration? longPressTimeout,
    Duration? doubleTapTimeout,
    double? scaleSensitivity,
    double? rotationSensitivity,
    Map<GestureType, bool>? enabledGestures,
  }) {
    return GestureCustomization(
      dragThreshold: dragThreshold ?? this.dragThreshold,
      longPressTimeout: longPressTimeout ?? this.longPressTimeout,
      doubleTapTimeout: doubleTapTimeout ?? this.doubleTapTimeout,
      scaleSensitivity: scaleSensitivity ?? this.scaleSensitivity,
      rotationSensitivity: rotationSensitivity ?? this.rotationSensitivity,
      enabledGestures: enabledGestures ?? this.enabledGestures,
    );
  }
}

/// Platform-specific settings.
class PlatformSettings {
  final double touchSlop;
  final Duration dragStartDelay;
  final bool supportsPressure;
  final bool supportsHaptics;
  final int maxSimultaneousTouches;

  PlatformSettings({
    required this.touchSlop,
    required this.dragStartDelay,
    required this.supportsPressure,
    required this.supportsHaptics,
    required this.maxSimultaneousTouches,
  });
}

/// Conflict resolution result.
class ConflictResolution {
  final List<GestureType> allowedGestures;
  final GestureType? primaryGesture;

  ConflictResolution({
    required this.allowedGestures,
    this.primaryGesture,
  });
}

// Type definitions

typedef GestureCallback = void Function(GestureType type, GestureState state);
typedef ComposedGestureCallback = void Function(ComposedGesture gesture);
typedef ConflictResolver = ConflictResolution? Function(
  List<ActiveGesture> gestures,
  PointerEvent event,
);
