import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../puzzle_game_module2.dart';
import '../../debug_tracer.dart';
import '../../../game_module/puzzle_game_module.dart' show PuzzlePiece;
import '../gestures/magnetic_gesture_recognizer.dart';
import '../../infrastructure/feature_flags.dart';

/// Extended magnetic snap point with grid metadata
class ExtendedMagneticSnapPoint extends MagneticSnapPoint {
  final int row;
  final int col;
  
  ExtendedMagneticSnapPoint({
    required super.position,
    super.radius = 50.0,
    super.strength = 1.0,
    required this.row,
    required this.col,
  });
}

/// Widget that implements the workspace-based interaction model with MAGNETIC GESTURES.
/// 
/// Version 8: ACTUALLY uses the magnetic gesture system
class PuzzleWorkspaceWidgetMagnetic extends StatefulWidget {
  final PuzzleGameSession2 gameSession;
  final VoidCallback? onGameCompleted;

  const PuzzleWorkspaceWidgetMagnetic({
    super.key,
    required this.gameSession,
    this.onGameCompleted,
  });

  @override
  State<PuzzleWorkspaceWidgetMagnetic> createState() => _PuzzleWorkspaceWidgetMagneticState();
}

class _PuzzleWorkspaceWidgetMagneticState extends State<PuzzleWorkspaceWidgetMagnetic> {
  // Track pieces on workspace
  final Map<String, Offset> _workspacePiecePositions = {};
  
  // Magnetic gesture configuration
  late MagneticFieldConfiguration _magneticConfig;
  final List<ExtendedMagneticSnapPoint> _snapPoints = [];
  
  // Track dragging state
  String? _draggingPieceId;
  Offset? _dragOffset;
  
  // Store canvas scale for calculations
  double _currentScale = 1.0;
  
  // GlobalKey for overlay Stack to convert coordinates
  final GlobalKey _overlayKey = GlobalKey();
  
  // Feature flags
  bool _magneticEnabled = false;
  bool _enhancedFeedback = false;
  bool _smoothAnimations = false;
  
  // Debug mode flag
  bool get _showDebugInfo => kDebugMode || const String.fromEnvironment('DEBUG_TOOLS') == 'true';
  
  @override
  void initState() {
    super.initState();
    DebugTracer.log('INIT', '🚀 PuzzleWorkspaceWidgetMagnetic.initState()');
    _initializeFeatureFlags();
    _initializeMagneticSystem();
    _initializeWorkspacePieces();
  }
  
  Future<void> _initializeFeatureFlags() async {
    DebugTracer.log('FLAGS', 'Checking feature flags...');
    
    final flags = FeatureFlagService.instance;
    _magneticEnabled = await flags.isEnabled('magnetic_gestures');
    _enhancedFeedback = await flags.isEnabled('enhanced_feedback');
    _smoothAnimations = await flags.isEnabled('smooth_animations');
    
    DebugTracer.logFeatureFlag('Feature flags loaded', data: {
      'magnetic_gestures': _magneticEnabled,
      'enhanced_feedback': _enhancedFeedback,
      'smooth_animations': _smoothAnimations,
    });
    
    if (mounted) setState(() {});
  }
  
