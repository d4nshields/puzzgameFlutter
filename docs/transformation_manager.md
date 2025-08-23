# Transformation Manager Documentation

## Overview

The Transformation Manager builds on the Coordinate System to provide high-performance, cached transformations with support for batch operations, interpolation, and comprehensive metrics. It's designed for mobile game development with a focus on efficiency and smooth 60 FPS performance.

## Architecture

### Core Components

1. **TransformationManager**: Main orchestrator for all transformation operations
2. **TransformCache**: LRU cache with TTL support for transformation results  
3. **BatchTransformation**: Handles efficient batch processing of multiple points
4. **InterpolatedTransform**: Smooth animations between coordinate spaces
5. **TransformationRecorder**: Debug and performance analysis tools

### Performance Guarantees

- **Cache hit rate > 90%** for repeated transformations
- **Support for 1000+ simultaneous transforms** without blocking
- **Thread-safe operations** via isolate-safe locking
- **Memory efficient** with configurable cache limits
- **< 16ms frame time** for smooth 60 FPS on mobile

## Usage

### Basic Setup

```dart
import 'package:puzzgame_flutter/game_module2/domain/services/transformation_manager.dart';

// Initialize with coordinate system
final transformManager = TransformationManager(
  coordSystem: coordinateSystem,
  cacheConfig: const TransformCacheConfig(
    maxEntries: 1000,
    ttl: Duration(minutes: 5),
    enableMetrics: true,
    targetHitRate: 0.9,
  ),
  enableRecording: true,
);
```

### Single Point Transformation

```dart
// Transform with automatic caching
final result = await transformManager.transform<ScreenPoint, CanvasPoint>(
  from: ScreenPoint(100, 200),
  transformType: 'screen_to_canvas',
  transformer: (p) => coordSystem.screenToCanvas(p),
);

print('Result: ${result.result}');
print('From cache: ${result.wasFromCache}');
print('Execution time: ${result.executionTime.inMicroseconds}μs');
```

### Batch Transformations

```dart
// Transform multiple points efficiently
final points = List.generate(1000, (i) => 
  ScreenPoint(i.toDouble(), i.toDouble())
);

final batchResult = await transformManager.batchTransform<ScreenPoint, CanvasPoint>(
  points: points,
  transformType: 'screen_to_canvas_batch',
  transformer: (p) => coordSystem.screenToCanvas(p),
);

print('Processed: ${batchResult.results.length} points');
print('Cache hit rate: ${(batchResult.cacheHitRate * 100).toStringAsFixed(2)}%');
print('Total time: ${batchResult.totalExecutionTime.inMilliseconds}ms');
```

### Animated Transformations

```dart
// Create smooth interpolation
final interpolator = transformManager.createInterpolation(
  duration: Duration(milliseconds: 300),
  mode: InterpolationMode.easeInOut,
  fps: 60,
);

// Animate between two points
final from = CanvasPoint(100, 100);
final to = CanvasPoint(500, 400);

await for (final point in interpolator.interpolateCanvas(from, to)) {
  // Update UI with interpolated point
  updatePiecePosition(point);
}
```

### Zoom Animation

```dart
// Smooth zoom transition
final zoomInterpolator = transformManager.createInterpolation(
  duration: Duration(milliseconds: 500),
  mode: InterpolationMode.cubic,
);

await for (final zoomLevel in zoomInterpolator.interpolateZoom(1.0, 2.0)) {
  coordSystem.updateConfig(
    coordSystem.config.copyWith(zoomLevel: zoomLevel),
  );
  // Redraw at new zoom level
}
```

## Advanced Features

### Cache Management

```dart
// Get cache metrics
final metrics = transformManager.getMetrics();
final cacheMetrics = metrics['cache'];
print('Hit rate: ${cacheMetrics['hitRate']}');
print('Current size: ${cacheMetrics['currentSize']}/${cacheMetrics['maxSize']}');

// Invalidate specific cache entries
transformManager.cache.invalidatePattern('screen_to_canvas.*');

// Clear entire cache
transformManager.reset();
```

### Performance Recording

```dart
// Start recording for analysis
transformManager.startRecording();

// Perform operations...
await performGameOperations();

// Stop and analyze
transformManager.stopRecording();

// Get detailed metrics
final summary = transformManager.getMetrics()['recorder'];
print('Operations recorded: ${summary['totalRecords']}');

// Export for external analysis
final records = transformManager.exportRecords();
await saveToFile(records);
```

### Thread-Safe Concurrent Operations

```dart
// Safe concurrent transformations
final futures = <Future<TransformResult>>[];

for (final point in points) {
  futures.add(
    transformManager.transform(
      from: point,
      transformType: 'concurrent_transform',
      transformer: transformer,
    )
  );
}

// All operations execute safely in parallel
final results = await Future.wait(futures);
```

## Real-World Examples

### Puzzle Piece Drag

```dart
class PieceDragHandler {
  final TransformationManager transformManager;
  
  Future<void> handleDrag(DragUpdateDetails details) async {
    // Convert touch to grid with caching
    final result = await transformManager.transform<ScreenPoint, GridPoint?>(
      from: ScreenPoint(details.globalPosition.dx, details.globalPosition.dy),
      transformType: 'drag_to_grid',
      transformer: (p) {
        final canvas = coordSystem.screenToCanvas(p);
        return coordSystem.canvasToGrid(canvas);
      },
    );
    
    if (result.result != null) {
      highlightGridCell(result.result!);
    }
    
    // Performance is guaranteed < 16ms for 60 FPS
  }
}
```

