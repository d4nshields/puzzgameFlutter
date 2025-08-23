part of '../hybrid_renderer.dart';

/// Controller for the static layer
class StaticLayerController extends ChangeNotifier {
  final CoordinateSystem coordinateSystem;
  final DirtyRegionTracker dirtyRegionTracker;
  
  ui.Picture? _cachedPicture;
  bool _needsRepaint = true;
  Size? _lastSize;
  GameState? _lastGameState;

  StaticLayerController({
    required this.coordinateSystem,
    required this.dirtyRegionTracker,
  });

  ui.Picture? get cachedPicture => _cachedPicture;
  bool get needsRepaint => _needsRepaint;

  void markNeedsRepaint() {
    _needsRepaint = true;
    notifyListeners();
  }

  void updatePicture(ui.Picture picture, Size size, GameState gameState) {
    _cachedPicture = picture;
    _lastSize = size;
    _lastGameState = gameState;
    _needsRepaint = false;
  }

  bool shouldRepaint(Size size, GameState gameState) {
    return _needsRepaint ||
        _cachedPicture == null ||
        _lastSize != size ||
        _hasGameStateChanged(gameState);
  }

  bool _hasGameStateChanged(GameState gameState) {
    if (_lastGameState == null) return true;
    
    // Check for changes in completed sections
    if (_lastGameState!.completedSections.length != 
        gameState.completedSections.length) {
      return true;
    }
    
    // Check for changes in grid visibility
    if (_lastGameState!.showGrid != gameState.showGrid) {
      return true;
    }
    
    return false;
  }

  @override
  void dispose() {
    _cachedPicture?.dispose();
    super.dispose();
  }
}

/// Custom painter for the static background layer
class StaticLayerPainter extends CustomPainter {
  final StaticLayerController controller;
  final GameState gameState;
  final QualityLevel quality;

  StaticLayerPainter({
    required this.controller,
    required this.gameState,
    required this.quality,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final stopwatch = Stopwatch()..start();

    // Check if we need to regenerate the picture
    if (controller.shouldRepaint(size, gameState)) {
      final picture = _recordStaticElements(size);
      controller.updatePicture(picture, size, gameState);
    }

    // Draw the cached picture
    if (controller.cachedPicture != null) {
      canvas.drawPicture(controller.cachedPicture!);
    }

    // Record frame time for performance monitoring
    if (stopwatch.elapsedMilliseconds > 8) {
      debugPrint('Static layer paint took ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  ui.Picture _recordStaticElements(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw background
    _drawBackground(canvas, size);

    // Draw puzzle grid if enabled
    if (gameState.showGrid) {
      _drawPuzzleGrid(canvas, size);
    }

    // Draw completed sections
    _drawCompletedSections(canvas, size);

    // Draw static decorations
    if (quality.enableShadows) {
      _drawStaticShadows(canvas, size);
    }

    // Draw field effects background
    _drawStaticFieldEffects(canvas, size);

    return recorder.endRecording();
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Draw gradient background
    final rect = Offset.zero & size;
    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [
        const Color(0xFF1a1a2e),
        const Color(0xFF0f0f1e),
      ],
    );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);

    // Add subtle texture overlay if high quality
    if (quality == QualityLevel.high || quality == QualityLevel.ultra) {
      _drawTextureOverlay(canvas, size);
    }
  }

  void _drawTextureOverlay(Canvas canvas, Size size) {
    // Create a subtle noise texture
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..blendMode = BlendMode.screen;

    // Draw random dots for texture
    final random = math.Random(42); // Fixed seed for consistency
    for (int i = 0; i < 500; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  void _drawPuzzleGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0 * quality.resolutionScale
      ..style = PaintingStyle.stroke;

    // Calculate grid dimensions
    const gridSize = 50.0;
    final columns = (size.width / gridSize).ceil();
    final rows = (size.height / gridSize).ceil();

    // Draw vertical lines
    for (int i = 0; i <= columns; i++) {
      final x = i * gridSize;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (int i = 0; i <= rows; i++) {
      final y = i * gridSize;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw grid intersection points with higher opacity
    if (quality == QualityLevel.high || quality == QualityLevel.ultra) {
      paint
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.fill;

      for (int i = 0; i <= columns; i++) {
        for (int j = 0; j <= rows; j++) {
          canvas.drawCircle(
            Offset(i * gridSize, j * gridSize),
            2.0 * quality.resolutionScale,
            paint,
          );
        }
      }
    }
  }

  void _drawCompletedSections(Canvas canvas, Size size) {
    // Draw completed puzzle sections with a glow effect
    for (final sectionId in gameState.completedSections) {
      final bounds = _getSectionBounds(sectionId, size);
      if (bounds != null) {
        _drawCompletedSection(canvas, bounds);
      }
    }
  }

  Rect? _getSectionBounds(String sectionId, Size size) {
    // This would normally calculate the actual bounds of a completed section
    // For now, return a placeholder
    final index = gameState.completedSections.indexOf(sectionId);
    if (index < 0) return null;

    final x = (index % 3) * (size.width / 3);
    final y = (index ~/ 3) * (size.height / 3);
    return Rect.fromLTWH(x, y, size.width / 3, size.height / 3);
  }

  void _drawCompletedSection(Canvas canvas, Rect bounds) {
    // Draw glow effect
    if (quality.enableShadows) {
      final glowPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..style = PaintingStyle.fill;

      canvas.drawRect(bounds, glowPaint);
    }

    // Draw section background
    final backgroundPaint = Paint()
      ..color = Colors.green.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(bounds, backgroundPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.5)
      ..strokeWidth = 2.0 * quality.resolutionScale
      ..style = PaintingStyle.stroke;

    canvas.drawRect(bounds, borderPaint);
  }

  void _drawStaticShadows(Canvas canvas, Size size) {
    // Draw ambient shadows for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    // Top shadow
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 50),
      shadowPaint,
    );

    // Bottom shadow
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 50, size.width, 50),
      shadowPaint,
    );

    // Left shadow
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 50, size.height),
      shadowPaint,
    );

    // Right shadow
    canvas.drawRect(
      Rect.fromLTWH(size.width - 50, 0, 50, size.height),
      shadowPaint,
    );
  }

  void _drawStaticFieldEffects(Canvas canvas, Size size) {
    // Draw magnetic field visualization background
    if (quality == QualityLevel.ultra) {
      _drawMagneticFieldGrid(canvas, size);
    }
  }

  void _drawMagneticFieldGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.05)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Create a warped grid effect to represent magnetic field
    const gridSpacing = 30.0;
    final columns = (size.width / gridSpacing).ceil();
    final rows = (size.height / gridSpacing).ceil();

    for (int i = 0; i <= columns; i++) {
      final path = Path();
      for (int j = 0; j <= rows; j++) {
        final x = i * gridSpacing;
        final y = j * gridSpacing;
        
        // Add some wave distortion
        final waveX = x + math.sin(y / 50) * 5;
        
        if (j == 0) {
          path.moveTo(waveX, y);
        } else {
          path.lineTo(waveX, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    for (int j = 0; j <= rows; j++) {
      final path = Path();
      for (int i = 0; i <= columns; i++) {
        final x = i * gridSpacing;
        final y = j * gridSpacing;
        
        // Add some wave distortion
        final waveY = y + math.sin(x / 50) * 5;
        
        if (i == 0) {
          path.moveTo(x, waveY);
        } else {
          path.lineTo(x, waveY);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(StaticLayerPainter oldDelegate) {
    return oldDelegate.gameState != gameState ||
           oldDelegate.quality != quality ||
           controller.needsRepaint;
  }
}