  void _initializeMagneticSystem() {
    DebugTracer.logMagnetic('Initializing magnetic system');
    
    // Clear existing snap points
    _snapPoints.clear();
    
    // Create snap points for each grid position
    final gridSize = widget.gameSession.gridSize;
    final canvasSize = widget.gameSession.canvasInfo.canvasSize;
    final cellWidth = canvasSize.width / gridSize;
    final cellHeight = canvasSize.height / gridSize;
    
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final snapPoint = ExtendedMagneticSnapPoint(
          position: Offset(
            col * cellWidth + cellWidth / 2,
            row * cellHeight + cellHeight / 2,
          ),
          radius: math.min(cellWidth, cellHeight) * 0.4, // 40% of cell size
          strength: 1.0,
          row: row,
          col: col,
        );
        _snapPoints.add(snapPoint);
      }
    }
    
    // Configure magnetic field
    _magneticConfig = MagneticFieldConfiguration(
      snapPoints: _snapPoints,
      strength: 0.5, // Medium strength
      minimumInfluence: 0.1,
      maxInfluence: 5.0,
      falloffType: FieldFalloffType.quadratic,
    );
    
    DebugTracer.logMagnetic('Magnetic system initialized', data: {
      'snap_points': _snapPoints.length,
      'field_strength': 0.5,
      'falloff': 'quadratic',
    });
  }
  
  void _initializeWorkspacePieces() {
    DebugTracer.logWorkspace('Initializing workspace pieces');
    
    print('=== INITIALIZING MAGNETIC WORKSPACE WIDGET ===');
    print('🧲 MAGNETIC GESTURES ENABLED: $_magneticEnabled');
    print('Total pieces: ${widget.gameSession.totalPieces}');
    print('Tray pieces: ${widget.gameSession.trayPieces.length}');
    print('Placed pieces: ${widget.gameSession.placedPieces.length}');
    print('Grid size: ${widget.gameSession.gridSize}x${widget.gameSession.gridSize}');
    
    for (final piece in widget.gameSession.workspacePieces) {
      _workspacePiecePositions[piece.id] = Offset(
        100.0 + (_workspacePiecePositions.length * 50),
        100.0,
      );
    }
  }
  
  /// Create a magnetic gesture recognizer for a piece
  MagneticGestureRecognizer _createMagneticRecognizer(PuzzlePiece piece) {
    DebugTracer.logMagnetic('Creating magnetic recognizer for piece ${piece.id}');
    
    return MagneticGestureRecognizer(
      fieldConfig: _magneticConfig,
      debugMode: _showDebugInfo,
    )
      ..onStart = (details) {
        DebugTracer.logInteraction('Drag START: piece ${piece.id}', data: details.globalPosition);
        setState(() {
          _draggingPieceId = piece.id;
          _dragOffset = details.localPosition;
        });
        if (_enhancedFeedback) {
          HapticFeedback.selectionClick();
        }
      }
      ..onUpdate = (details) {
        if (_draggingPieceId == piece.id) {
          setState(() {
            _workspacePiecePositions[piece.id] = details.localPosition - (_dragOffset ?? Offset.zero);
          });
        }
      }
      ..onEnd = (details) {
        DebugTracer.logInteraction('Drag END: piece ${piece.id}', data: {
          'velocity': details.velocity,
          'position': _workspacePiecePositions[piece.id],
        });
        _handleMagneticDrop(piece, details);
      }
      ..onMagneticInfluence = (influence) {
        DebugTracer.logMagnetic('Magnetic influence on ${piece.id}', data: {
          'strength': influence.strength,
          'direction': influence.direction,
        });
        
        if (_enhancedFeedback && influence.strength > 0.3) {
          HapticFeedback.lightImpact();
        }
      };
  }
  
  void _handleMagneticDrop(PuzzlePiece piece, DragEndDetails details) {
    DebugTracer.logMagnetic('Processing magnetic drop for ${piece.id}');
    
    // Find nearest snap point
    final currentPos = _workspacePiecePositions[piece.id] ?? Offset.zero;
    ExtendedMagneticSnapPoint? nearestSnap;
    double minDistance = double.infinity;
    
    for (final snap in _snapPoints) {
      final distance = (snap.position - currentPos).distance;
      if (distance < minDistance && distance < snap.radius) {
        minDistance = distance;
        nearestSnap = snap;
      }
    }
    
    if (nearestSnap != null) {
      final row = nearestSnap.row;
      final col = nearestSnap.col;
      
      DebugTracer.logMagnetic('SNAPPING to ($row, $col)', data: {
        'piece': piece.id,
        'correct_position': '(${piece.correctRow}, ${piece.correctCol})',
        'distance': minDistance,
      });
      
      if (piece.correctRow == row && piece.correctCol == col) {
        // Correct placement!
        _placePieceWithMagneticSnap(piece, row, col, nearestSnap.position);
      } else {
        // Wrong position but still snap for visual feedback
        if (_smoothAnimations) {
          _animateToPosition(piece.id, nearestSnap.position);
        } else {
          setState(() {
            _workspacePiecePositions[piece.id] = nearestSnap!.position;
          });
        }
        
        if (_enhancedFeedback) {
          HapticFeedback.mediumImpact();
        }
      }
    }
    
    setState(() {
      _draggingPieceId = null;
      _dragOffset = null;
    });
  }
  
  void _placePieceWithMagneticSnap(PuzzlePiece piece, int row, int col, Offset snapPosition) {
    DebugTracer.logMagnetic('✅ MAGNETIC SNAP SUCCESS!', data: {
      'piece': piece.id,
      'position': '($row, $col)',
    });
    
    setState(() {
      // Calculate pixel coordinates from grid position
      // tryPlacePieceAt expects pixel coordinates, not grid indices!
      // Grid (row=0, col=0) → Pixel (x=0, y=0)
      // Grid (row=1, col=2) → Pixel (x=2*cellWidth, y=1*cellHeight)
      final canvasSize = widget.gameSession.canvasInfo.canvasSize;
      final gridSize = widget.gameSession.gridSize;
      final x = col * (canvasSize.width / gridSize);
      final y = row * (canvasSize.height / gridSize);
      
      // Place the piece at the calculated pixel coordinates
      widget.gameSession.tryPlacePieceAt(piece, x, y);
      _workspacePiecePositions.remove(piece.id);
      
      if (_enhancedFeedback) {
        HapticFeedback.heavyImpact();
      }
      
      // Check for completion
      if (widget.gameSession.isCompleted) {
        DebugTracer.log('COMPLETE', '🎉 Puzzle completed!');
        widget.onGameCompleted?.call();
      }
    });
  }
  
  void _animateToPosition(String pieceId, Offset targetPosition) {
    // TODO: Implement smooth animation
    setState(() {
      _workspacePiecePositions[pieceId] = targetPosition;
    });
  }
  
  double _calculateCanvasScale(Size canvasSize, Size availableSize) {
    final scaleX = availableSize.width / canvasSize.width;
    final scaleY = (availableSize.height - 150) / canvasSize.height; // Account for tray
    return math.min(scaleX, scaleY.toDouble()) * 0.9; // 90% to leave some margin
  }

  @override
  Widget build(BuildContext context) {
    DebugTracer.logWidget('Building PuzzleWorkspaceWidgetMagnetic');
    
    return Column(
      children: [
        // Debug info banner
        if (_showDebugInfo)
          Container(
            color: _magneticEnabled ? Colors.green : Colors.orange,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(_magneticEnabled ? Icons.check_circle : Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _magneticEnabled 
                    ? '🧲 MAGNETIC GESTURES ACTIVE' 
                    : '⚠️ MAGNETIC GESTURES DISABLED (using basic drag)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => DebugTracer.dumpLogs(),
                  child: const Text('DUMP LOGS', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        
        // Main game area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = widget.gameSession.canvasInfo.canvasSize;
              _currentScale = _calculateCanvasScale(
                Size(canvasSize.width, canvasSize.height),
                constraints.biggest,
              );
              
              return Stack(
                key: _overlayKey,
                children: [
                  // Canvas with grid
                  _buildCanvas(constraints),
                  
                  // Workspace pieces with magnetic gestures
                  if (_magneticEnabled)
                    ..._buildMagneticWorkspacePieces()
                  else
                    ..._buildBasicWorkspacePieces(),
                  
                  // Piece tray at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 120,
                    child: _buildPieceTray(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildCanvas(BoxConstraints constraints) {
    // Implementation similar to original but with magnetic snap indicators
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey),
          ),
          child: CustomPaint(
            size: Size(
              widget.gameSession.canvasInfo.canvasSize.width * _currentScale,
              widget.gameSession.canvasInfo.canvasSize.height * _currentScale,
            ),
            painter: _magneticEnabled 
              ? MagneticGridPainter(
                  gridSize: widget.gameSession.gridSize,
                  snapPoints: _snapPoints,
                  scale: _currentScale,
                  showMagneticField: _showDebugInfo,
                )
              : GridPainter(gridSize: widget.gameSession.gridSize),
          ),
        ),
      ),
    );
  }
  
  List<Widget> _buildMagneticWorkspacePieces() {
    DebugTracer.logWidget('Building MAGNETIC workspace pieces');
    
    return _workspacePiecePositions.entries.map((entry) {
      final pieceId = entry.key;
      final position = entry.value;
      final piece = widget.gameSession.pieces.firstWhere((p) => p.id == pieceId);
      
      return Positioned(
        left: position.dx,
        top: position.dy,
        child: GestureDetector(
          onPanStart: _createMagneticRecognizer(piece).onStart != null 
            ? (details) => _createMagneticRecognizer(piece).onStart!(
                DragStartDetails(
                  globalPosition: details.globalPosition,
                  localPosition: details.localPosition,
                )
              )
            : null,
          onPanUpdate: _createMagneticRecognizer(piece).onUpdate != null
            ? (details) => _createMagneticRecognizer(piece).onUpdate!(
                DragUpdateDetails(
                  globalPosition: details.globalPosition,
                  localPosition: details.localPosition,
                  delta: details.delta,
                )
              )
            : null,
          onPanEnd: _createMagneticRecognizer(piece).onEnd != null
            ? (details) => _createMagneticRecognizer(piece).onEnd!(
                DragEndDetails(
                  velocity: details.velocity,
                )
              )
            : null,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              border: Border.all(
                color: _draggingPieceId == pieceId ? Colors.blue : Colors.grey,
                width: _draggingPieceId == pieceId ? 3 : 1,
              ),
            ),
            child: Center(
              child: Text(
                piece.id,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
  
  List<Widget> _buildBasicWorkspacePieces() {
    DebugTracer.logWidget('Building BASIC workspace pieces (no magnetic)');
    
    // Fallback to basic draggable (existing implementation)
    return _workspacePiecePositions.entries.map((entry) {
      final pieceId = entry.key;
      final position = entry.value;
      final piece = widget.gameSession.pieces.firstWhere((p) => p.id == pieceId);
      
      return Positioned(
        left: position.dx,
        top: position.dy,
        child: Draggable<PuzzlePiece>(
          data: piece,
          feedback: Container(
            width: 80,
            height: 80,
            color: Colors.blue.withOpacity(0.5),
            child: Center(child: Text(piece.id)),
          ),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              border: Border.all(color: Colors.grey),
            ),
            child: Center(child: Text(piece.id, style: const TextStyle(fontSize: 10))),
          ),
        ),
      );
    }).toList();
  }
  
  Widget _buildPieceTray() {
    return Container(
      color: Colors.grey[300],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.gameSession.trayPieces.length,
        itemBuilder: (context, index) {
          final piece = widget.gameSession.trayPieces[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.3),
                border: Border.all(color: Colors.amber),
              ),
              child: Center(
                child: Text(
                  piece.id,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for grid with magnetic field visualization
class MagneticGridPainter extends CustomPainter {
  final int gridSize;
  final List<ExtendedMagneticSnapPoint> snapPoints;
  final double scale;
  final bool showMagneticField;
  
  MagneticGridPainter({
    required this.gridSize,
    required this.snapPoints,
    required this.scale,
    this.showMagneticField = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;
    
    // Draw grid
    for (int i = 0; i <= gridSize; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        paint,
      );
    }
    
    // Draw magnetic field visualization
    if (showMagneticField) {
      final magneticPaint = Paint()
        ..color = Colors.purple.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      for (final snap in snapPoints) {
        final scaledPos = snap.position * scale;
        final scaledRadius = snap.radius * scale;
        
        // Draw magnetic field circle
        canvas.drawCircle(
          scaledPos,
          scaledRadius,
          magneticPaint,
        );
        
        // Draw snap point
        canvas.drawCircle(
          scaledPos,
          5,
          Paint()..color = Colors.purple,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Basic grid painter for non-magnetic mode
class GridPainter extends CustomPainter {
  final int gridSize;
  
  GridPainter({required this.gridSize});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;
    
    for (int i = 0; i <= gridSize; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
