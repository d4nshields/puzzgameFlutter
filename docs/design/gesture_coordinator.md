# Gesture Coordinator System

## Overview

The `GestureCoordinator` is a comprehensive gesture management system that provides unified handling of all input types (touch, keyboard, gamepad) with advanced features like conflict resolution, gesture composition, and accessibility support.

## Architecture

```
GestureCoordinator (Singleton)
├── GestureArena
│   ├── Conflict Resolution
│   ├── Priority Management
│   └── Event Dispatching
├── GestureSequencer
│   ├── Gesture Composition
│   ├── Sequence Detection
│   └── Complex Gestures
├── AccessibilityAdapter
│   ├── Screen Reader Support
│   ├── Switch Control
│   └── Platform Integration
├── GestureRecorder
│   ├── Event Recording
│   ├── Replay System
│   └── Gesture Analysis
├── UnifiedInputManager
│   ├── Keyboard Handling
│   ├── Gamepad Support
│   └── Action Mapping
└── Platform Optimizer
    ├── iOS Optimizations
    ├── Android Optimizations
    └── Desktop Settings
```

## Key Features

### 1. **Gesture Conflict Resolution**
- Priority-based gesture handling
- Custom conflict resolvers
- Arena-based competition model
- Automatic gesture disambiguation

### 2. **Priority System**
- Integer-based priority levels (higher = more priority)
- Dynamic priority adjustment
- Conflict resolution based on priorities
- Support for custom resolution strategies

### 3. **Gesture Composition**
- Combine multiple gestures into complex interactions
- Sequential gesture detection (e.g., triple-tap)
- Parallel gesture composition (e.g., drag + rotate)
- Timeout-based sequence management

### 4. **Accessibility Support**
- Screen reader integration (VoiceOver/TalkBack)
- Switch control compatibility
- Keyboard navigation
- Semantic announcements
- Platform-specific accessibility features

### 5. **Input Unification**
- Keyboard input handling with customizable mappings
- Gamepad/controller support
- Touch/mouse/stylus normalization
- Cross-platform input abstraction

### 6. **Recording and Replay**
- Record gesture sequences for testing
- Replay recorded gestures with speed control
- Export/import gesture recordings
- Useful for tutorials and automation

### 7. **Platform Optimizations**
- iOS-specific touch handling
- Android material design compliance
- Desktop mouse/keyboard optimizations
- Adaptive touch slop and timing

## Usage

### Basic Setup

```dart
// Initialize the coordinator
final coordinator = GestureCoordinator();

await coordinator.initialize(
  context: context,
  config: GestureConfiguration(
    dragThreshold: 18.0,
    longPressTimeout: Duration(milliseconds: 500),
    doubleTapTimeout: Duration(milliseconds: 300),
    recordGestures: false,
  ),
);
```

### Registering Gestures

```dart
// Register a tap gesture with priority
coordinator.registerGesture(
  type: GestureType.tap,
  recognizer: TapGestureRecognizer()..onTap = handleTap,
  priority: 5,
  callback: (type, state) {
    print('Tap state: $state');
  },
);

// Register a high-priority drag gesture
coordinator.registerGesture(
  type: GestureType.drag,
  recognizer: PanGestureRecognizer()..onUpdate = handleDrag,
  priority: 10, // Higher priority than tap
);
```

### Custom Conflict Resolution

```dart
coordinator.addConflictResolver((gestures, event) {
  // Custom logic to resolve conflicts
  if (gestures.any((g) => g.type == GestureType.magnetic)) {
    // Always prefer magnetic gestures
    return ConflictResolution(
      allowedGestures: [GestureType.magnetic],
      primaryGesture: GestureType.magnetic,
    );
  }
  return null; // Use default resolution
});
```

### Composing Gestures

```dart
// Create a double-tap + drag combination
coordinator.composeGestures(
  types: [GestureType.doubleTap, GestureType.drag],
  callback: (gesture) {
    print('Special move activated!');
    performSpecialMove();
  },
);

// Create a triple-tap sequence
coordinator.composeGestures(
  types: [GestureType.tap, GestureType.tap, GestureType.tap],
  callback: (gesture) {
    showDebugMenu();
  },
);
```

### Keyboard Support

```dart
// Handle keyboard events
Focus(
  onKeyEvent: (node, event) {
    coordinator.handleKeyEvent(event);
    return KeyEventResult.handled;
  },
  child: YourGameWidget(),
)

// Register keyboard actions
final inputManager = UnifiedInputManager();
inputManager.registerAction(GestureAction.select, () {
  selectPiece();
});
inputManager.registerAction(GestureAction.undo, () {
  undoLastMove();
});
```

### Gamepad Support

```dart
// Register gamepad actions
inputManager.registerAction(GestureAction.select, () {
  // A button pressed
  selectPiece();
});

// Custom gamepad mappings
inputManager.setGamepadMapping(
  GamepadButton.buttonX,
  GestureAction.rotateLeft,
);
```

### Accessibility

```dart
// Register accessibility gestures
final adapter = AccessibilityGestureAdapter();
adapter.registerGesture(
  AccessibilityGesture.doubleTap,
  () => activateSelectedItem(),
);

// Announce for screen readers
adapter.announce(
  'Piece moved to position',
  textDirection: TextDirection.ltr,
);
```

