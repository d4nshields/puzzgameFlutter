/// Test file for CoordinateSystem transformations
/// 
/// This test verifies that the coordinate system transformations
/// work correctly with proper matrix operation order.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;

// Simplified CoordinateSystem for testing
class CoordinateSystem {
  Size _screenSize;
  final Size gameSize;
  
  Matrix4 _screenToCanvas = Matrix4.identity();
  Matrix4 _canvasToScreen = Matrix4.identity();

  CoordinateSystem({
    required Size screenSize,
    required this.gameSize,
  }) : _screenSize = screenSize {
    _updateTransformations();
  }

  void _updateTransformations() {
    // Calculate scale factor to fit game within screen
    final scaleX = _screenSize.width / gameSize.width;
    final scaleY = _screenSize.height / gameSize.height;
    final scale = (scaleX < scaleY) ? scaleX : scaleY;
    
    // Center the game area on screen
    final offsetX = (_screenSize.width - gameSize.width * scale) / 2;
    final offsetY = (_screenSize.height - gameSize.height * scale) / 2;
    
    // Build transformation matrices
    // We want: canvas = (screen - offset) / scale
    // Create matrices separately and multiply in correct order
    final translationMatrix = Matrix4.translationValues(-offsetX, -offsetY, 0);
    final scaleMatrix = Matrix4.diagonal3Values(1 / scale, 1 / scale, 1.0);
    
    // For (screen - offset) / scale, we need: scale * translation
    _screenToCanvas = scaleMatrix.clone()..multiply(translationMatrix);
    
    // Calculate inverse
    _canvasToScreen = Matrix4.identity()..setFrom(_screenToCanvas)..invert();
  }

  Offset screenToCanvas(Offset screenPoint) {
    final vector = vector_math.Vector3(screenPoint.dx, screenPoint.dy, 0);
    final transformed = _screenToCanvas.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  Offset canvasToScreen(Offset canvasPoint) {
    final vector = vector_math.Vector3(canvasPoint.dx, canvasPoint.dy, 0);
    final transformed = _canvasToScreen.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }
}

void main() {
  group('CoordinateSystem', () {
    test('should correctly transform screen to canvas coordinates', () {
      // Setup: Screen is 800x600, game is 400x300
      final coordSystem = CoordinateSystem(
        screenSize: const Size(800, 600),
        gameSize: const Size(400, 300),
      );
      
      // The game should be scaled by 2x and centered
      // Scale = min(800/400, 600/300) = min(2, 2) = 2
      // Offset X = (800 - 400*2) / 2 = 0
      // Offset Y = (600 - 300*2) / 2 = 0
      
      // Test center of screen
      final screenCenter = const Offset(400, 300);
      final canvasCenter = coordSystem.screenToCanvas(screenCenter);
      
      // Screen center (400, 300) should map to canvas center (200, 150)
      expect(canvasCenter.dx, closeTo(200, 0.01));
      expect(canvasCenter.dy, closeTo(150, 0.01));
      
      // Test top-left corner
      final screenTopLeft = const Offset(0, 0);
      final canvasTopLeft = coordSystem.screenToCanvas(screenTopLeft);
      
      // Screen (0, 0) should map to canvas (0, 0) when centered
      expect(canvasTopLeft.dx, closeTo(0, 0.01));
      expect(canvasTopLeft.dy, closeTo(0, 0.01));
      
      // Test bottom-right corner
      final screenBottomRight = const Offset(800, 600);
      final canvasBottomRight = coordSystem.screenToCanvas(screenBottomRight);
      
      // Screen (800, 600) should map to canvas (400, 300)
      expect(canvasBottomRight.dx, closeTo(400, 0.01));
      expect(canvasBottomRight.dy, closeTo(300, 0.01));
    });
    
    test('should correctly handle off-center game area', () {
      // Setup: Screen is wider than game aspect ratio
      final coordSystem = CoordinateSystem(
        screenSize: const Size(1000, 600),
        gameSize: const Size(400, 300),
      );
      
      // Scale = min(1000/400, 600/300) = min(2.5, 2) = 2
      // Offset X = (1000 - 400*2) / 2 = 100
      // Offset Y = (600 - 300*2) / 2 = 0
      
      // Test left edge of game area
      final screenGameLeft = const Offset(100, 0);
      final canvasGameLeft = coordSystem.screenToCanvas(screenGameLeft);
      
      // Screen (100, 0) should map to canvas (0, 0)
      expect(canvasGameLeft.dx, closeTo(0, 0.01));
      expect(canvasGameLeft.dy, closeTo(0, 0.01));
      
      // Test right edge of game area
      final screenGameRight = const Offset(900, 600);
      final canvasGameRight = coordSystem.screenToCanvas(screenGameRight);
      
      // Screen (900, 600) should map to canvas (400, 300)
      expect(canvasGameRight.dx, closeTo(400, 0.01));
      expect(canvasGameRight.dy, closeTo(300, 0.01));
    });
    
    test('should correctly inverse transform canvas to screen', () {
      final coordSystem = CoordinateSystem(
        screenSize: const Size(800, 600),
        gameSize: const Size(400, 300),
      );
      
      // Test round-trip transformation
      final originalScreen = const Offset(350, 275);
      final canvas = coordSystem.screenToCanvas(originalScreen);
      final backToScreen = coordSystem.canvasToScreen(canvas);
      
      // Should get back the original screen coordinates
      expect(backToScreen.dx, closeTo(originalScreen.dx, 0.01));
      expect(backToScreen.dy, closeTo(originalScreen.dy, 0.01));
      
      // Test canvas origin
      final canvasOrigin = const Offset(0, 0);
      final screenOrigin = coordSystem.canvasToScreen(canvasOrigin);
      
      // Canvas (0, 0) should map to screen (0, 0) when game is centered
      expect(screenOrigin.dx, closeTo(0, 0.01));
      expect(screenOrigin.dy, closeTo(0, 0.01));
    });
    
    test('matrix order verification', () {
      // Verify that the matrix operations are in the correct order
      // For a point p, we want: canvas = (screen - offset) / scale
      
      final scale = 2.0;
      final offset = const Offset(100, 50);
      
      // Build matrix with correct order using explicit multiplication
      final translationMatrix = Matrix4.translationValues(-offset.dx, -offset.dy, 0);
      final scaleMatrix = Matrix4.diagonal3Values(1 / scale, 1 / scale, 1.0);
      
      // For (screen - offset) / scale, we need: scale * translation
      final correctMatrix = scaleMatrix.clone()..multiply(translationMatrix);
      
      // Test a point
      final screenPoint = const Offset(300, 250);
      final vector = vector_math.Vector3(screenPoint.dx, screenPoint.dy, 0);
      final transformed = correctMatrix.transform3(vector);
      
      // Manual calculation: (300 - 100) / 2 = 100, (250 - 50) / 2 = 100
      expect(transformed.x, closeTo(100, 0.01));
      expect(transformed.y, closeTo(100, 0.01));
    });
  });
}
