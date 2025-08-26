import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/presentation/gestures/magnetic_gesture_recognizer.dart';

/// Integration helper for using MagneticGestureRecognizer in the game.
/// This mixin provides all the necessary setup and handlers for magnetic gestures.
mixin MagneticGestureHandler<T extends StatefulWidget> on State<T> {
  // Gesture recognizer configuration
  late MagneticFieldConfiguration _magneticConfig;
  
  // Snap points for the current puzzle
  final List<MagneticSnapPoint> _snapPoints = [];
  
  // Performance tracking
  PerformanceMetrics? _lastMetrics;
  
  // Debug mode flag
  bool _debugModeEnabled = false;
  
  /// Initialize the magnetic gesture system with puzzle-specific configuration.
  void initializeMagneticGestures({
    required List<Offset> snapPositions,
    double snapRadius = 50.0,
    double fieldStrength = 0.4,
    FieldFalloffType falloffType = FieldFalloffType.quadratic,
  }) {
    _snapPoints.clear();
    
    // Create snap points from positions
    for (final position in snapPositions) {
      _snapPoints.add(MagneticSnapPoint(
        position: position,
        radius: snapRadius,
        strength: 1.0,
      ));
    }
    
    // Create configuration
    _magneticConfig = MagneticFieldConfiguration(
      snapPoints: _snapPoints,
      strength: fieldStrength,
      minimumInfluence: 0.1,
      maxInfluence: 8.0,
      falloffType: falloffType,
    );
  }
  
  /// Create a magnetic gesture recognizer for a puzzle piece.
  MagneticGestureRecognizer createMagneticRecognizer({
    required void Function(DragStartDetails) onStart,
    required void Function(DragUpdateDetails) onUpdate,
    required void Function(DragEndDetails) onEnd,
    void Function()? onCancel,
    void Function(MagneticFieldInfluence)? onMagneticInfluence,
    void Function(MultiTouchEvent)? onMultiTouch,
  }) {
    return MagneticGestureRecognizer(
      fieldConfig: _magneticConfig,
      debugMode: _debugModeEnabled,
    )
      ..onStart = onStart
      ..onUpdate = onUpdate
      ..onEnd = onEnd
      ..onCancel = onCancel
      ..onMagneticInfluence = onMagneticInfluence
      ..onMultiTouch = onMultiTouch;
  }
  
  /// Wrap a widget with magnetic gesture detection.
  Widget wrapWithMagneticGesture({
    required Widget child,
    required void Function(DragStartDetails) onStart,
    required void Function(DragUpdateDetails) onUpdate,
    required void Function(DragEndDetails) onEnd,
    void Function()? onCancel,
    void Function(MagneticFieldInfluence)? onMagneticInfluence,
    void Function(MultiTouchEvent)? onMultiTouch,
  }) {
    return RawGestureDetector(
      gestures: {
        MagneticGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            MagneticGestureRecognizer>(
          () => createMagneticRecognizer(
            onStart: onStart,
            onUpdate: onUpdate,
            onEnd: onEnd,
            onCancel: onCancel,
            onMagneticInfluence: onMagneticInfluence,
            onMultiTouch: onMultiTouch,
          ),
          (MagneticGestureRecognizer instance) {
            // Configuration is already done in the factory
          },
        ),
      },
      child: child,
    );
  }
  
  /// Update snap points dynamically (e.g., when pieces are placed).
  void updateSnapPoints(List<Offset> newPositions) {
    setState(() {
      initializeMagneticGestures(snapPositions: newPositions);
    });
  }
  
  /// Toggle debug mode for development.
  void setDebugMode(bool enabled) {
    setState(() {
      _debugModeEnabled = enabled;
    });
  }
  
  /// Get the current performance metrics.
  PerformanceMetrics? getPerformanceMetrics() => _lastMetrics;
  
  /// Build a debug overlay widget.
  Widget buildDebugOverlay() {
    if (!_debugModeEnabled || _lastMetrics == null) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: 50,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gesture Performance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Avg: ${_lastMetrics!.averageProcessingTime.toStringAsFixed(1)}μs',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              'Max: ${_lastMetrics!.maxProcessingTime}μs',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              'Rate: ${_lastMetrics!.samplingRate.toStringAsFixed(1)}Hz',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            if (_lastMetrics!.droppedEvents > 0)
              Text(
                'Dropped: ${_lastMetrics!.droppedEvents}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}

/// Example game widget using the magnetic gesture system.
class MagneticPuzzleGame extends StatefulWidget {
  const MagneticPuzzleGame({super.key});

  @override
  State<MagneticPuzzleGame> createState() => _MagneticPuzzleGameState();
}

class _MagneticPuzzleGameState extends State<MagneticPuzzleGame>
    with TickerProviderStateMixin, MagneticGestureHandler {
  
  // Game state
  final Map<int, Offset> _piecePositions = {};
  final Map<int, bool> _pieceLocked = {};
  int? _draggingPiece;
  
  // Animation controllers for smooth movements
  final Map<int, AnimationController> _animationControllers = {};
  
  @override
  void initState() {
    super.initState();
    _initializeGame();
  }
  
  void _initializeGame() {
    // Create a 3x3 grid of pieces
    for (int i = 0; i < 9; i++) {
      _piecePositions[i] = Offset(
        50.0 + (i % 3) * 100,
        50.0 + (i ~/ 3) * 100,
      );
      _pieceLocked[i] = false;
    }
    
    // Initialize magnetic snap points (target positions)
    final snapPositions = <Offset>[];
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        snapPositions.add(Offset(
          100.0 + col * 120,
          200.0 + row * 120,
        ));
      }
    }
    
    initializeMagneticGestures(
      snapPositions: snapPositions,
      snapRadius: 40.0,
      fieldStrength: 0.35,
    );
  }
  
  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _handlePieceStart(int pieceId, DragStartDetails details) {
    if (_pieceLocked[pieceId] ?? false) return;
    
    setState(() {
      _draggingPiece = pieceId;
    });
    
    // Cancel any ongoing animation for this piece
    _animationControllers[pieceId]?.stop();
  }
  
  void _handlePieceUpdate(int pieceId, DragUpdateDetails details) {
    if (_pieceLocked[pieceId] ?? false) return;
    
    setState(() {
      _piecePositions[pieceId] = _piecePositions[pieceId]! + details.delta;
    });
  }
  
  void _handlePieceEnd(int pieceId, DragEndDetails details) {
    if (_pieceLocked[pieceId] ?? false) return;
    
    // Check if piece is close enough to snap point
    final currentPos = _piecePositions[pieceId]!;
    for (final snapPoint in _snapPoints) {
      if ((currentPos - snapPoint.position).distance < 30) {
        // Snap to position
        _animateToPosition(pieceId, snapPoint.position);
        setState(() {
          _pieceLocked[pieceId] = true;
        });
        break;
      }
    }
    
    // Apply momentum if velocity is significant
    if (details.velocity.pixelsPerSecond.distance > 50) {
      _applyMomentum(pieceId, details.velocity);
    }
    
    setState(() {
      _draggingPiece = null;
    });
  }
  
  void _animateToPosition(int pieceId, Offset target) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    final startPos = _piecePositions[pieceId]!;
    final animation = Tween<Offset>(
      begin: startPos,
      end: target,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
    
    animation.addListener(() {
      setState(() {
        _piecePositions[pieceId] = animation.value;
      });
    });
    
    _animationControllers[pieceId]?.dispose();
    _animationControllers[pieceId] = controller;
    
    controller.forward();
  }
  
  void _applyMomentum(int pieceId, Velocity velocity) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    final startPos = _piecePositions[pieceId]!;
    final momentum = velocity.pixelsPerSecond * 0.3;
    final endPos = startPos + momentum;
    
    final animation = Tween<Offset>(
      begin: startPos,
      end: endPos,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.decelerate,
    ));
    
    animation.addListener(() {
      setState(() {
        _piecePositions[pieceId] = animation.value;
      });
    });
    
    _animationControllers[pieceId]?.dispose();
    _animationControllers[pieceId] = controller;
    
    controller.forward();
  }
  
  void _handleMagneticInfluence(MagneticFieldInfluence influence) {
    // Could show visual feedback here
    debugPrint('Magnetic influence: ${influence.strength}');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Magnetic Puzzle Game'),
        actions: [
          IconButton(
            icon: Icon(_debugModeEnabled ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () => setDebugMode(!_debugModeEnabled),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeGame,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.purple.shade50,
                ],
              ),
            ),
          ),
          
          // Snap point indicators
          ..._snapPoints.map((snapPoint) => Positioned(
            left: snapPoint.position.dx - 25,
            top: snapPoint.position.dy - 25,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )),
          
          // Puzzle pieces
          ..._piecePositions.entries.map((entry) {
            final pieceId = entry.key;
            final position = entry.value;
            final isLocked = _pieceLocked[pieceId] ?? false;
            final isDragging = _draggingPiece == pieceId;
            
            return Positioned(
              left: position.dx - 30,
              top: position.dy - 30,
              child: wrapWithMagneticGesture(
                onStart: (details) => _handlePieceStart(pieceId, details),
                onUpdate: (details) => _handlePieceUpdate(pieceId, details),
                onEnd: (details) => _handlePieceEnd(pieceId, details),
                onMagneticInfluence: _handleMagneticInfluence,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isLocked 
                        ? Colors.green 
                        : Colors.primaries[pieceId % Colors.primaries.length],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDragging ? 0.4 : 0.2),
                        blurRadius: isDragging ? 12 : 6,
                        offset: Offset(0, isDragging ? 6 : 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${pieceId + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          
          // Debug overlay
          buildDebugOverlay(),
        ],
      ),
    );
  }
}
