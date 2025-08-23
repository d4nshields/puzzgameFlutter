import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/coordinate_system.dart';

void main() {
  group('CoordinateSystem', () {
    late CoordinateSystem coordinateSystem;
    late CoordinateSystemConfig defaultConfig;

    setUp(() {
      defaultConfig = const CoordinateSystemConfig(
        devicePixelRatio: 2.0,
        canvasSize: ui.Size(800, 600),
        gridCellSize: 50.0,
        gridWidth: 10,
        gridHeight: 8,
        workspaceBounds: ui.Rect.fromLTWH(0, 0, 1600, 1200),
        zoomLevel: 1.0,
        panOffset: ui.Offset.zero,
      );
      coordinateSystem = CoordinateSystem(defaultConfig);
    });

    group('Point Classes', () {
      test('ScreenPoint equality and hashCode', () {
        const point1 = ScreenPoint(100, 200);
        const point2 = ScreenPoint(100, 200);
        const point3 = ScreenPoint(100, 201);

        expect(point1, equals(point2));
        expect(point1.hashCode, equals(point2.hashCode));
        expect(point1, isNot(equals(point3)));
      });

      test('CanvasPoint equality and hashCode', () {
        const point1 = CanvasPoint(50.5, 100.5);
        const point2 = CanvasPoint(50.5, 100.5);
        const point3 = CanvasPoint(50.5, 100.6);

        expect(point1, equals(point2));
        expect(point1.hashCode, equals(point2.hashCode));
        expect(point1, isNot(equals(point3)));
      });

      test('GridPoint equality and hashCode', () {
        const point1 = GridPoint(5, 3);
        const point2 = GridPoint(5, 3);
        const point3 = GridPoint(5, 4);

        expect(point1, equals(point2));
        expect(point1.hashCode, equals(point2.hashCode));
        expect(point1, isNot(equals(point3)));
      });

      test('WorkspacePoint equality and hashCode', () {
        const point1 = WorkspacePoint(250.0, 350.0);
        const point2 = WorkspacePoint(250.0, 350.0);
        const point3 = WorkspacePoint(250.0, 350.1);

        expect(point1, equals(point2));
        expect(point1.hashCode, equals(point2.hashCode));
        expect(point1, isNot(equals(point3)));
      });
    });

    group('Screen ↔ Canvas Transformations', () {
      test('screenToCanvas converts correctly with device pixel ratio', () {
        const screenPoint = ScreenPoint(200, 300);
        final canvasPoint = coordinateSystem.screenToCanvas(screenPoint);

        // With devicePixelRatio = 2.0, screen coordinates should be halved
        expect(canvasPoint.x, equals(100));
        expect(canvasPoint.y, equals(150));
      });

      test('canvasToScreen converts correctly with device pixel ratio', () {
        const canvasPoint = CanvasPoint(100, 150);
        final screenPoint = coordinateSystem.canvasToScreen(canvasPoint);

        // With devicePixelRatio = 2.0, canvas coordinates should be doubled
        expect(screenPoint.x, equals(200));
        expect(screenPoint.y, equals(300));
      });

      test('round-trip screen ↔ canvas conversion maintains precision', () {
        const originalScreen = ScreenPoint(123.456, 789.012);
        final canvas = coordinateSystem.screenToCanvas(originalScreen);
        final backToScreen = coordinateSystem.canvasToScreen(canvas);

        expect(backToScreen.x, closeTo(originalScreen.x, 0.001));
        expect(backToScreen.y, closeTo(originalScreen.y, 0.001));
      });
    });

    group('Canvas ↔ Grid Transformations', () {
      test('canvasToGrid converts correctly with default settings', () {
        // Grid cell size is 50, so canvas point (75, 125) should be in grid cell (1, 2)
        const canvasPoint = CanvasPoint(75, 125);
        final gridPoint = coordinateSystem.canvasToGrid(canvasPoint);

        expect(gridPoint, isNotNull);
        expect(gridPoint!.x, equals(1)); // 75 / 50 = 1.5, floors to 1
        expect(gridPoint.y, equals(2)); // 125 / 50 = 2.5, floors to 2
      });

      test('canvasToGrid returns null for out-of-bounds points', () {
        const outOfBoundsPoint = CanvasPoint(-100, -100);
        final gridPoint = coordinateSystem.canvasToGrid(outOfBoundsPoint);

        expect(gridPoint, isNull);
      });

      test('canvasToGrid respects grid boundaries', () {
        // Grid is 10x8, so valid indices are 0-9 for x, 0-7 for y
        const edgePoint = CanvasPoint(495, 395); // Just inside the last cell (9,7)
        final gridPoint = coordinateSystem.canvasToGrid(edgePoint);

        expect(gridPoint, isNotNull);
        expect(gridPoint!.x, equals(9)); // 495 / 50 = 9.9, floors to 9
        expect(gridPoint.y, equals(7)); // 395 / 50 = 7.9, floors to 7
      });

      test('gridToCanvas returns center of grid cell', () {
        const gridPoint = GridPoint(2, 3);
        final canvasPoint = coordinateSystem.gridToCanvas(gridPoint);

        // Grid cell (2, 3) with cell size 50 should have center at (125, 175)
        expect(canvasPoint.x, equals(125)); // (2 + 0.5) * 50
        expect(canvasPoint.y, equals(175)); // (3 + 0.5) * 50
      });

      test('gridCellToCanvasBounds returns correct bounds', () {
        const gridPoint = GridPoint(1, 2);
        final bounds = coordinateSystem.gridCellToCanvasBounds(gridPoint);

        expect(bounds.left, equals(50)); // 1 * 50
        expect(bounds.top, equals(100)); // 2 * 50
        expect(bounds.width, equals(50));
        expect(bounds.height, equals(50));
      });
    });

    group('Canvas ↔ Grid with Zoom and Pan', () {
      test('canvasToGrid with zoom applied', () {
        // Apply 2x zoom
        coordinateSystem.updateConfig(CoordinateSystemConfig(
          devicePixelRatio: defaultConfig.devicePixelRatio,
          canvasSize: defaultConfig.canvasSize,
          gridCellSize: defaultConfig.gridCellSize,
          gridWidth: defaultConfig.gridWidth,
          gridHeight: defaultConfig.gridHeight,
          workspaceBounds: defaultConfig.workspaceBounds,
          zoomLevel: 2.0,
          panOffset: ui.Offset.zero,
        ));

        const canvasPoint = CanvasPoint(100, 100);
        final gridPoint = coordinateSystem.canvasToGrid(canvasPoint);

        // With 2x zoom, effective cell size is 100, so (100, 100) should be grid (1, 1)
        expect(gridPoint, isNotNull);
        expect(gridPoint!.x, equals(1));
        expect(gridPoint.y, equals(1));
      });

      test('canvasToGrid with pan applied', () {
        // Apply pan offset
        coordinateSystem.updateConfig(CoordinateSystemConfig(
          devicePixelRatio: defaultConfig.devicePixelRatio,
          canvasSize: defaultConfig.canvasSize,
          gridCellSize: defaultConfig.gridCellSize,
          gridWidth: defaultConfig.gridWidth,
          gridHeight: defaultConfig.gridHeight,
          workspaceBounds: defaultConfig.workspaceBounds,
          zoomLevel: 1.0,
          panOffset: const ui.Offset(50, 50),
        ));

        const canvasPoint = CanvasPoint(100, 100);
        final gridPoint = coordinateSystem.canvasToGrid(canvasPoint);

        // With pan offset (50, 50), canvas (100, 100) maps to grid (1, 1)
        expect(gridPoint, isNotNull);
        expect(gridPoint!.x, equals(1));
        expect(gridPoint.y, equals(1));
      });
    });

    group('Canvas ↔ Workspace Transformations', () {
      test('canvasToWorkspace scales correctly', () {
        // Canvas is 800x600, workspace is 1600x1200 (2x scale)
        const canvasPoint = CanvasPoint(400, 300);
        final workspacePoint = coordinateSystem.canvasToWorkspace(canvasPoint);

        expect(workspacePoint.x, equals(800)); // 400 * 2
        expect(workspacePoint.y, equals(600)); // 300 * 2
      });

      test('workspaceToCanvas scales correctly', () {
        const workspacePoint = WorkspacePoint(800, 600);
        final canvasPoint = coordinateSystem.workspaceToCanvas(workspacePoint);

        expect(canvasPoint.x, equals(400)); // 800 / 2
        expect(canvasPoint.y, equals(300)); // 600 / 2
      });

      test('round-trip canvas ↔ workspace conversion maintains precision', () {
        const originalCanvas = CanvasPoint(123.456, 234.567);
        final workspace = coordinateSystem.canvasToWorkspace(originalCanvas);
        final backToCanvas = coordinateSystem.workspaceToCanvas(workspace);

        expect(backToCanvas.x, closeTo(originalCanvas.x, 0.001));
        expect(backToCanvas.y, closeTo(originalCanvas.y, 0.001));
      });
    });

    group('Composite Transformations', () {
      test('screenToGrid chains transformations correctly', () {
        const screenPoint = ScreenPoint(200, 300);
        final gridPoint = coordinateSystem.screenToGrid(screenPoint);

        // Screen (200, 300) → Canvas (100, 150) → Grid (2, 3)
        expect(gridPoint, isNotNull);
        expect(gridPoint!.x, equals(2)); // 100 / 50 = 2
        expect(gridPoint.y, equals(3)); // 150 / 50 = 3
      });

      test('gridToScreen chains transformations correctly', () {
        const gridPoint = GridPoint(2, 3);
        final screenPoint = coordinateSystem.gridToScreen(gridPoint);

        // Grid (2, 3) → Canvas (125, 175) → Screen (250, 350)
        expect(screenPoint.x, equals(250));
        expect(screenPoint.y, equals(350));
      });

      test('screenToWorkspace chains transformations correctly', () {
        const screenPoint = ScreenPoint(400, 300);
        final workspacePoint = coordinateSystem.screenToWorkspace(screenPoint);

        // Screen (400, 300) → Canvas (200, 150) → Workspace (400, 300)
        expect(workspacePoint.x, equals(400));
        expect(workspacePoint.y, equals(300));
      });

      test('gridToWorkspace chains transformations correctly', () {
        const gridPoint = GridPoint(2, 3);
        final workspacePoint = coordinateSystem.gridToWorkspace(gridPoint);

        // Grid (2, 3) → Canvas (125, 175) → Workspace (250, 350)
        expect(workspacePoint.x, equals(250));
        expect(workspacePoint.y, equals(350));
      });

      test('workspaceToGrid chains transformations correctly', () {
        const workspacePoint = WorkspacePoint(250, 350);
        final gridPoint = coordinateSystem.workspaceToGrid(workspacePoint);

        // Workspace (250, 350) → Canvas (125, 175) → Grid (2, 3)
        expect(gridPoint, isNotNull);
        expect(gridPoint!.x, equals(2)); // 125 / 50 = 2.5, floors to 2
        expect(gridPoint.y, equals(3)); // 175 / 50 = 3.5, floors to 3
      });
    });

    group('Utility Methods', () {
      test('isPointInCanvas validates canvas bounds', () {
        const insidePoint = ScreenPoint(400, 300);
        const outsidePoint = ScreenPoint(2000, 2000);

        expect(coordinateSystem.isPointInCanvas(insidePoint), isTrue);
        expect(coordinateSystem.isPointInCanvas(outsidePoint), isFalse);
      });

      test('isPointInGrid validates grid bounds', () {
        const insidePoint = CanvasPoint(250, 200);
        const outsidePoint = CanvasPoint(600, 500);

        expect(coordinateSystem.isPointInGrid(insidePoint), isTrue);
        expect(coordinateSystem.isPointInGrid(outsidePoint), isFalse);
      });

      test('getVisibleGridBounds returns correct bounds', () {
        final bounds = coordinateSystem.getVisibleGridBounds();

        expect(bounds.width, equals(500)); // 10 * 50 * 1.0
        expect(bounds.height, equals(400)); // 8 * 50 * 1.0
      });
    });

    group('Zoom Operations', () {
      test('applyZoom scales correctly around center point', () {
        const centerPoint = CanvasPoint(400, 300);
        
        // Find what grid position is at the center before zoom
        final gridBeforeZoom = coordinateSystem.canvasToGrid(centerPoint);
        
        coordinateSystem.applyZoom(2.0, centerPoint);
        
        expect(coordinateSystem.config.zoomLevel, equals(2.0));
        
        // The same grid position should still be at the center after zoom
        final gridAfterZoom = coordinateSystem.canvasToGrid(centerPoint);
        
        expect(gridAfterZoom, equals(gridBeforeZoom));
        
        // Also verify that a known grid point scales correctly
        // const testGridPoint = GridPoint(4, 3);
        // final canvasPoint = coordinateSystem.gridToCanvas(testGridPoint);
        
        // The grid cell size should be doubled (100 instead of 50)
        // Grid (4,3) center would be at (4.5, 3.5) in grid coords
        // At zoom 2x with proper pan offset to keep center fixed
        expect(coordinateSystem.config.gridCellSize * coordinateSystem.config.zoomLevel, equals(100));
      });

      test('applyZoom clamps to valid range', () {
        const centerPoint = CanvasPoint(400, 300);
        
        // Try to zoom too far out
        coordinateSystem.applyZoom(0.01, centerPoint);
        expect(coordinateSystem.config.zoomLevel, equals(0.1));

        // Try to zoom too far in
        coordinateSystem.applyZoom(1000, centerPoint);
        expect(coordinateSystem.config.zoomLevel, equals(10.0));
      });
    });

    group('Pan Operations', () {
      test('applyPan shifts view correctly', () {
        const delta = ui.Offset(50, 30);
        coordinateSystem.applyPan(delta);

        expect(coordinateSystem.config.panOffset, equals(delta));
      });

      test('multiple pans accumulate', () {
        coordinateSystem.applyPan(const ui.Offset(10, 20));
        coordinateSystem.applyPan(const ui.Offset(15, 25));

        expect(coordinateSystem.config.panOffset, equals(const ui.Offset(25, 45)));
      });
    });

    group('View Control', () {
      test('resetView returns to default state', () {
        // Apply some transformations
        coordinateSystem.applyZoom(2.0, const CanvasPoint(400, 300));
        coordinateSystem.applyPan(const ui.Offset(100, 50));

        // Reset
        coordinateSystem.resetView();

        expect(coordinateSystem.config.zoomLevel, equals(1.0));
        expect(coordinateSystem.config.panOffset, equals(ui.Offset.zero));
      });

      test('centerOnGridPoint centers view correctly', () {
        const targetPoint = GridPoint(5, 4);
        coordinateSystem.centerOnGridPoint(targetPoint);

        // The grid point should now be at canvas center (400, 300)
        final canvasPoint = coordinateSystem.gridToCanvas(targetPoint);
        
        // The point should be exactly at center
        expect(canvasPoint.x, equals(400));
        expect(canvasPoint.y, equals(300));
      });

      test('fitGridToView scales grid to fit canvas', () {
        coordinateSystem.fitGridToView();

        final bounds = coordinateSystem.getVisibleGridBounds();
        
        // Grid should fit within canvas with some padding
        expect(bounds.width, lessThanOrEqualTo(defaultConfig.canvasSize.width));
        expect(bounds.height, lessThanOrEqualTo(defaultConfig.canvasSize.height));
      });
    });

    group('Performance', () {
      test('transformations complete within target time', () {
        // Perform multiple transformations
        for (int i = 0; i < 100; i++) {
          final screenPoint = ScreenPoint(i.toDouble(), i.toDouble());
          coordinateSystem.screenToCanvas(screenPoint);
        }

        final avgTime = coordinateSystem.averageTransformationTimeUs;
        
        // Should be less than 100 microseconds (0.1ms)
        expect(avgTime, lessThan(100));
        
        final stats = coordinateSystem.getPerformanceStats();
        expect(stats['meetsTargetPerformance'], isTrue);
      });

      test('cached matrices improve performance', () {
        // First transformation (builds matrices)
        const point1 = ScreenPoint(100, 100);
        coordinateSystem.screenToCanvas(point1);
        
        // Clear timing samples
        for (int i = 0; i < 100; i++) {
          coordinateSystem.screenToCanvas(point1);
        }
        
        final cachedTime = coordinateSystem.averageTransformationTimeUs;

        // Update config to invalidate cache
        coordinateSystem.updateConfig(CoordinateSystemConfig(
          devicePixelRatio: 3.0, // Changed
          canvasSize: defaultConfig.canvasSize,
          gridCellSize: defaultConfig.gridCellSize,
          gridWidth: defaultConfig.gridWidth,
          gridHeight: defaultConfig.gridHeight,
          workspaceBounds: defaultConfig.workspaceBounds,
          zoomLevel: 1.0,
          panOffset: ui.Offset.zero,
        ));

        // First transformation after cache invalidation
        coordinateSystem.screenToCanvas(point1);
        
        // Cached operations should be fast
        expect(cachedTime, lessThan(100));
      });
    });

    group('Edge Cases', () {
      test('handles zero grid size gracefully', () {
        final zeroGridConfig = CoordinateSystemConfig(
          devicePixelRatio: 2.0,
          canvasSize: const ui.Size(800, 600),
          gridCellSize: 50.0,
          gridWidth: 0,
          gridHeight: 0,
          workspaceBounds: const ui.Rect.fromLTWH(0, 0, 1600, 1200),
        );
        
        final zeroSystem = CoordinateSystem(zeroGridConfig);
        const canvasPoint = CanvasPoint(100, 100);
        final gridPoint = zeroSystem.canvasToGrid(canvasPoint);
        
        expect(gridPoint, isNull); // Should return null for invalid grid
      });

      test('handles extreme zoom levels', () {
        // Use a center point that maps to a valid grid position
        // Grid is 10x8 (indices 0-9 for x, 0-7 for y)
        // Let's use grid cell (4, 3) which is safely in the middle
        // At 1x zoom, grid (4, 3) center is at canvas (225, 175)
        const safeCenter = CanvasPoint(225, 175);
        
        // Verify our starting point is correct
        final initialGrid = coordinateSystem.canvasToGrid(safeCenter);
        expect(initialGrid, isNotNull);
        expect(initialGrid!.x, equals(4)); // 225 / 50 = 4.5, floors to 4
        expect(initialGrid.y, equals(3)); // 175 / 50 = 3.5, floors to 3
        
        // Test minimum zoom (0.1)
        coordinateSystem.applyZoom(0.1, safeCenter);
        expect(coordinateSystem.config.zoomLevel, equals(0.1));
        
        // After zoom, the same grid cell should still be at the focal point
        final minZoomGridAtCenter = coordinateSystem.canvasToGrid(safeCenter);
        expect(minZoomGridAtCenter, isNotNull);
        expect(minZoomGridAtCenter!.x, equals(4));
        expect(minZoomGridAtCenter.y, equals(3));
        
        // At minimum zoom (0.1x), the grid is compressed
        // Cell size is 5 pixels, total grid is 50x40 pixels
        // The pan offset keeps grid (4,3) at canvas (225,175)
        // So the grid starts at approximately x=205, y=160
        // Test a point that's actually within the visible grid
        const validPoint = CanvasPoint(230, 180); // Near the focal point
        final validGrid = coordinateSystem.canvasToGrid(validPoint);
        expect(validGrid, isNotNull);
        expect(validGrid!.x, greaterThanOrEqualTo(0));
        expect(validGrid.x, lessThan(10));
        expect(validGrid.y, greaterThanOrEqualTo(0));
        expect(validGrid.y, lessThan(8));
        
        // Reset and test maximum zoom
        coordinateSystem.resetView();
        coordinateSystem.applyZoom(10.0, safeCenter);
        expect(coordinateSystem.config.zoomLevel, equals(10.0));
        
        // After max zoom, the same grid cell should still be at the focal point
        final maxZoomGridAtCenter = coordinateSystem.canvasToGrid(safeCenter);
        expect(maxZoomGridAtCenter, isNotNull, reason: 'Focal point should still map to valid grid');
        expect(maxZoomGridAtCenter!.x, equals(4));
        expect(maxZoomGridAtCenter.y, equals(3));
      });

      test('handles negative coordinates', () {
        coordinateSystem.applyPan(const ui.Offset(100, 100));
        
        const negativeCanvas = CanvasPoint(-50, -50);
        final gridPoint = coordinateSystem.canvasToGrid(negativeCanvas);
        
        expect(gridPoint, isNull); // Negative grid coordinates are invalid
      });

      test('handles boundary points correctly', () {
        // Exactly on grid boundary
        const boundaryPoint = CanvasPoint(500, 400);
        final gridPoint = coordinateSystem.canvasToGrid(boundaryPoint);
        
        expect(gridPoint, isNull); // Should be outside valid grid (0-9, 0-7)
      });

      test('configuration equality works correctly', () {
        final config1 = CoordinateSystemConfig(
          devicePixelRatio: 2.0,
          canvasSize: const ui.Size(800, 600),
          gridCellSize: 50.0,
          gridWidth: 10,
          gridHeight: 8,
          workspaceBounds: const ui.Rect.fromLTWH(0, 0, 1600, 1200),
        );

        final config2 = CoordinateSystemConfig(
          devicePixelRatio: 2.0,
          canvasSize: const ui.Size(800, 600),
          gridCellSize: 50.0,
          gridWidth: 10,
          gridHeight: 8,
          workspaceBounds: const ui.Rect.fromLTWH(0, 0, 1600, 1200),
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });
    });
  });
}
