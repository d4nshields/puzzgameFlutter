# Render Coordinator Documentation

## Overview

The Render Coordinator is a centralized system that manages all rendering layers in the Puzzle Nook game, providing optimal performance through intelligent frame scheduling, automatic quality adaptation, and comprehensive performance monitoring.

## Architecture

### Core Components

1. **RenderCoordinator**
   - Central hub for all rendering operations
   - Manages layer registration and lifecycle
   - Coordinates frame scheduling and quality adaptation
   - Provides performance monitoring and profiling

2. **FrameScheduler**
   - Priority-based frame scheduling system
   - Processes frames at target frame rate (60fps default)
   - Merges similar frame requests for efficiency
   - Uses priority queue for optimal scheduling

3. **QualityAdapter**
   - Automatic quality adjustment based on performance
   - Monitors FPS and dropped frames
   - Smooth transitions between quality levels
   - Configurable thresholds and adaptation speed

4. **RenderMetrics**
   - Comprehensive performance data collection
   - Per-layer and per-frame metrics
   - Historical data for trend analysis
   - Export capabilities for profiling

5. **LayerCommunicationBus**
   - Inter-layer messaging system
   - Broadcast and direct message support
   - Event-driven architecture
   - Type-safe message passing

6. **DeveloperTools**
   - Visual performance overlay
   - Profiling modes (off, basic, detailed)
   - Real-time metrics display
   - Profile export functionality

## Features

### Layer Management
- Dynamic layer registration/unregistration
- Automatic layer lifecycle management
- Layer-specific quality settings
- Independent layer update cycles

### Frame Scheduling
- Priority levels: low, normal, high, critical
- Intelligent frame merging
- Frame budget management
- Dropped frame detection

### Quality Adaptation
- Four quality levels: low, medium, high, ultra
- Automatic adaptation based on:
  - Current FPS (target: 60fps)
  - Dropped frame count
  - Average frame time
- Manual quality override support

### Performance Monitoring
- Real-time FPS tracking
- Frame time measurements
- Dropped frame counting
- Memory usage monitoring
- Layer-specific metrics

### Developer Tools
- Visual overlay showing:
  - Current FPS
  - Frame time
  - Quality level
  - Active layers
  - Memory usage
- Expandable detail view
- Profiling controls
- Export functionality

## Usage

### Basic Setup

```dart
// Create coordinator with configuration
final coordinator = RenderCoordinator(
  config: const RenderCoordinatorConfig(
    targetFrameRate: 60,
    initialQuality: QualityLevel.high,
    autoAdaptQuality: true,
    enableDeveloperTools: true,
  ),
);

// Register layers
coordinator.registerLayer(RenderLayerType.static, staticLayer);
coordinator.registerLayer(RenderLayerType.dynamic, dynamicLayer);
coordinator.registerLayer(RenderLayerType.effects, effectsLayer);
```

### Scheduling Frames

```dart
// Schedule with priority
coordinator.scheduleFrame(
  layers: {RenderLayerType.dynamic},
  priority: RenderPriority.high,
  metadata: {'reason': 'animation_update'},
);

// Force immediate render
coordinator.forceFrame();
```

### Inter-Layer Communication

```dart
// Send broadcast message
coordinator.sendMessage(LayerMessage(
  type: MessageType.update,
  sender: RenderLayerType.static,
  data: {'state': 'changed'},
));

// Send direct message
coordinator.sendMessage(LayerMessage(
  type: MessageType.custom,
  sender: RenderLayerType.dynamic,
  recipient: RenderLayerType.effects,
  data: {'trigger': 'celebration'},
));
```

### Performance Monitoring

```dart
// Get performance snapshot
final snapshot = coordinator.getPerformanceSnapshot();
print('FPS: ${snapshot.fps}');
print('Quality: ${snapshot.currentQuality}');

// Enable profiling
coordinator.setProfilingMode(ProfilingMode.detailed);

// Export profile data
final profile = coordinator.developerTools.exportProfile();
```

### Custom Layer Implementation

```dart
class CustomRenderLayer extends RenderLayer {
  @override
  void performRender() {
    // Rendering logic here
  }
  
  @override
  void handleMessage(LayerMessage message) {
    // Handle incoming messages
  }
  
  @override
  void updateQuality(QualityLevel quality) {
    // Adjust rendering for quality level
  }
  
  @override
  RenderLayerType get layerType => RenderLayerType.custom;
}
```

## Performance Targets

- **Frame Rate**: 60fps minimum
- **Frame Budget**: 16ms per frame
- **Dropped Frames**: < 5 per minute
- **Quality Adaptation**: < 2 seconds response time
- **Memory Usage**: < 100MB for coordinator
- **Message Latency**: < 1ms

## Quality Levels

### Low
- Minimal effects
- Reduced particle count
- Basic animations
- Lower texture quality

### Medium
- Standard effects
- Moderate particle count
- Smooth animations
- Standard texture quality

### High
- Enhanced effects
- High particle count
- Complex animations
- High texture quality

### Ultra
- Maximum effects
- Unlimited particles
- Advanced animations
- Maximum texture quality

## Profiling Modes

### Off
- No profiling overhead
- Minimal memory usage
- Production mode

### Basic
- Layer render times
- Frame statistics
- Low overhead

### Detailed
- Complete frame profiles
- Per-layer metrics
- Message tracking
- Higher overhead

## Testing

The render coordinator includes comprehensive tests covering:
- Layer registration and management
- Frame scheduling with priorities
- Quality adaptation algorithms
- Performance metric collection
- Communication bus functionality
- Developer tools and overlays

Run tests with:
```bash
flutter test test/game_module2/presentation/rendering/render_coordinator_test.dart
```

## Integration Example

See `/lib/game_module2/presentation/rendering/render_coordinator_example.dart` for a complete integration example showing:
- Layer setup and registration
- Frame scheduling
- Quality management
- Message passing
- Developer tools usage

## Best Practices

1. **Layer Registration**
   - Register layers in order of rendering (back to front)
   - Unregister layers when not needed
   - Use appropriate layer types

2. **Frame Scheduling**
   - Use appropriate priorities
   - Batch similar updates
   - Avoid excessive force frames

3. **Quality Management**
   - Enable auto-adaptation for production
   - Test all quality levels
   - Monitor performance metrics

4. **Message Passing**
   - Use typed messages
   - Keep payloads small
   - Avoid circular dependencies

5. **Performance**
   - Profile regularly
   - Monitor dropped frames
   - Optimize heavy layers
   - Use quality levels effectively

## Troubleshooting

### High Frame Drops
- Check layer render times
- Reduce quality level
- Optimize heavy operations
- Enable profiling

### Poor Quality Adaptation
- Adjust thresholds
- Check FPS calculation
- Verify metrics collection
- Test adaptation speed

### Message Issues
- Verify layer registration
- Check message types
- Debug with logging
- Test message flow

### Memory Issues
- Clear old profiles
- Limit metric history
- Optimize layer data
- Check for leaks
