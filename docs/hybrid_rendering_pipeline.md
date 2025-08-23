# Hybrid Rendering Pipeline Documentation

## Overview

The Hybrid Rendering Pipeline for Puzzle Nook implements a sophisticated three-layer rendering architecture that combines the best of Flutter widgets, custom painting, and game engine capabilities. This system is designed to achieve smooth 60fps gameplay while maintaining visual quality and efficient memory usage.

## Architecture

### Three-Layer System

1. **Static Layer** (CustomPaint with Picture caching)
   - Renders background elements that rarely change
   - Uses Picture caching for optimal performance
   - Updates only when puzzle pieces lock in place
   - Includes: game board grid, completed sections, background effects

2. **Dynamic Layer** (Optimized Widgets)
   - Renders interactive puzzle pieces
   - Each piece wrapped in RepaintBoundary for independent updates
   - Hardware-accelerated transforms
   - Updates per-piece as needed

3. **Effects Layer** (Custom particle system)
   - Renders particle effects and celebrations
   - Magnetic field visualizations
   - Runs at 60-120 FPS independent of other layers
   - Includes: bursts, fountains, confetti, field lines

## Core Components

### 1. HybridRenderer
Main orchestrator widget that manages all three layers and coordinates rendering.

```dart
HybridRenderer(
  gameSize: Size(800, 600),
  pieces: puzzlePieces,
  gameState: currentGameState,
  config: RenderingConfig(
    targetFrameTime: Duration(milliseconds: 16),
    initialQuality: QualityLevel.high,
    autoAdjustQuality: true,
    showDebugOverlay: kDebugMode,
  ),
  onPerformanceUpdate: (metrics) {
    // Handle performance metrics
  },
)
```

### 2. Coordinate System
Manages transformations between different coordinate spaces:
- **Screen Space**: Device pixel coordinates
- **Canvas Space**: Game rendering coordinates
- **Grid Space**: Logical game grid coordinates
- **Workspace Space**: Puzzle workspace coordinates

### 3. Performance Monitoring
Tracks and reports performance metrics:
- Frame rate (FPS)
- Frame time variance
- Dropped frames
- Memory usage
- Performance score (0-100)

### 4. Quality Management
Automatically adjusts rendering quality based on performance:
- **Low**: 0.5x resolution, 30 FPS target, no shadows/particles
- **Medium**: 0.75x resolution, 60 FPS target, basic effects
- **High**: 1.0x resolution, 60 FPS target, full effects
- **Ultra**: 1.0x resolution, 120 FPS target, all effects

### 5. Frame Budget Management
Ensures smooth performance by allocating time budgets:
- Static Layer: 25% of frame time (4ms)
- Dynamic Layer: 50% of frame time (8ms)
- Effects Layer: 25% of frame time (4ms)

### 6. Dirty Region Tracking
Optimizes repainting by tracking changed regions:
- Marks regions that need repainting
- Merges overlapping regions
- Provides statistics for optimization

## Usage Examples

### Basic Setup

```dart
class GameScreen extends StatefulWidget {
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<RenderablePiece> _pieces;
  late GameState _gameState;
  
  @override
  Widget build(BuildContext context) {
    return HybridRenderer(
      gameSize: Size(1024, 768),
      pieces: _pieces,
      gameState: _gameState,
      config: RenderingConfig(
        initialQuality: QualityLevel.high,
        autoAdjustQuality: true,
      ),
      onPerformanceUpdate: _handlePerformanceUpdate,
    );
  }
  
  void _handlePerformanceUpdate(PerformanceMetrics metrics) {
    if (metrics.fps < 30) {
      // Show performance warning
      print('Low FPS: ${metrics.fps}');
    }
  }
}
```

### Triggering Effects

```dart
// Access the effects controller
final effectsController = _hybridRenderer.effectsController;

// Trigger a burst effect when piece is placed
effectsController.triggerEffect(
  BurstEffect(
    position: piecePosition,
    particleCount: 30,
    colors: [Colors.yellow, Colors.orange],
    duration: Duration(milliseconds: 500),
  ),
);

// Start continuous magnetic field visualization
final fieldId = effectsController.startContinuousEffect(
  MagneticFieldEffect(
    center: targetPosition,
    radius: 100,
  ),
);

// Stop the effect later
effectsController.stopContinuousEffect(fieldId);

// Trigger celebration effect on puzzle completion
effectsController.triggerEffect(
  CelebrationEffect(
    position: screenCenter,
    duration: Duration(seconds: 3),
  ),
);
```

