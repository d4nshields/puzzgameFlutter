part of '../hybrid_renderer.dart';

/// Controller for the dynamic piece layer
class DynamicLayerController extends ChangeNotifier {
  final CoordinateSystem coordinateSystem;
  final QualityManager qualityManager;
  
  List<RenderablePiece> _pieces = [];
  final Map<String, PieceTransform> _transforms = {};
  final Map<String, AnimationController> _animationControllers = {};

  DynamicLayerController({
    required this.coordinateSystem,
    required this.qualityManager,
  });

  List<RenderablePiece> get pieces => _pieces;

  void updatePieces(List<RenderablePiece> pieces) {
    _pieces = pieces;
    notifyListeners();
  }

  void updatePieceTransform(String pieceId, Matrix4 transform) {
    _transforms[pieceId] = PieceTransform(
      transform: transform,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  PieceTransform? getTransform(String pieceId) => _transforms[pieceId];

  AnimationController? getAnimationController(String pieceId) =>
      _animationControllers[pieceId];

  void registerAnimationController(
    String pieceId,
    AnimationController controller,
  ) {
    _animationControllers[pieceId] = controller;
  }

  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Transform data for a piece
class PieceTransform {
  final Matrix4 transform;
  final DateTime timestamp;

  const PieceTransform({
    required this.transform,
    required this.timestamp,
  });
}

/// Dynamic layer widget that renders individual pieces
class DynamicPieceLayer extends StatefulWidget {
  final DynamicLayerController controller;
  final List<RenderablePiece> pieces;
  final CoordinateSystem coordinateSystem;
  final QualityLevel quality;
  final Function(String, Matrix4) onPieceTransform;

  const DynamicPieceLayer({
    super.key,
    required this.controller,
    required this.pieces,
    required this.coordinateSystem,
    required this.quality,
    required this.onPieceTransform,
  });

  @override
  State<DynamicPieceLayer> createState() => _DynamicPieceLayerState();
}

class _DynamicPieceLayerState extends State<DynamicPieceLayer> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.pieces.map((piece) {
        return _buildPieceWidget(piece);
      }).toList(),
    );
  }

  Widget _buildPieceWidget(RenderablePiece piece) {
    // Each piece is wrapped in a RepaintBoundary for independent updates
    return RepaintBoundary(
      key: ValueKey('piece_${piece.id}'),
      child: OptimizedPieceWidget(
        piece: piece,
        controller: widget.controller,
        coordinateSystem: widget.coordinateSystem,
        quality: widget.quality,
        onTransformUpdate: (transform) {
          widget.onPieceTransform(piece.id, transform);
        },
      ),
    );
  }
}

/// Optimized widget for individual puzzle pieces
class OptimizedPieceWidget extends StatefulWidget {
  final RenderablePiece piece;
  final DynamicLayerController controller;
  final CoordinateSystem coordinateSystem;
  final QualityLevel quality;
  final ValueChanged<Matrix4> onTransformUpdate;

  const OptimizedPieceWidget({
    super.key,
    required this.piece,
    required this.controller,
    required this.coordinateSystem,
    required this.quality,
    required this.onTransformUpdate,
  });

  @override
  State<OptimizedPieceWidget> createState() => _OptimizedPieceWidgetState();
}

