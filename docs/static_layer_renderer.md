# Static Layer Renderer Documentation

## Overview

The Static Layer Renderer is a highly optimized CustomPainter implementation designed to render static game elements with minimal CPU overhead. It achieves 60fps performance on mid-range devices through advanced caching strategies, viewport culling, and a level-of-detail system.

## Key Features

### 1. **Picture Caching System**
- Renders complex graphics once and caches them as `ui.Picture` objects
- Automatically invalidates cache when content changes
- Separate caches for grid, background, sections, and effects
- Memory-efficient disposal of unused pictures

### 2. **Viewport Culling**
- Only renders elements visible in the current viewport
- Calculates visible grid bounds to minimize draw calls
- Skips rendering of off-screen completed sections
- Dynamic culling based on zoom level

### 3. **Level of Detail (LOD) System**
- **Low**: Minimal details for zoomed-out views (< 50% zoom)
  - Large grid spacing (100px)
  - No intersection points
  - Basic effects only
  - Reduced particle count
  
- **Medium**: Balanced quality (50-100% zoom)
  - Standard grid spacing (50px)
  - Basic effects enabled
  - Moderate particle density
  
- **High**: Full quality for close-up views (> 100% zoom)
  - Fine grid spacing (25px)
  - All effects enabled
  - Maximum particle count
  - Grid intersection points
  - Success patterns in completed sections

### 4. **Performance Optimizations**
- Paint object caching to reduce allocations
- Efficient viewport bounds calculation
- Batch rendering of similar elements
- Smart cache invalidation strategies
- Frame time monitoring

## Architecture

### Core Components

#### `StaticLayerController`
Manages the state and caching logic for the static layer.

```dart
class StaticLayerController extends ChangeNotifier {
  // Picture caches
  ui.Picture? _gridPicture;
  ui.Picture? _backgroundPicture;
  Map<String, ui.Picture> _sectionPictures;
  
  // Cache invalidation
  void invalidateGrid();
  void invalidateBackground();
  void invalidateSection(String sectionId);
  
  // Performance tracking
  PerformanceMetrics getPerformanceMetrics();
}
```

#### `StaticLayerPainter`
Custom painter that renders cached pictures with viewport culling.

```dart
class StaticLayerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Apply viewport clipping
    // 2. Draw background (cached)
    // 3. Draw grid (cached with culling)
    // 4. Draw completed sections (individually cached)
    // 5. Draw effects (LOD-based)
    // 6. Debug visualizations (optional)
  }
}
```

#### `PerformanceTracker`
Monitors rendering performance and cache efficiency.

```dart
class PerformanceTracker {
  void recordPaintTime(Duration time);
  void recordCacheHit();
  void recordCacheMiss();
  PerformanceMetrics getMetrics();
}
```

## Usage

### Basic Integration

```dart
class GameScreen extends StatefulWidget {
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late StaticLayerController _controller;
  late GameState _gameState;
  
  @override
  void initState() {
    super.initState();
    _controller = StaticLayerController();
    _gameState = MyGameState();
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final viewport = Rect.fromLTWH(0, 0, size.width, size.height);
        
        return StaticLayer(
          size: size,
          gameState: _gameState,
          viewport: viewport,
          zoomLevel: 1.0,
          debugMode: false,
        );
      },
    );
  }
}
```

### With Viewport Control

```dart
class PannableGameArea extends StatefulWidget {
  @override
  State<PannableGameArea> createState() => _PannableGameAreaState();
}

class _PannableGameAreaState extends State<PannableGameArea> {
  Offset _viewportOffset = Offset.zero;
  double _zoomLevel = 1.0;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _viewportOffset -= details.delta / _zoomLevel;
        });
      },
      onScaleUpdate: (details) {
        setState(() {
          _zoomLevel = details.scale.clamp(0.5, 3.0);
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Rect.fromLTWH(
            _viewportOffset.dx,
            _viewportOffset.dy,
            constraints.maxWidth / _zoomLevel,
            constraints.maxHeight / _zoomLevel,
          );
          
          return Transform.scale(
            scale: _zoomLevel,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: -_viewportOffset * _zoomLevel,
              child: StaticLayer(
                size: Size(2000, 2000), // Large game area
                gameState: _gameState,
                viewport: viewport,
                zoomLevel: _zoomLevel,
              ),
            ),
          );
        },
      ),
    );
  }
}
```

### Implementing GameState

```dart
class MyGameState implements GameState {
  bool _showGrid = true;
  final List<String> _completedSections = [];
  final Map<String, dynamic> _metadata = {};
  
  @override
  bool get showGrid => _showGrid;
  
  @override
  List<String> get completedSections => _completedSections;
  
  @override
  Map<String, dynamic> get metadata => _metadata;
  
  void completeSection(String sectionId) {
    _completedSections.add(sectionId);
    // Controller will automatically invalidate the section cache
  }
}
```

## Performance Guidelines

### Cache Management

1. **Picture Caching**
   - Grid: Cached once, invalidated on size/LOD change
   - Background: Cached once, rarely invalidated
   - Sections: Cached individually, invalidated on completion
   - Effects: Not cached (animated)

2. **Cache Invalidation**
   ```dart
   // Invalidate specific elements
   controller.invalidateGrid();        // Grid changed
   controller.invalidateBackground();  // Background changed
   controller.invalidateSection(id);   // Section completed
   ```

3. **Memory Management**
   - Pictures are automatically disposed when replaced
   - Controller disposal cleans up all cached pictures
   - Monitor memory usage with performance metrics

### Optimization Tips

