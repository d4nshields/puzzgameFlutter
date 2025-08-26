# Magnetic Gesture Recognizer

## Overview

The `MagneticGestureRecognizer` is an advanced gesture recognition system that provides smooth, intuitive piece manipulation with magnetic field influence for the Puzzle Nook game. It extends Flutter's `OneSequenceGestureRecognizer` to add sophisticated features like magnetic snapping, momentum physics, and multi-touch support.

## Key Features

### 1. **Magnetic Field Influence**
- Smooth interpolation between user input and magnetic assistance
- Configurable field strength and falloff curves
- Multiple snap points with independent radii and strengths
- Gradient-based field calculations for natural movement

### 2. **Performance Optimization**
- **< 1ms processing per gesture event** (verified by tests)
- Support for **120Hz touch sampling** without frame drops
- Efficient event handling with no dropped touches under load
- Memory-efficient with automatic cleanup

### 3. **Advanced Gesture Tracking**
- High-precision velocity tracking using least squares regression
- Momentum physics with configurable friction and mass
- Predictive touch handling for responsive interactions
- Smooth gesture interpolation using cubic curves

### 4. **Multi-Touch Support**
- Simultaneous tracking of multiple touch points
- Pinch-to-zoom gesture recognition
- Rotation gesture detection
- Center point calculation for multi-finger gestures

### 5. **Adaptive Sensitivity**
- Device-specific sensitivity adjustments (touch, stylus, mouse)
- Velocity-based sensitivity scaling
- Pressure-sensitive input support
- Context-aware sensitivity adaptation

### 6. **Debug and Performance Tools**
- Comprehensive gesture event logging
- Real-time performance metrics
- Visual debug overlays
- Exportable debug logs for analysis

## Architecture

```
MagneticGestureRecognizer
├── Core Components
│   ├── Gesture Recognition (OneSequenceGestureRecognizer)
│   ├── Magnetic Field System
│   ├── Velocity Tracker
│   └── Momentum Physics
│
├── Configuration
│   ├── MagneticFieldConfiguration
│   ├── AdaptiveSensitivity
│   └── MomentumPhysics
│
├── Multi-Touch
│   ├── Touch Point Tracking
│   ├── Gesture Composition
│   └── Multi-Touch Events
│
└── Debug Tools
    ├── Performance Monitor
    ├── Gesture Debugger
    └── Event Logger
```

## Usage Example

### Basic Setup

```dart
// Create a recognizer with magnetic field configuration
final recognizer = MagneticGestureRecognizer(
  fieldConfig: MagneticFieldConfiguration(
    snapPoints: [
      MagneticSnapPoint(
        position: Offset(100, 100),
        radius: 50,
        strength: 0.8,
      ),
    ],
    strength: 0.4,
    falloffType: FieldFalloffType.quadratic,
  ),
  debugMode: true, // Enable debug logging
);

// Set up callbacks
recognizer.onStart = (details) {
  print('Drag started at ${details.globalPosition}');
};

recognizer.onUpdate = (details) {
  // Update piece position with magnetic assistance
  setState(() {
    piecePosition += details.delta;
  });
};

recognizer.onEnd = (details) {
  // Apply momentum if velocity is significant
  if (details.velocity.pixelsPerSecond.distance > 10) {
    startMomentumAnimation(details.velocity);
  }
};

recognizer.onMagneticInfluence = (influence) {
  // Visual feedback for magnetic field
  print('Magnetic influence: ${influence.strength}');
};
```

### Integration with Widgets

```dart
RawGestureDetector(
  gestures: {
    MagneticGestureRecognizer: GestureRecognizerFactoryWithHandlers<
        MagneticGestureRecognizer>(
      () => MagneticGestureRecognizer(
        fieldConfig: magneticConfig,
      ),
      (MagneticGestureRecognizer instance) {
        instance
          ..onStart = handleDragStart
          ..onUpdate = handleDragUpdate
          ..onEnd = handleDragEnd;
      },
    ),
  },
  child: YourWidget(),
)
```

