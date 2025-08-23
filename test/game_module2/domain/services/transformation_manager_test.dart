import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/coordinate_system.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/transformation_manager.dart';

void main() {
  group('TransformationManager Performance Tests', () {
    late TransformationManager transformManager;
    late CoordinateSystem coordSystem;

    setUp(() {
      const config = CoordinateSystemConfig(
        devicePixelRatio: 2.0,
        canvasSize: ui.Size(800, 600),
        gridCellSize: 50.0,
        gridWidth: 20,
        gridHeight: 15,
        workspaceBounds: ui.Rect.fromLTWH(0, 0, 1600, 1200),
        zoomLevel: 1.0,
        panOffset: ui.Offset.zero,
      );
      
      coordSystem = CoordinateSystem(config);
      transformManager = TransformationManager(
        coordSystem: coordSystem,
        cacheConfig: const TransformCacheConfig(
          maxEntries: 1000,
          ttl: Duration(minutes: 5),
          enableMetrics: true,
          targetHitRate: 0.9,
        ),
        enableRecording: true,
      );
    });

    tearDown(() {
      transformManager.dispose();
    });

    group('Cache Performance', () {
      test('achieves > 90% cache hit rate with repeated transformations', () async {
        // Start recording
        transformManager.startRecording();
        
        // Create a set of points that will be reused
        final points = List.generate(100, (i) => ScreenPoint(i * 10.0, i * 10.0));
        
        // First pass - all cache misses
        for (final point in points) {
          await transformManager.transform<ScreenPoint, CanvasPoint>(
            from: point,
            transformType: 'screen_to_canvas',
            transformer: (p) => coordSystem.screenToCanvas(p),
          );
        }
        
        // Next 9 passes - all should be cache hits
        for (int iteration = 1; iteration < 10; iteration++) {
          for (final point in points) {
            await transformManager.transform<ScreenPoint, CanvasPoint>(
              from: point,
              transformType: 'screen_to_canvas',
              transformer: (p) => coordSystem.screenToCanvas(p),
            );
          }
        }
        
        // Get metrics
        final metrics = transformManager.getMetrics();
        final cacheMetrics = metrics['cache'] as Map<String, dynamic>;
        final hitRate = cacheMetrics['hitRate'] as double;
        
        // Debug output
        print('Cache hits: ${cacheMetrics['totalHits']}');
        print('Cache misses: ${cacheMetrics['totalMisses']}');
        print('Hit rate: $hitRate');
        
        expect(hitRate, greaterThanOrEqualTo(0.9));
        expect(cacheMetrics['meetsTarget'], isTrue);
        
        // Verify cache is working
        expect(cacheMetrics['totalHits'], equals(900)); // 9 iterations * 100 points
        expect(cacheMetrics['totalMisses'], equals(100)); // Only first iteration
      });

      test('LRU eviction works correctly', () async {
        // Create a cache with small size
        final smallCacheManager = TransformationManager(
          coordSystem: coordSystem,
          cacheConfig: const TransformCacheConfig(
            maxEntries: 10,
            ttl: Duration(minutes: 5),
            enableMetrics: true,
          ),
        );
        
        // Add more items than cache can hold
        final points = List.generate(20, (i) => ScreenPoint(i.toDouble(), i.toDouble()));
        
        for (final point in points) {
          await smallCacheManager.transform<ScreenPoint, CanvasPoint>(
            from: point,
            transformType: 'screen_to_canvas',
            transformer: (p) => coordSystem.screenToCanvas(p),
          );
        }
        
        final metrics = smallCacheManager.getMetrics();
        final cacheMetrics = metrics['cache'] as Map<String, dynamic>;
        
        expect(cacheMetrics['currentSize'], lessThanOrEqualTo(10));
        expect(cacheMetrics['evictions'], greaterThan(0));
        
        smallCacheManager.dispose();
      });

      test('TTL expiration works correctly', () async {
        // Create cache with very short TTL
        final shortTtlManager = TransformationManager(
          coordSystem: coordSystem,
          cacheConfig: const TransformCacheConfig(
            maxEntries: 100,
            ttl: Duration(milliseconds: 100),
            enableMetrics: true,
          ),
        );
        
        final point = const ScreenPoint(100, 100);
        
        // First transformation - should miss cache
        final result1 = await shortTtlManager.transform<ScreenPoint, CanvasPoint>(
          from: point,
          transformType: 'screen_to_canvas',
          transformer: (p) => coordSystem.screenToCanvas(p),
        );
        expect(result1.wasFromCache, isFalse);
        
        // Immediate second transformation - should hit cache
        final result2 = await shortTtlManager.transform<ScreenPoint, CanvasPoint>(
          from: point,
          transformType: 'screen_to_canvas',
          transformer: (p) => coordSystem.screenToCanvas(p),
        );
        expect(result2.wasFromCache, isTrue);
        
        // Wait for TTL to expire
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Third transformation - should miss cache due to expiration
        final result3 = await shortTtlManager.transform<ScreenPoint, CanvasPoint>(
          from: point,
          transformType: 'screen_to_canvas',
          transformer: (p) => coordSystem.screenToCanvas(p),
        );
        expect(result3.wasFromCache, isFalse);
        
        shortTtlManager.dispose();
      });
    });

    group('Batch Transformation Performance', () {
      test('handles 1000+ simultaneous transformations efficiently', () async {
        // Generate 1000 points
        final random = math.Random(42);
        final points = List.generate(1000, (i) => 
          ScreenPoint(
            random.nextDouble() * 800,
            random.nextDouble() * 600,
          ),
        );
        
        // Perform batch transformation
        final stopwatch = Stopwatch()..start();
        
        final result = await transformManager.batchTransform<ScreenPoint, CanvasPoint>(
          points: points,
          transformType: 'screen_to_canvas',
          transformer: (p) => coordSystem.screenToCanvas(p),
        );
        
        stopwatch.stop();
        
        // Verify all points were transformed
        expect(result.results.length, equals(1000));
        expect(result.results.where((r) => r != null).length, equals(1000));
        
        // Verify performance (should complete in reasonable time)
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be very fast
        
        // Check throughput
        final pointsPerSecond = 1000 / (stopwatch.elapsedMicroseconds / 1000000.0);
        expect(pointsPerSecond, greaterThan(10000)); // Should handle > 10k points/second
      });

      test('batch transformation uses cache effectively', () async {
        // Use unique points that are guaranteed to be within grid bounds
        // Grid is 20x15 with cell size 50, so valid canvas range is 0-1000 x 0-750
        final points = <CanvasPoint>[];
        for (int i = 0; i < 10; i++) {
          for (int j = 0; j < 10; j++) {
            points.add(CanvasPoint(i * 40.0, j * 40.0));
          }
        }
        
        // Verify we have 100 unique points
        expect(points.length, equals(100));
        expect(points.toSet().length, equals(100), 
          reason: 'All points should be unique');
        
        // Verify all points are valid
        for (final point in points) {
          final gridPoint = coordSystem.canvasToGrid(point);
          expect(gridPoint, isNotNull, 
            reason: 'Point $point should map to valid grid position');
        }
        
        // First batch - all cache misses
        final result1 = await transformManager.batchTransform<CanvasPoint, GridPoint?>(
          points: points,
          transformType: 'canvas_to_grid_batch',
          transformer: (p) => coordSystem.canvasToGrid(p),
        );
        
        print('First batch - hits: ${result1.cacheHits}, misses: ${result1.cacheMisses}');
        print('Results with nulls: ${result1.results.where((r) => r == null).length}');
        expect(result1.cacheMisses, equals(100));
        expect(result1.cacheHits, equals(0));
        
        // Second batch - all cache hits
        final result2 = await transformManager.batchTransform<CanvasPoint, GridPoint?>(
          points: points,
          transformType: 'canvas_to_grid_batch',
          transformer: (p) => coordSystem.canvasToGrid(p),
        );
        
        print('Second batch - hits: ${result2.cacheHits}, misses: ${result2.cacheMisses}');
        expect(result2.cacheHits, equals(100));
        expect(result2.cacheMisses, equals(0));
        expect(result2.cacheHitRate, equals(1.0));
      });

      test('handles mixed batch sizes efficiently', () async {
        // Test various batch sizes
        final batchSizes = [1, 10, 100, 500, 1000, 2000];
        final results = <int, Duration>{};
        
        for (final size in batchSizes) {
          final points = List.generate(size, (i) => 
            GridPoint(i % 20, i ~/ 20),
          );
          
          final stopwatch = Stopwatch()..start();
          
          await transformManager.batchTransform<GridPoint, CanvasPoint>(
            points: points,
            transformType: 'grid_to_canvas',
            transformer: (p) => coordSystem.gridToCanvas(p),
          );
          
          stopwatch.stop();
          results[size] = stopwatch.elapsed;
        }
        
        // Verify linear or better scaling
        for (int i = 1; i < batchSizes.length; i++) {
          final size1 = batchSizes[i - 1];
          final size2 = batchSizes[i];
          final time1 = results[size1]!.inMicroseconds;
          final time2 = results[size2]!.inMicroseconds;
          
          // Time should scale sub-linearly due to caching and optimization
          final expectedMaxTime = time1 * (size2 / size1) * 1.5; // Allow 50% overhead
          expect(time2, lessThan(expectedMaxTime));
        }
      });
    });

    group('Interpolation Performance', () {
      test('maintains target FPS during interpolation', () async {
        final interpolator = transformManager.createInterpolation(
          duration: const Duration(seconds: 1),
          mode: InterpolationMode.easeInOut,
          fps: 60,
        );
        
        final from = const CanvasPoint(0, 0);
        final to = const CanvasPoint(800, 600);
        
        final frames = <CanvasPoint>[];
        final frameTimes = <DateTime>[];
        
        await for (final point in interpolator.interpolateCanvas(from, to)) {
          frames.add(point);
          frameTimes.add(DateTime.now());
        }
        
        // Should generate approximately 60 frames for 1 second
        expect(frames.length, greaterThan(55));
        expect(frames.length, lessThan(65));
        
        // Verify smooth interpolation
        expect(frames.first, equals(from));
        expect(frames.last, equals(to));
        
        // Check frame timing consistency
        if (frameTimes.length > 1) {
          final frameDeltas = <int>[];
          for (int i = 1; i < frameTimes.length; i++) {
            frameDeltas.add(
              frameTimes[i].difference(frameTimes[i - 1]).inMicroseconds,
            );
          }
          
          // Average frame time should be close to 16.67ms (60 FPS)
          final avgFrameTime = frameDeltas.reduce((a, b) => a + b) / frameDeltas.length;
          expect(avgFrameTime, closeTo(16667, 5000)); // Allow some variance
        }
      });

      test('different easing modes produce different curves', () async {
        final modes = [
          InterpolationMode.linear,
          InterpolationMode.easeIn,
          InterpolationMode.easeOut,
          InterpolationMode.easeInOut,
          InterpolationMode.cubic,
        ];
        
        final results = <InterpolationMode, List<double>>{};
        
        for (final mode in modes) {
          final interpolator = transformManager.createInterpolation(
            duration: const Duration(milliseconds: 100),
            mode: mode,
            fps: 10, // Low FPS for testing
          );
          
          final values = <double>[];
          await for (final value in interpolator.interpolateZoom(1.0, 2.0)) {
            values.add(value);
          }
          
          results[mode] = values;
        }
        
        // Verify different modes produce different curves
        final linearValues = results[InterpolationMode.linear]!;
        
        for (final mode in modes) {
          if (mode != InterpolationMode.linear) {
            final values = results[mode]!;
            
            // Mid-point values should differ from linear
            if (values.length > 2) {
              final midIndex = values.length ~/ 2;
              expect(
                values[midIndex],
                isNot(closeTo(linearValues[midIndex], 0.01)),
                reason: '$mode should differ from linear interpolation',
              );
            }
          }
        }
      });
    });

    group('Thread Safety', () {
      test('handles concurrent transformations safely', () async {
        // Create many concurrent transformation requests
        final futures = <Future<TransformResult<CanvasPoint>>>[];
        
        // Same points accessed concurrently
        final points = List.generate(10, (i) => ScreenPoint(i * 10.0, i * 10.0));
        
        // Launch 100 concurrent operations on the same 10 points
        for (int i = 0; i < 100; i++) {
          final point = points[i % points.length];
          futures.add(
            transformManager.transform<ScreenPoint, CanvasPoint>(
              from: point,
              transformType: 'screen_to_canvas',
              transformer: (p) => coordSystem.screenToCanvas(p),
            ),
          );
        }
        
        // Wait for all to complete
        final results = await Future.wait(futures);
        
        // Verify all completed successfully
        expect(results.length, equals(100));
        
        // Verify consistent results for same input
        final resultsByInput = <String, Set<String>>{};
        for (int i = 0; i < results.length; i++) {
          final inputKey = '${points[i % points.length].x},${points[i % points.length].y}';
          final outputKey = '${results[i].result.x},${results[i].result.y}';
          resultsByInput.putIfAbsent(inputKey, () => <String>{}).add(outputKey);
        }
        
        // Each input should produce exactly one unique output
        for (final outputs in resultsByInput.values) {
          expect(outputs.length, equals(1), reason: 'Same input should produce same output');
        }
      });

      test('batch operations are thread-safe', () async {
        // Launch multiple batch operations concurrently
        final futures = <Future<BatchTransformResult<GridPoint?>>>[];
        
        final pointSets = List.generate(10, (setIndex) =>
          List.generate(100, (i) => 
            CanvasPoint(setIndex * 100.0 + i, i.toDouble()),
          ),
        );
        
        // Launch concurrent batch operations
        for (final points in pointSets) {
          futures.add(
            transformManager.batchTransform<CanvasPoint, GridPoint?>(
              points: points,
              transformType: 'canvas_to_grid',
              transformer: (p) => coordSystem.canvasToGrid(p),
            ),
          );
        }
        
        final results = await Future.wait(futures);
        
        // Verify all batches completed
        expect(results.length, equals(10));
        
        for (final result in results) {
          expect(result.results.length, equals(100));
        }
      });
    });

    group('Recording and Metrics', () {
      test('recorder captures transformation details', () async {
        transformManager.startRecording();
        
        // Perform various transformations
        final operations = [
          () async => transformManager.transform<ScreenPoint, CanvasPoint>(
            from: const ScreenPoint(100, 100),
            transformType: 'screen_to_canvas',
            transformer: (p) => coordSystem.screenToCanvas(p),
          ),
          () async => transformManager.transform<CanvasPoint, GridPoint?>(
            from: const CanvasPoint(200, 200),
            transformType: 'canvas_to_grid',
            transformer: (p) => coordSystem.canvasToGrid(p),
          ),
          () async => transformManager.transform<GridPoint, CanvasPoint>(
            from: const GridPoint(5, 5),
            transformType: 'grid_to_canvas',
            transformer: (p) => coordSystem.gridToCanvas(p),
          ),
        ];
        
        // Execute operations multiple times
        for (int i = 0; i < 10; i++) {
          for (final op in operations) {
            await op();
          }
        }
        
        transformManager.stopRecording();
        
        // Get summary
        final metrics = transformManager.getMetrics();
        final recorderSummary = metrics['recorder'] as Map<String, dynamic>;
        
        expect(recorderSummary['totalRecords'], equals(30));
        
        final types = recorderSummary['types'] as Map<String, dynamic>;
        expect(types.keys.length, equals(3));
        
        // Verify each type was recorded
        for (final typeData in types.values) {
          final data = typeData as Map<String, dynamic>;
          expect(data['count'], equals(10));
          expect(data['cacheHits'], greaterThan(0)); // Should have cache hits after first run
        }
      });

      test('exports records in analyzable format', () async {
        transformManager.startRecording();
        
        // Perform some transformations
        for (int i = 0; i < 5; i++) {
          await transformManager.transform<ScreenPoint, CanvasPoint>(
            from: ScreenPoint(i * 10.0, i * 10.0),
            transformType: 'screen_to_canvas',
            transformer: (p) => coordSystem.screenToCanvas(p),
          );
        }
        
        transformManager.stopRecording();
        
        final records = transformManager.exportRecords();
        
        expect(records.length, equals(5));
        
        for (final record in records) {
          expect(record.containsKey('timestamp'), isTrue);
          expect(record.containsKey('type'), isTrue);
          expect(record.containsKey('from'), isTrue);
          expect(record.containsKey('to'), isTrue);
          expect(record.containsKey('executionTimeUs'), isTrue);
          expect(record.containsKey('wasFromCache'), isTrue);
        }
      });

      test('performance metrics track throughput', () async {
        // Perform many operations
        final points = List.generate(500, (i) => 
          ScreenPoint(i.toDouble(), i.toDouble()),
        );
        
        await transformManager.batchTransform<ScreenPoint, CanvasPoint>(
          points: points,
          transformType: 'screen_to_canvas',
          transformer: (p) => coordSystem.screenToCanvas(p),
        );
        
        final metrics = transformManager.getMetrics();
        final perfMetrics = metrics['performance'] as Map<String, dynamic>;
        
        expect(perfMetrics.containsKey('batchOperations'), isTrue);
        
        final batchMetrics = perfMetrics['batchOperations'] as Map<String, dynamic>;
        expect(batchMetrics['totalPoints'], equals(500));
        expect(batchMetrics['throughput'], greaterThan(1000)); // Points per second
      });
    });

    group('Memory Efficiency', () {
      test('cache respects memory limits', () async {
        final cacheManager = TransformationManager(
          coordSystem: coordSystem,
          cacheConfig: const TransformCacheConfig(
            maxEntries: 100,
            enableMetrics: true,
          ),
        );
        
        // Add many unique transformations
        for (int i = 0; i < 200; i++) {
          await cacheManager.transform<ScreenPoint, CanvasPoint>(
            from: ScreenPoint(i.toDouble(), i.toDouble()),
            transformType: 'screen_to_canvas',
            transformer: (p) => coordSystem.screenToCanvas(p),
          );
        }
        
        final metrics = cacheManager.getMetrics();
        final cacheMetrics = metrics['cache'] as Map<String, dynamic>;
        
        // Cache should not exceed max size
        expect(cacheMetrics['currentSize'], lessThanOrEqualTo(100));
        expect(cacheMetrics['evictions'], equals(100)); // Should have evicted 100 entries
        
        cacheManager.dispose();
      });

      test('clears resources on reset', () async {
        // Populate cache and recorder
        for (int i = 0; i < 50; i++) {
          await transformManager.transform<ScreenPoint, CanvasPoint>(
            from: ScreenPoint(i.toDouble(), i.toDouble()),
            transformType: 'screen_to_canvas',
            transformer: (p) => coordSystem.screenToCanvas(p),
          );
        }
        
        transformManager.reset();
        
        final metrics = transformManager.getMetrics();
        final cacheMetrics = metrics['cache'] as Map<String, dynamic>;
        
        expect(cacheMetrics['currentSize'], equals(0));
        expect(cacheMetrics['totalHits'], equals(0));
        expect(cacheMetrics['totalMisses'], equals(0));
      });
    });

    group('Real-world Scenarios', () {
      test('handles puzzle piece drag operation efficiently', () async {
        // Simulate dragging a puzzle piece across the screen
        const startPoint = ScreenPoint(100, 100);
        const endPoint = ScreenPoint(500, 400);
        const steps = 60; // 60 frames of movement
        
        final dragPoints = <ScreenPoint>[];
        for (int i = 0; i <= steps; i++) {
          final t = i / steps;
          dragPoints.add(ScreenPoint(
            startPoint.x + (endPoint.x - startPoint.x) * t,
            startPoint.y + (endPoint.y - startPoint.y) * t,
          ));
        }
        
        final stopwatch = Stopwatch()..start();
        
        // Transform all drag points to grid coordinates to check valid positions
        final result = await transformManager.batchTransform<ScreenPoint, GridPoint?>(
          points: dragPoints,
          transformType: 'screen_to_grid',
          transformer: (p) {
            final canvas = coordSystem.screenToCanvas(p);
            return coordSystem.canvasToGrid(canvas);
          },
        );
        
        stopwatch.stop();
        
        // Should complete quickly enough for smooth animation
        expect(stopwatch.elapsedMilliseconds, lessThan(16)); // Single frame time
        expect(result.results.length, equals(61));
        
        // Some points should be valid grid positions
        final validPositions = result.results.where((r) => r != null).length;
        expect(validPositions, greaterThan(0));
      });

      test('handles zoom operation with many pieces efficiently', () async {
        // Simulate zooming with many puzzle pieces on screen
        final piecePositions = <GridPoint>[];
        for (int x = 0; x < 20; x++) {
          for (int y = 0; y < 15; y++) {
            piecePositions.add(GridPoint(x, y));
          }
        }
        
        // Transform all pieces before zoom
        final beforeZoom = await transformManager.batchTransform<GridPoint, CanvasPoint>(
          points: piecePositions,
          transformType: 'grid_to_canvas_zoom1',
          transformer: (p) => coordSystem.gridToCanvas(p),
        );
        
        // Update coordinate system with zoom
        coordSystem.updateConfig(CoordinateSystemConfig(
          devicePixelRatio: 2.0,
          canvasSize: const ui.Size(800, 600),
          gridCellSize: 50.0,
          gridWidth: 20,
          gridHeight: 15,
          workspaceBounds: const ui.Rect.fromLTWH(0, 0, 1600, 1200),
          zoomLevel: 2.0, // 2x zoom
          panOffset: ui.Offset.zero,
        ));
        
        // Clear cache since coordinate system changed
        transformManager.reset();
        
        // Transform all pieces after zoom
        final afterZoom = await transformManager.batchTransform<GridPoint, CanvasPoint>(
          points: piecePositions,
          transformType: 'grid_to_canvas_zoom2',
          transformer: (p) => coordSystem.gridToCanvas(p),
        );
        
        expect(beforeZoom.results.length, equals(300));
        expect(afterZoom.results.length, equals(300));
        
        // Verify zoom applied (positions should be different)
        for (int i = 0; i < piecePositions.length; i++) {
          if (beforeZoom.results[i] != null && afterZoom.results[i] != null) {
            expect(
              afterZoom.results[i]!.x,
              isNot(equals(beforeZoom.results[i]!.x)),
              reason: 'Zoom should change canvas positions',
            );
          }
        }
      });
    });
  });
}