1. **Viewport Size**
   - Keep viewport reasonable (not entire game area)
   - Use culling to skip off-screen rendering
   - Adjust LOD based on zoom level

2. **Grid Optimization**
   - Larger grid spacing for low zoom levels
   - Skip intersection points when zoomed out
   - Use viewport culling for grid lines

3. **Section Rendering**
   - Cache completed sections individually
   - Only render sections overlapping viewport
   - Use simpler effects for distant sections

4. **Paint Object Caching**
   ```dart
   // Reuse Paint objects
   static final Map<String, Paint> _paintCache = {};
   
   Paint _getCachedPaint(String key) {
     return _paintCache.putIfAbsent(key, () => Paint());
   }
   ```

## Debug Features

### Enable Debug Mode

```dart
StaticLayer(
  // ... other parameters
  debugMode: true,  // Enables all debug features
)
```

### Debug Visualizations

1. **Cache Bounds**
   - Red: Viewport bounds
   - Blue: Cached section bounds
   - Green: Visible grid bounds

2. **Performance Overlay**
   - FPS counter
   - Average paint time
   - Cache hit rate
   - Current LOD level
   - Section count

3. **Custom Debug Flags**
   ```dart
   controller.debugShowGrid = true;
   controller.debugShowCacheBounds = true;
   controller.debugShowPerformanceOverlay = true;
   ```

## Performance Metrics

### Available Metrics

```dart
final metrics = controller.getPerformanceMetrics();

print('FPS: ${metrics.fps}');
print('Paint Time: ${metrics.averagePaintTime.inMicroseconds}μs');
print('Cache Hit Rate: ${metrics.cacheHitRate}%');
print('Samples: ${metrics.samples}');
```

### Target Performance

For 60fps on mid-range devices:
- Average paint time: < 8ms
- Cache hit rate: > 90%
- Memory usage: < 50MB for caches
- CPU usage: < 30% during idle

### Performance Monitoring

```dart
// Monitor performance in production
Timer.periodic(Duration(seconds: 1), (_) {
  final metrics = controller.getPerformanceMetrics();
  
  if (metrics.fps < 50) {
    // Reduce quality or adjust settings
    print('Performance warning: ${metrics.fps} FPS');
  }
  
  if (metrics.averagePaintTime > Duration(milliseconds: 10)) {
    // Investigate slow rendering
    print('Slow paint: ${metrics.averagePaintTime}');
  }
});
```

## Advanced Features

### Custom Effects

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Add custom background effect
void _drawCustomEffect(Canvas canvas, Size size) {
  // Define the center point
  final center = Offset(size.width / 2, size.height / 2);
  
  // Use public API to check LOD
  if (controller.getCurrentLOD() == LevelOfDetail.high) {
    // Draw complex effect only for high LOD
    final paint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [Colors.blue, Colors.purple],
      );
    canvas.drawCircle(center, 100, paint);
  }
}
```

### Dynamic Grid Patterns

```dart
class CustomGridPainter extends StaticLayerPainter {
  @override
  double _getGridSizeForLOD() {
    // Access game state through the public gameState property
    if (gameState.metadata['difficulty'] == 'hard') {
      // Use public API to get current LOD
      return controller.getCurrentLOD() == LevelOfDetail.high ? 20.0 : 40.0;
    }
    return super._getGridSizeForLOD();
  }
}
```

### Animated Backgrounds

```dart
import 'dart:math' as math;

// Animate background without invalidating cache
void _drawAnimatedParticles(Canvas canvas, Size size) {
  final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
  
  // Determine particle count based on LOD
  final particleCount = controller.getCurrentLOD() == LevelOfDetail.high ? 50 : 20;
  
  for (int i = 0; i < particleCount; i++) {
    final phase = (time + i * 0.1) % 10.0;
    final opacity = math.sin(phase * math.pi / 5.0).abs();
    
    final x = (math.sin(i * 1.7) + 1) * size.width / 2;
    final y = (phase / 10.0) * size.height;
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.3);
    
    canvas.drawCircle(
      Offset(x, y),
      2.0,
      paint,
    );
  }
}
```

## Troubleshooting

### Common Issues

1. **Low FPS**
   - Check viewport size (not too large)
   - Verify LOD system is working
   - Ensure cache invalidation isn't too frequent
   - Profile with Flutter DevTools

2. **High Memory Usage**
   - Dispose old pictures properly
   - Limit number of cached sections
   - Use lower resolution for distant LOD
   - Monitor with memory profiler

3. **Visual Glitches**
   - Verify viewport calculations
   - Check cache invalidation logic
   - Ensure proper clipping is applied
   - Test on different screen sizes

### Best Practices

1. **Always use RepaintBoundary**
   ```dart
   RepaintBoundary(
     child: CustomPaint(
       painter: StaticLayerPainter(...),
     ),
   )
   ```

2. **Dispose controllers properly**
   ```dart
   @override
   void dispose() {
     _controller.dispose();
     super.dispose();
   }
   ```

3. **Profile on target devices**
   - Test on mid-range Android devices
   - Use Flutter DevTools Timeline
   - Monitor memory usage
   - Check frame rendering times

## Conclusion

The Static Layer Renderer provides a robust foundation for rendering static game elements with excellent performance. By leveraging Picture caching, viewport culling, and LOD systems, it maintains 60fps even on mid-range devices while providing rich visual effects and smooth interactions.

Key takeaways:
- Use Picture caching for complex static graphics
- Implement viewport culling for large game areas
- Adjust detail level based on zoom
- Monitor performance metrics continuously
- Cache Paint objects to reduce allocations

For questions or improvements, refer to the example implementation or profile your specific use case with Flutter DevTools.