## Configuration Options

### MagneticFieldConfiguration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strength` | double | 0.3 | Base strength of the magnetic field (0.0 to 1.0) |
| `minimumInfluence` | double | 0.1 | Minimum distance for field influence to activate |
| `maxInfluence` | double | 5.0 | Maximum influence offset in logical pixels |
| `falloffType` | FieldFalloffType | quadratic | Field strength falloff curve |
| `snapPoints` | List<MagneticSnapPoint> | [] | Snap points that generate magnetic fields |

### Field Falloff Types

- **Linear**: Uniform decrease with distance
- **Quadratic**: Natural falloff (recommended)
- **Cubic**: Sharp falloff for precise snapping
- **Exponential**: Smooth, gradual falloff

### MomentumPhysics

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `friction` | double | 0.15 | Friction coefficient for momentum decay |
| `mass` | double | 1.0 | Virtual mass of dragged object |
| `threshold` | double | 10.0 | Minimum velocity for momentum activation |

### AdaptiveSensitivity

The system automatically adjusts sensitivity based on:
- **Device Type**: Touch (1.0x), Stylus (1.2x), Mouse/Trackpad (0.8x)
- **Velocity**: Reduces sensitivity at high speeds for better control
- **Pressure**: Adjusts based on pressure-sensitive input

## Performance Metrics

The recognizer provides real-time performance metrics:

```dart
final metrics = recognizer.getPerformanceMetrics();
print('Average processing: ${metrics.averageProcessingTime}μs');
print('Max processing: ${metrics.maxProcessingTime}μs');
print('Sampling rate: ${metrics.samplingRate}Hz');
print('Dropped events: ${metrics.droppedEvents}');
```

## Debug Mode

Enable debug mode for detailed gesture analysis:

```dart
recognizer.setDebugMode(true);

// Export debug logs
final logs = recognizer.exportDebugLogs();
for (final event in logs) {
  print('${event.type}: ${event.position} at ${event.timestamp}');
}
```

## Best Practices

### 1. **Configure Snap Points Appropriately**
- Use reasonable radii (40-80 pixels) for natural snapping
- Avoid overlapping snap point radii
- Adjust strength based on puzzle difficulty

### 2. **Optimize for Device Type**
- Test on various devices (phones, tablets)
- Adjust sensitivity for different screen sizes
- Consider device-specific magnetic field strengths

### 3. **Provide Visual Feedback**
- Show magnetic field influence visually
- Indicate when pieces are within snap range
- Use animations for smooth transitions

### 4. **Handle Edge Cases**
- Test with rapid gestures
- Handle multi-touch scenarios
- Ensure proper cleanup on dispose

### 5. **Performance Monitoring**
- Monitor gesture processing times in production
- Track dropped events
- Adjust quality settings based on device capabilities

## Testing

Run the comprehensive test suite:

```bash
flutter test test/magnetic_gesture_recognizer_test.dart
```

Key test categories:
- Performance benchmarks (< 1ms processing)
- 120Hz touch sampling support
- Magnetic field calculations
- Multi-touch handling
- Velocity tracking accuracy
- Momentum physics
- Adaptive sensitivity

## Troubleshooting

### Issue: Laggy gesture response
**Solution**: Check performance metrics and reduce magnetic field calculations or snap point count.

### Issue: Pieces snapping too aggressively
**Solution**: Reduce `strength` parameter or increase `minimumInfluence` threshold.

### Issue: Multi-touch not working
**Solution**: Ensure `supportedDevices` includes the target device type.

### Issue: Memory leaks
**Solution**: Ensure proper disposal of recognizer and animation controllers.

## Future Enhancements

- [ ] GPU-accelerated field calculations
- [ ] Machine learning-based gesture prediction
- [ ] Haptic feedback integration
- [ ] Custom field shapes (not just circular)
- [ ] Network-synchronized gestures for multiplayer

## License

This component is part of the Puzzle Nook project and follows the project's licensing terms.
