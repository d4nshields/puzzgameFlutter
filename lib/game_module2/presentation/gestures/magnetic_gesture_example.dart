import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/presentation/gestures/magnetic_gesture_recognizer.dart';

/// Example widget demonstrating the use of MagneticGestureRecognizer
/// for puzzle piece manipulation with magnetic snap points.
class MagneticGestureExample extends StatefulWidget {
  const MagneticGestureExample({super.key});

  @override
  State<MagneticGestureExample> createState() => _MagneticGestureExampleState();
}

class _MagneticGestureExampleState extends State<MagneticGestureExample>
    with TickerProviderStateMixin {
  // Piece positions
  final List<PieceData> _pieces = [];
  
  // Snap points for magnetic field
  final List<MagneticSnapPoint> _snapPoints = [];
  
  // Currently dragging piece
  PieceData? _draggingPiece;
  
  // Animation controllers for momentum
  final Map<int, AnimationController> _momentumControllers = {};
  final Map<int, Animation<Offset>> _momentumAnimations = {};
  
  // Performance metrics
  PerformanceMetrics? _performanceMetrics;
  
  // Debug mode
  bool _debugMode = false;
  
  // Visual feedback
  MagneticFieldInfluence? _lastMagneticInfluence;
  MultiTouchEvent? _lastMultiTouchEvent;

  @override
  void initState() {
    super.initState();
    _initializePieces();
    _initializeSnapPoints();
  }

  void _initializePieces() {
    // Create sample puzzle pieces
    for (int i = 0; i < 9; i++) {
      _pieces.add(PieceData(
        id: i,
        position: Offset(
          50.0 + (i % 3) * 120,
          50.0 + (i ~/ 3) * 120,
        ),
        size: const Size(80, 80),
        color: HSLColor.fromAHSL(1.0, i * 40.0, 0.7, 0.5).toColor(),
      ));
    }
  }

  void _initializeSnapPoints() {
    // Create grid of snap points
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        _snapPoints.add(MagneticSnapPoint(
          position: Offset(
            100.0 + col * 150,
            200.0 + row * 150,
          ),
          radius: 60.0,
          strength: 0.8,
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _momentumControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handlePieceDragStart(int pieceId, DragStartDetails details) {
    setState(() {
      _draggingPiece = _pieces.firstWhere((p) => p.id == pieceId);
    });
  }

  void _handlePieceDragUpdate(int pieceId, DragUpdateDetails details) {
    setState(() {
      final piece = _pieces.firstWhere((p) => p.id == pieceId);
      piece.position += details.delta;
    });
  }

  void _handlePieceDragEnd(int pieceId, DragEndDetails details) {
    // Apply momentum animation
    if (details.velocity.pixelsPerSecond.distance > 10) {
      _startMomentumAnimation(pieceId, details.velocity);
    }
    
    setState(() {
      _draggingPiece = null;
    });
  }

  void _handleMagneticInfluence(MagneticFieldInfluence influence) {
    setState(() {
      _lastMagneticInfluence = influence;
    });
    
    // Clear after a short duration
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _lastMagneticInfluence = null;
        });
      }
    });
  }

  void _handleMultiTouch(MultiTouchEvent event) {
    setState(() {
      _lastMultiTouchEvent = event;
    });
    
    // Handle pinch to zoom
    if (event.type == MultiTouchType.pinch) {
      // Could implement zoom here
    }
  }

  void _startMomentumAnimation(int pieceId, Velocity velocity) {
    // Clean up existing animation
    _momentumControllers[pieceId]?.dispose();
    
    final controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    final piece = _pieces.firstWhere((p) => p.id == pieceId);
    final startPosition = piece.position;
    final endPosition = startPosition + 
        (velocity.pixelsPerSecond * 0.5); // Simplified momentum
    
    final animation = Tween<Offset>(
      begin: startPosition,
      end: endPosition,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.decelerate,
    ));
    
    animation.addListener(() {
      setState(() {
        piece.position = animation.value;
      });
    });
    
    _momentumControllers[pieceId] = controller;
    _momentumAnimations[pieceId] = animation;
    
    controller.forward();
  }

  void _toggleDebugMode() {
    setState(() {
      _debugMode = !_debugMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Magnetic Gesture Example'),
        actions: [
          IconButton(
            icon: Icon(_debugMode ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: _toggleDebugMode,
            tooltip: 'Toggle Debug Mode',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background with snap points
          CustomPaint(
            painter: SnapPointPainter(
              snapPoints: _snapPoints,
              showMagneticField: _debugMode,
              magneticInfluence: _lastMagneticInfluence,
            ),
            size: Size.infinite,
          ),
          
          // Puzzle pieces
          ..._pieces.map((piece) => _buildPiece(piece)),
          
          // Debug overlay
          if (_debugMode) _buildDebugOverlay(),
          
          // Performance metrics
          if (_performanceMetrics != null) _buildPerformanceOverlay(),
        ],
      ),
    );
  }

  Widget _buildPiece(PieceData piece) {
    final isDragging = _draggingPiece?.id == piece.id;
    
    return Positioned(
      left: piece.position.dx,
      top: piece.position.dy,
      child: RawGestureDetector(
        gestures: {
          MagneticGestureRecognizer: GestureRecognizerFactoryWithHandlers<
              MagneticGestureRecognizer>(
            () => MagneticGestureRecognizer(
              fieldConfig: MagneticFieldConfiguration(
                snapPoints: _snapPoints,
                strength: 0.4,
                minimumInfluence: 0.1,
                maxInfluence: 8.0,
                falloffType: FieldFalloffType.quadratic,
              ),
              debugMode: _debugMode,
            ),
            (MagneticGestureRecognizer instance) {
              instance.onStart = (details) => _handlePieceDragStart(piece.id, details);
              instance.onUpdate = (details) => _handlePieceDragUpdate(piece.id, details);
              instance.onEnd = (details) => _handlePieceDragEnd(piece.id, details);
              instance.onMagneticInfluence = _handleMagneticInfluence;
              instance.onMultiTouch = _handleMultiTouch;
            },
          ),
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: piece.size.width,
          height: piece.size.height,
          decoration: BoxDecoration(
            color: piece.color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDragging ? 0.3 : 0.2),
                blurRadius: isDragging ? 12 : 6,
                offset: Offset(0, isDragging ? 6 : 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${piece.id + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return Positioned(
      right: 16,
      top: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug Info',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dragging: ${_draggingPiece?.id ?? "none"}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (_lastMagneticInfluence != null) ...[
              Text(
                'Magnetic: ${_lastMagneticInfluence!.strength.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
            ],
            if (_lastMultiTouchEvent != null) ...[
              Text(
                'Multi-touch: ${_lastMultiTouchEvent!.touches.length} points',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceOverlay() {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Avg: ${_performanceMetrics!.averageProcessingTime.toStringAsFixed(1)}μs',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Max: ${_performanceMetrics!.maxProcessingTime}μs',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Rate: ${_performanceMetrics!.samplingRate.toStringAsFixed(1)}Hz',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data model for a puzzle piece.
class PieceData {
  final int id;
  Offset position;
  final Size size;
  final Color color;

  PieceData({
    required this.id,
    required this.position,
    required this.size,
    required this.color,
  });
}

/// Custom painter for visualizing snap points and magnetic fields.
class SnapPointPainter extends CustomPainter {
  final List<MagneticSnapPoint> snapPoints;
  final bool showMagneticField;
  final MagneticFieldInfluence? magneticInfluence;

  SnapPointPainter({
    required this.snapPoints,
    this.showMagneticField = false,
    this.magneticInfluence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw magnetic field visualization
    if (showMagneticField) {
      _drawMagneticField(canvas, size);
    }
    
    // Draw snap points
    _drawSnapPoints(canvas);
    
    // Draw magnetic influence indicator
    if (magneticInfluence != null) {
      _drawMagneticInfluence(canvas);
    }
  }

  void _drawMagneticField(Canvas canvas, Size size) {
    // Create a gradient for each snap point to visualize field strength
    for (final snapPoint in snapPoints) {
      final gradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Colors.blue.withOpacity(0.3),
          Colors.blue.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      );
      
      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: snapPoint.position,
            radius: snapPoint.radius,
          ),
        );
      
      canvas.drawCircle(
        snapPoint.position,
        snapPoint.radius,
        paint,
      );
    }
  }

  void _drawSnapPoints(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    for (final snapPoint in snapPoints) {
      // Draw outer ring
      paint.color = Colors.blue.withOpacity(0.5);
      canvas.drawCircle(
        snapPoint.position,
        20,
        paint,
      );
      
      // Draw inner dot
      paint.style = PaintingStyle.fill;
      paint.color = Colors.blue;
      canvas.drawCircle(
        snapPoint.position,
        4,
        paint,
      );
      
      // Draw crosshair
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      paint.color = Colors.blue.withOpacity(0.3);
      
      canvas.drawLine(
        snapPoint.position - const Offset(15, 0),
        snapPoint.position + const Offset(15, 0),
        paint,
      );
      
      canvas.drawLine(
        snapPoint.position - const Offset(0, 15),
        snapPoint.position + const Offset(0, 15),
        paint,
      );
    }
  }

  void _drawMagneticInfluence(Canvas canvas) {
    if (magneticInfluence == null) return;
    
    // Draw influence vector
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    path.moveTo(magneticInfluence!.source.dx, magneticInfluence!.source.dy);
    
    final endPoint = magneticInfluence!.source + 
        (magneticInfluence!.direction * 30);
    path.lineTo(endPoint.dx, endPoint.dy);
    
    // Draw arrowhead
    final arrowSize = 8.0;
    
    path.moveTo(endPoint.dx, endPoint.dy);
    path.lineTo(
      endPoint.dx - arrowSize * (0.866 * magneticInfluence!.direction.dx - 0.5 * magneticInfluence!.direction.dy),
      endPoint.dy - arrowSize * (0.5 * magneticInfluence!.direction.dx + 0.866 * magneticInfluence!.direction.dy),
    );
    
    path.moveTo(endPoint.dx, endPoint.dy);
    path.lineTo(
      endPoint.dx - arrowSize * (0.866 * magneticInfluence!.direction.dx + 0.5 * magneticInfluence!.direction.dy),
      endPoint.dy - arrowSize * (-0.5 * magneticInfluence!.direction.dx + 0.866 * magneticInfluence!.direction.dy),
    );
    
    canvas.drawPath(path, paint);
    
    // Draw influence strength text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(magneticInfluence!.strength * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      magneticInfluence!.source + const Offset(20, -20),
    );
  }

  @override
  bool shouldRepaint(SnapPointPainter oldDelegate) {
    return oldDelegate.showMagneticField != showMagneticField ||
           oldDelegate.magneticInfluence != magneticInfluence ||
           oldDelegate.snapPoints != snapPoints;
  }
}