### Custom Piece Rendering

```dart
class MyPiece implements RenderablePiece {
  @override
  final String id;
  
  @override
  Offset position;
  
  @override
  double rotation;
  
  @override
  final Size size;
  
  @override
  bool isSelected = false;
  
  @override
  bool isPlaced = false;
  
  @override
  bool isDragging = false;
  
  MyPiece({
    required this.id,
    required this.position,
    this.rotation = 0,
    required this.size,
  });
}
```

### Performance Optimization

```dart
// Access quality manager from the renderer
final qualityManager = hybridRenderer.qualityManager;

// Manual quality adjustment
qualityManager.setQuality(QualityLevel.medium);

// Check current quality level (public API)
final currentQuality = qualityManager.currentQuality;
print('Current quality: $currentQuality');

// Check if can increase quality
if (qualityManager.canIncreaseQuality()) {
  qualityManager.increaseQuality();
}

// Get current render settings
final settings = qualityManager.getRenderSettings();
print('Resolution scale: ${settings.resolutionScale}');
print('Shadows enabled: ${settings.enableShadows}');
print('Target FPS: ${settings.targetFps}');
```

## Performance Guidelines

### Optimization Tips

1. **Use RepaintBoundary**
   - Wrap expensive widgets in RepaintBoundary
   - Already implemented for each puzzle piece

2. **Batch Updates**
   - Group multiple piece updates together
   - Use scheduler.scheduleBatch() for multiple layers

3. **Quality Settings**
   - Start with High quality
   - Enable auto-adjustment for dynamic optimization
   - Manually lower quality for low-end devices

4. **Memory Management**
   - Target < 100MB for rendering
   - Monitor memory trend in performance metrics
   - Clear unused resources promptly

### Performance Targets

- **Frame Rate**: 60 FPS (55+ acceptable)
- **Frame Time**: < 16ms average
- **Dropped Frames**: < 5 per second
- **Memory Usage**: < 100MB for rendering
- **Quality Score**: > 80/100

## Advanced Features

### Coordinate Transformations

```dart
// Transform from screen to workspace coordinates
final workspacePoint = coordinateSystem.screenToWorkspace(touchPoint);

// Transform from workspace to screen for rendering
final screenPoint = coordinateSystem.workspaceToScreen(piecePosition);

// Get visible bounds in different spaces
final screenBounds = coordinateSystem.screenBounds;
final canvasBounds = coordinateSystem.canvasBounds;
final gridBounds = coordinateSystem.gridBounds;
```

### Custom Effects

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

// Create custom particle effect
class CustomEffect extends ParticleEffect {
  CustomEffect({required Offset position})
    : super(
        type: ParticleEffectType.custom,
        position: position,
        duration: Duration(seconds: 1),
      );
  
  @override
  void update(double deltaTime) {
    // Update particle positions
    // Apply physics, fade out, etc.
  }
}

// Create custom continuous effect with proper LOD checking
class PulsingGlow extends ContinuousEffect {
  final Offset center;  // Define center point
  double time = 0;
  double intensity = 0.5;
  
  PulsingGlow({required this.center}) : super(type: ContinuousEffectType.custom);
  
  @override
  void update(double deltaTime) {
    time += deltaTime;
    // Update glow intensity
    intensity = 0.5 + 0.5 * math.sin(time * 2);
  }
}

// Example of rendering with LOD consideration
class LODAwareRenderer {
  final QualityManager qualityManager;
  
  LODAwareRenderer({required this.qualityManager});
  
  void render(Canvas canvas, Size size) {
    // Define center point for effects
    final center = Offset(size.width / 2, size.height / 2);
    
    // Use public API to check quality level
    final currentQuality = qualityManager.currentQuality;
    
    if (currentQuality == QualityLevel.high || currentQuality == QualityLevel.ultra) {
      // Render complex effects only on high quality
      _renderComplexEffect(canvas, center);
    } else {
      // Render simple effects for lower quality
      _renderSimpleEffect(canvas, center);
    }
  }
  
