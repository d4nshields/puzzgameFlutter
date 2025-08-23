import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/coordinate_spaces.dart';

void main() {
  group('Value Objects Tests', () {
    test('All value objects are properly implemented', () {
      // Test ScreenPoint
      const screenPoint = ScreenPoint(x: 100, y: 200, devicePixelRatio: 2.0);
      expect(screenPoint.x, equals(100));
      expect(screenPoint.logicalX, equals(50));
      
      // Test CanvasPoint  
      const canvasPoint = CanvasPoint(x: 50, y: 75);
      expect(canvasPoint.isValid, isTrue);
      
      // Test GridPosition
      const gridPos = GridPosition(x: 5, y: 3, maxX: 10, maxY: 10);
      expect(gridPos.isValid, isTrue);
      
      // Test WorkspaceRegion
      const region = WorkspaceRegion(
        bounds: ui.Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(region.area, equals(10000));
    });
  });
}