### Recording and Replay

```dart
// Start recording
coordinator.startRecording();

// Perform gestures...

// Stop and get recording
final recorded = coordinator.stopRecording();

// Save recording for later
final json = recorded.toJson();

// Replay gestures
await coordinator.replayGestures(
  recorded,
  speed: 2.0, // 2x speed
);
```

### Platform-Specific Settings

```dart
final optimizer = PlatformOptimizer(
  platform: Theme.of(context).platform,
);

final settings = optimizer.getOptimizedSettings();
print('Touch slop: ${settings.touchSlop}');
print('Supports haptics: ${settings.supportsHaptics}');
```

## Configuration

### GestureConfiguration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `dragThreshold` | double | 18.0 | Minimum distance for drag detection |
| `longPressTimeout` | Duration | 500ms | Time before long press triggers |
| `doubleTapTimeout` | Duration | 300ms | Maximum time between taps |
| `recordGestures` | bool | false | Enable automatic recording |

### GestureCustomization

```dart
final customization = GestureCustomization(
  dragThreshold: 25.0,
  longPressTimeout: Duration(milliseconds: 600),
  doubleTapTimeout: Duration(milliseconds: 250),
  scaleSensitivity: 1.5,
  rotationSensitivity: 0.8,
  enabledGestures: {
    GestureType.tap: true,
    GestureType.drag: true,
    GestureType.scale: false, // Disable pinch
  },
);

coordinator.applyCustomization(customization);
```

## Gesture Types

- `tap` - Single tap
- `doubleTap` - Double tap
- `longPress` - Long press
- `drag` - Pan/drag gesture
- `scale` - Pinch to zoom
- `rotate` - Two-finger rotation
- `magnetic` - Magnetic field-influenced drag
- `swipe` - Quick directional swipe
- `fling` - Fast throw gesture
- `custom` - User-defined gestures

## Gesture Actions

- `select` - Primary selection
- `cancel` - Cancel/back
- `moveUp/Down/Left/Right` - Directional movement
- `rotateLeft/Right` - Rotation
- `zoomIn/Out` - Zoom controls
- `undo/redo` - History navigation
- `nextFocus/previousFocus` - Focus navigation

## Performance Metrics

Monitor gesture performance:

```dart
final metrics = coordinator.getMetrics();
print('Events processed: ${metrics.eventCount}');
print('Average time: ${metrics.averageProcessingTime}μs');
print('Max time: ${metrics.maxProcessingTime}μs');
```

## Best Practices

### 1. **Priority Management**
- Use consistent priority scales (e.g., 0-10)
- Higher priority for more specific gestures
- Document priority decisions

### 2. **Conflict Resolution**
- Test gesture combinations thoroughly
- Provide clear conflict resolution rules
- Consider user expectations

### 3. **Accessibility**
- Always support keyboard navigation
- Provide screen reader descriptions
- Test with accessibility tools

### 4. **Performance**
- Dispose recognizers when not needed
- Use appropriate gesture granularity
- Monitor metrics in production

### 5. **Platform Considerations**
- Test on all target platforms
- Adjust touch thresholds per platform
- Consider input device capabilities

## Testing

```dart
// Test gesture conflicts
test('should resolve tap vs drag conflict', () {
  final coordinator = GestureCoordinator();
  
  // Register conflicting gestures
  coordinator.registerGesture(
    type: GestureType.tap,
    recognizer: TapGestureRecognizer(),
    priority: 5,
  );
  
  coordinator.registerGesture(
    type: GestureType.drag,
    recognizer: PanGestureRecognizer(),
    priority: 10,
  );
  
  // Drag should win due to higher priority
  // Test implementation...
});
```

## Troubleshooting

### Issue: Gestures not responding
- Check gesture priorities
- Verify gesture is enabled
- Look for conflicting recognizers

### Issue: Wrong gesture triggered
- Adjust priorities
- Add custom conflict resolver
- Increase gesture thresholds

### Issue: Accessibility not working
- Ensure proper initialization
- Check platform settings
- Verify semantic annotations

## Integration with Game

The gesture coordinator integrates seamlessly with the magnetic gesture recognizer and other game systems:

```dart
class PuzzleGame extends StatefulWidget {
  @override
  _PuzzleGameState createState() => _PuzzleGameState();
}

class _PuzzleGameState extends State<PuzzleGame> {
  late GestureCoordinator _coordinator;
  
  @override
  void initState() {
    super.initState();
    _coordinator = GestureCoordinator();
    _setupGestures();
  }
  
  void _setupGestures() {
    // Register magnetic gesture with highest priority
    _coordinator.registerGesture(
      type: GestureType.magnetic,
      recognizer: MagneticGestureRecognizer(...),
      priority: 100,
    );
    
    // Add other gestures...
  }
}
```

## Summary

The GestureCoordinator provides a robust, extensible system for managing all types of user input in the Puzzle Nook game. It handles complex scenarios like gesture conflicts, accessibility requirements, and cross-platform differences while maintaining excellent performance and user experience.