  void _renderComplexEffect(Canvas canvas, Offset center) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.blue, Colors.purple],
      ).createShader(Rect.fromCircle(center: center, radius: 100));
    canvas.drawCircle(center, 100, paint);
  }
  
  void _renderSimpleEffect(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.5);
    canvas.drawCircle(center, 50, paint);
  }
}
```

### Performance Monitoring

```dart
// Get performance summary
final summary = performanceMonitor.getSummary();
print('Uptime: ${summary.uptime}');
print('Average FPS: ${summary.averageFps}');
print('Performance Score: ${summary.performanceScore}/100');

// Get scheduler statistics
final stats = renderScheduler.getStats();
print('Queue size: ${stats.queueSize}');
for (final entry in stats.layerStats.entries) {
  print('${entry.key}: ${entry.value.renderCount} renders');
}
```

## Debugging

### Debug Overlay
Enable the debug overlay to see real-time performance metrics:

```dart
RenderingConfig(
  showDebugOverlay: true,
)
```

Shows:
- Current FPS
- Dropped frames
- Quality level
- Dirty region count

### Performance Logging
Performance issues are automatically logged in debug mode:
- Low FPS warnings (< 30 FPS)
- High memory usage (> 100MB)
- Excessive dropped frames (> 10)
- Frame budget overruns

### Troubleshooting

**Low FPS**
1. Check quality settings - consider lowering
2. Reduce particle effect complexity
3. Optimize piece count on screen
4. Check for unnecessary rebuilds

**High Memory Usage**
1. Check for memory leaks in effects
2. Dispose unused controllers properly
3. Clear picture cache periodically
4. Reduce texture quality

**Visual Glitches**
1. Verify coordinate transformations
2. Check dirty region tracking
3. Ensure proper layer ordering
4. Validate RepaintBoundary usage

## Integration with Game Module

### Connecting to Game State

```dart
class GameStateAdapter implements GameState {
  final PuzzleGameState puzzleState;
  
  @override
  bool get showGrid => puzzleState.settings.showGrid;
  
  @override
  List<String> get completedSections => 
    puzzleState.completedPieces.map((p) => p.sectionId).toList();
  
  @override
  Map<String, dynamic> get metadata => {
    'difficulty': puzzleState.difficulty,
    'progress': puzzleState.progress,
  };
}
```

### Handling Piece Interactions

```dart
// In your game widget
GestureDetector(
  onPanStart: (details) {
    final piece = _hitTest(details.localPosition);
    if (piece != null) {
      setState(() {
        piece.isDragging = true;
        piece.isSelected = true;
      });
    }
  },
  onPanUpdate: (details) {
    if (_selectedPiece != null) {
      setState(() {
        _selectedPiece!.position += details.delta;
      });
    }
  },
  onPanEnd: (details) {
    if (_selectedPiece != null) {
      _checkPiecePlacement(_selectedPiece!);
      setState(() {
        _selectedPiece!.isDragging = false;
      });
    }
  },
  child: HybridRenderer(
    // ... configuration
  ),
)
```

## Best Practices

1. **Layer Separation**
   - Keep static content in static layer
   - Only update dynamic layer for piece movements
   - Reserve effects layer for visual feedback

2. **State Management**
   - Use immutable piece states where possible
   - Batch state updates
   - Avoid unnecessary rebuilds

3. **Resource Management**
   - Dispose controllers when not needed
   - Clear effect queues on screen transitions
   - Monitor memory usage trends

4. **Testing**
   - Test on low-end devices
   - Profile with DevTools
   - Monitor frame timing
   - Validate memory usage

## Future Enhancements

Planned improvements:
- WebGL rendering backend
- Texture atlasing for pieces
- Advanced shader effects
- Multi-threaded rendering
- Predictive quality adjustment
- Cloud-based quality profiles

## Support

For issues or questions:
1. Check debug overlay for performance metrics
2. Review console logs for warnings
3. Profile with Flutter DevTools
4. Contact the development team

---

Version: 1.0.0
Last Updated: August 2025