class _OptimizedPieceWidgetState extends State<OptimizedPieceWidget>
    with TickerProviderStateMixin {
  late AnimationController _pickupController;
  late AnimationController _snapController;
  late AnimationController _wobbleController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _wobbleAnimation;

  Matrix4 _currentTransform = Matrix4.identity();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _updateTransform();
  }

  void _initializeAnimations() {
    // Pickup animation
    _pickupController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pickupController,
      curve: Curves.easeOutBack,
    ));

    _elevationAnimation = Tween<double>(
      begin: 0,
      end: 8,
    ).animate(CurvedAnimation(
      parent: _pickupController,
      curve: Curves.easeOut,
    ));

    // Snap animation
    _snapController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Wobble animation for magnetic effect
    _wobbleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _wobbleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _wobbleController,
      curve: Curves.elasticIn,
    ));

    // Register controllers
    widget.controller.registerAnimationController(
      widget.piece.id,
      _pickupController,
    );
  }

  void _updateTransform() {
    _currentTransform = Matrix4.identity()
      ..translate(widget.piece.position.dx, widget.piece.position.dy)
      ..rotateZ(widget.piece.rotation);
  }

  @override
  void didUpdateWidget(OptimizedPieceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animations based on piece state changes
    if (widget.piece.isSelected && !oldWidget.piece.isSelected) {
      _pickupController.forward();
    } else if (!widget.piece.isSelected && oldWidget.piece.isSelected) {
      _pickupController.reverse();
    }

    // Update wobble animation when dragging state changes
    if (widget.piece.isDragging != oldWidget.piece.isDragging) {
      if (widget.piece.isDragging) {
        _wobbleController.repeat(reverse: true);
      } else {
        _wobbleController.stop();
        _wobbleController.reset();
      }
    }

    _updateTransform();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pickupController,
        _snapController,
        _wobbleController,
      ]),
      builder: (context, child) {
        return Transform(
          transform: _buildTransformMatrix(),
          child: _buildPieceContent(),
        );
      },
    );
  }

  Matrix4 _buildTransformMatrix() {
    final matrix = Matrix4.identity();
    
    // Apply base transform
    matrix.multiply(_currentTransform);
    
    // Apply scale animation
    final scale = _scaleAnimation.value;
    matrix.scale(scale, scale);
    
    // Apply wobble for magnetic effect
    if (_wobbleAnimation.value > 0) {
      final wobble = math.sin(_wobbleAnimation.value * math.pi * 2) * 0.05;
      matrix.rotateZ(wobble);
    }
    
    // Notify transform update
    widget.onTransformUpdate(matrix);
    
    return matrix;
  }

  Widget _buildPieceContent() {
    return Container(
      width: widget.piece.size.width,
      height: widget.piece.size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: widget.quality.enableShadows
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: _elevationAnimation.value,
                  offset: Offset(0, _elevationAnimation.value / 2),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: PiecePainter(
          piece: widget.piece,
          quality: widget.quality,
          isHighlighted: widget.piece.isSelected,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _snapController.dispose();
    _wobbleController.dispose();
    super.dispose();
  }
}

/// Custom painter for puzzle pieces
class PiecePainter extends CustomPainter {
  final RenderablePiece piece;
  final QualityLevel quality;
  final bool isHighlighted;

  const PiecePainter({
    required this.piece,
    required this.quality,
    this.isHighlighted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getPieceColor()
      ..style = PaintingStyle.fill;

    // Draw piece shape (simplified rectangle for now)
    final rect = Offset.zero & size;
    
    // Draw main piece
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );

    // Draw highlight if selected
    if (isHighlighted) {
      final highlightPaint = Paint()
        ..color = Colors.yellowAccent.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * quality.resolutionScale;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        highlightPaint,
      );
    }

    // Draw piece texture/pattern if high quality
    if (quality == QualityLevel.high || quality == QualityLevel.ultra) {
      _drawPieceTexture(canvas, size);
    }

    // Draw piece edges/connectors
    _drawPieceConnectors(canvas, size);
  }

  Color _getPieceColor() {
    // Generate color based on piece ID for consistency
    final hash = piece.id.hashCode;
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.7, 0.8).toColor();
  }

  void _drawPieceTexture(Canvas canvas, Size size) {
    // Add subtle texture to pieces
    final texturePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw diagonal lines for texture
    const lineSpacing = 5.0;
    final path = Path();
    
    for (double i = -size.height; i < size.width + size.height; i += lineSpacing) {
      path.moveTo(i, 0);
      path.lineTo(i + size.height, size.height);
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, texturePaint);
    canvas.restore();
  }

  void _drawPieceConnectors(Canvas canvas, Size size) {
    // Draw jigsaw-style connectors (simplified)
    final connectorPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Top connector
    final topPath = Path()
      ..moveTo(size.width * 0.4, 0)
      ..quadraticBezierTo(
        size.width * 0.5, -10,
        size.width * 0.6, 0,
      );
    canvas.drawPath(topPath, connectorPaint);

    // Right connector
    final rightPath = Path()
      ..moveTo(size.width, size.height * 0.4)
      ..quadraticBezierTo(
        size.width + 10, size.height * 0.5,
        size.width, size.height * 0.6,
      );
    canvas.drawPath(rightPath, connectorPaint);

    // Bottom connector (inset)
    final bottomPath = Path()
      ..moveTo(size.width * 0.4, size.height)
      ..quadraticBezierTo(
        size.width * 0.5, size.height + 10,
        size.width * 0.6, size.height,
      );
    canvas.drawPath(bottomPath, connectorPaint);

    // Left connector (inset)
    final leftPath = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        -10, size.height * 0.5,
        0, size.height * 0.6,
      );
    canvas.drawPath(leftPath, connectorPaint);
  }

  @override
  bool shouldRepaint(PiecePainter oldDelegate) {
    return oldDelegate.piece != piece ||
           oldDelegate.quality != quality ||
           oldDelegate.isHighlighted != isHighlighted;
  }
}