### Multi-Piece Selection

```dart
Future<void> selectPiecesInRegion(Rect selectionRect) async {
  // Get all grid positions in selection
  final gridPositions = <GridPoint>[];
  for (int x = 0; x < gridWidth; x++) {
    for (int y = 0; y < gridHeight; y++) {
      gridPositions.add(GridPoint(x, y));
    }
  }
  
  // Batch transform to check which are in selection
  final result = await transformManager.batchTransform<GridPoint, bool>(
    points: gridPositions,
    transformType: 'selection_check',
    transformer: (p) {
      final bounds = coordSystem.gridCellToCanvasBounds(p);
      return selectionRect.overlaps(bounds);
    },
  );
  
  // Process selection
  for (int i = 0; i < gridPositions.length; i++) {
    if (result.results[i] == true) {
      selectPiece(gridPositions[i]);
    }
  }
}
```

### Smooth Piece Snap Animation

```dart
Future<void> animatePieceSnap(
  WorkspacePoint from,
  GridPoint targetGrid,
) async {
  final targetCanvas = coordSystem.gridToCanvas(targetGrid);
  final targetWorkspace = coordSystem.canvasToWorkspace(targetCanvas);
  
  final interpolator = transformManager.createInterpolation(
    duration: Duration(milliseconds: 200),
    mode: InterpolationMode.easeOut,
    fps: 60,
  );
  
  await for (final pos in interpolator.interpolateWorkspace(from, targetWorkspace)) {
    updatePiecePosition(pos);
    await renderFrame();
  }
  
  // Piece is now snapped to grid
  placePieceOnGrid(targetGrid);
}
```

## Performance Optimization

### Mobile-Specific Optimizations

1. **Batch Processing**: Process transformations in chunks to avoid blocking
2. **Cache Warming**: Pre-cache common transformations during idle time
3. **Adaptive Quality**: Reduce interpolation FPS on lower-end devices
4. **Memory Management**: Automatic cache eviction prevents memory bloat

### Best Practices

1. **Reuse transformation types**: Use consistent type names for better cache hits
2. **Batch when possible**: Group related transformations together
3. **Profile regularly**: Use built-in metrics to identify bottlenecks
4. **Clear cache on context changes**: Reset cache when coordinate system changes significantly

## Benchmarking

Run the included benchmark to verify performance:

```bash
dart run lib/game_module2/domain/services/benchmark_transformations.dart
```

Expected results:
- Cache hit rate: > 90%
- Single transform: < 100μs
- Batch 1000 points: < 100ms
- Throughput: > 10,000 points/second

## API Reference

### TransformationManager

| Method | Description |
|--------|-------------|
| `transform<TFrom, TTo>()` | Transform single point with caching |
| `batchTransform<TFrom, TTo>()` | Transform multiple points efficiently |
| `createInterpolation()` | Create interpolation helper |
| `updateCoordinateSystem()` | Update underlying coordinate system |
| `getMetrics()` | Get comprehensive performance metrics |
| `startRecording()` | Begin recording operations |
| `stopRecording()` | Stop recording operations |
| `exportRecords()` | Export recorded data |
| `reset()` | Clear all caches and data |
| `dispose()` | Clean up resources |

### TransformCache

| Method | Description |
|--------|-------------|
| `get<T>()` | Retrieve cached value |
| `put<T>()` | Store value in cache |
| `getOrCompute<T>()` | Get from cache or compute |
| `invalidatePattern()` | Remove entries matching pattern |
| `clear()` | Clear entire cache |
| `getMetrics()` | Get cache statistics |

### InterpolatedTransform

| Method | Description |
|--------|-------------|
| `interpolateCanvas()` | Interpolate between canvas points |
| `interpolateWorkspace()` | Interpolate between workspace points |
| `interpolateZoom()` | Interpolate zoom levels |
| `interpolateMatrix()` | Interpolate transformation matrices |

### InterpolationMode

| Mode | Description |
|------|-------------|
| `linear` | Constant speed |
| `easeIn` | Start slow, accelerate |
| `easeOut` | Start fast, decelerate |
| `easeInOut` | Slow at both ends |
| `cubic` | Smooth cubic curve |
| `bounce` | Bounce effect |
| `elastic` | Elastic overshoot |

## Testing

Run the comprehensive test suite:

```bash
flutter test test/game_module2/domain/services/transformation_manager_test.dart
```

The test suite covers:
- Cache performance and eviction
- Batch transformation efficiency
- Thread safety
- Memory management
- Real-world scenarios
- Performance requirements

## Troubleshooting

### Low Cache Hit Rate

- Check transformation type consistency
- Verify TTL is appropriate for use case
- Ensure cache size is sufficient

### Performance Issues

- Enable metrics to identify bottlenecks
- Use batch transformations for multiple points
- Check for unnecessary cache clears
- Profile with the benchmark tool

### Memory Issues

- Reduce cache max entries
- Decrease TTL for less frequent transforms
- Use reset() to clear memory periodically
