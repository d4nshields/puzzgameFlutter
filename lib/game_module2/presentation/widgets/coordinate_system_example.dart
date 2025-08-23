import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/domain/services/coordinate_system.dart';

/// Example widget demonstrating the coordinate system in action.
/// This widget shows a grid with draggable pieces that snap to grid cells.
class CoordinateSystemExample extends StatefulWidget {
  const CoordinateSystemExample({super.key});

  @override
  State<CoordinateSystemExample> createState() => _CoordinateSystemExampleState();
}

class _CoordinateSystemExampleState extends State<CoordinateSystemExample> {
  late CoordinateSystem _coordSystem;
  final Map<String, GridPoint> _pieces = {
    'red': const GridPoint(2, 2),
    'blue': const GridPoint(5, 3),
    'green': const GridPoint(7, 5),
  };
  String? _draggingPiece;
  WorkspacePoint? _dragPosition;
  GridPoint? _highlightedCell;

  @override
  void initState() {
    super.initState();
    _initializeCoordinateSystem();
  }

  void _initializeCoordinateSystem() {
    const config = CoordinateSystemConfig(
      devicePixelRatio: 1.0, // Will be updated in build
      canvasSize: Size(800, 600),
      gridCellSize: 60.0,
      gridWidth: 10,
      gridHeight: 8,
      workspaceBounds: Rect.fromLTWH(0, 0, 800, 600),
      zoomLevel: 1.0,
      panOffset: Offset.zero,
    );
    _coordSystem = CoordinateSystem(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordinate System Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _zoom(1.2),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _zoom(0.8),
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _fitToView,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _updateCoordinateSystem(constraints.biggest);
          return GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              size: constraints.biggest,
              painter: _GridPainter(
                coordSystem: _coordSystem,
                pieces: _pieces,
                draggingPiece: _draggingPiece,
                dragPosition: _dragPosition,
                highlightedCell: _highlightedCell,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildInfoBar(),
    );
  }

  void _updateCoordinateSystem(Size canvasSize) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final currentConfig = _coordSystem.config;
    
    if (currentConfig.canvasSize != canvasSize ||
        currentConfig.devicePixelRatio != devicePixelRatio) {
      _coordSystem.updateConfig(CoordinateSystemConfig(
        devicePixelRatio: devicePixelRatio,
        canvasSize: canvasSize,
        gridCellSize: 60.0,
        gridWidth: 10,
        gridHeight: 8,
        workspaceBounds: Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        zoomLevel: currentConfig.zoomLevel,
        panOffset: currentConfig.panOffset,
      ));
    }
  }

  void _onPanStart(DragStartDetails details) {
    final screenPoint = ScreenPoint(
      details.globalPosition.dx,
      details.globalPosition.dy,
    );
    final gridPoint = _coordSystem.screenToGrid(screenPoint);
    
    if (gridPoint != null) {
      // Check if we're starting a drag on a piece
      for (final entry in _pieces.entries) {
        if (entry.value == gridPoint) {
          setState(() {
            _draggingPiece = entry.key;
            _dragPosition = _coordSystem.screenToWorkspace(screenPoint);
          });
          break;
        }
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggingPiece != null) {
      final screenPoint = ScreenPoint(
        details.globalPosition.dx,
        details.globalPosition.dy,
      );
      
      setState(() {
        _dragPosition = _coordSystem.screenToWorkspace(screenPoint);
        _highlightedCell = _coordSystem.screenToGrid(screenPoint);
      });
    } else {
      // Pan the view
      setState(() {
        _coordSystem.applyPan(details.delta);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_draggingPiece != null && _highlightedCell != null) {
      // Snap piece to highlighted cell
      setState(() {
        _pieces[_draggingPiece!] = _highlightedCell!;
        _draggingPiece = null;
        _dragPosition = null;
        _highlightedCell = null;
      });
    } else {
      setState(() {
        _draggingPiece = null;
        _dragPosition = null;
        _highlightedCell = null;
      });
    }
  }

  void _zoom(double factor) {
    setState(() {
      final center = CanvasPoint(
        _coordSystem.config.canvasSize.width / 2,
        _coordSystem.config.canvasSize.height / 2,
      );
      _coordSystem.applyZoom(factor, center);
    });
  }

  void _fitToView() {
    setState(() {
      _coordSystem.fitGridToView();
    });
  }

  Widget _buildInfoBar() {
    final stats = _coordSystem.getPerformanceStats();
    return Container(
      height: 60,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Zoom: ${_coordSystem.config.zoomLevel.toStringAsFixed(2)}x'),
          Text('Pan: (${_coordSystem.config.panOffset.dx.toStringAsFixed(0)}, '
              '${_coordSystem.config.panOffset.dy.toStringAsFixed(0)})'),
          Text('Avg Transform: ${stats['averageTransformationTimeUs'].toStringAsFixed(1)}μs'),
          Icon(
            stats['meetsTargetPerformance'] == true
                ? Icons.check_circle
                : Icons.warning,
            color: stats['meetsTargetPerformance'] == true
                ? Colors.green
                : Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final CoordinateSystem coordSystem;
  final Map<String, GridPoint> pieces;
  final String? draggingPiece;
  final WorkspacePoint? dragPosition;
  final GridPoint? highlightedCell;

  _GridPainter({
    required this.coordSystem,
    required this.pieces,
    this.draggingPiece,
    this.dragPosition,
    this.highlightedCell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    _drawGrid(canvas);
    
    // Draw highlighted cell
    if (highlightedCell != null) {
      _drawHighlightedCell(canvas, highlightedCell!);
    }
    
    // Draw pieces
    _drawPieces(canvas);
    
    // Draw dragging piece
    if (draggingPiece != null && dragPosition != null) {
      _drawDraggingPiece(canvas);
    }
    
    // Draw performance overlay
    _drawPerformanceOverlay(canvas, size);
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int x = 0; x <= coordSystem.config.gridWidth; x++) {
      for (int y = 0; y <= coordSystem.config.gridHeight; y++) {
        final gridPoint = GridPoint(x, y);
        final bounds = coordSystem.gridCellToCanvasBounds(gridPoint);
        
        // Only draw cells that are visible
        if (bounds.overlaps(Rect.fromLTWH(0, 0, 
            coordSystem.config.canvasSize.width, 
            coordSystem.config.canvasSize.height))) {
          canvas.drawRect(bounds, paint);
        }
      }
    }
  }

  void _drawHighlightedCell(Canvas canvas, GridPoint cell) {
    final bounds = coordSystem.gridCellToCanvasBounds(cell);
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(bounds, paint);
  }

  void _drawPieces(Canvas canvas) {
    final pieceColors = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
    };

    for (final entry in pieces.entries) {
      if (entry.key == draggingPiece) continue; // Skip the piece being dragged
      
      final bounds = coordSystem.gridCellToCanvasBounds(entry.value);
      final paint = Paint()
        ..color = pieceColors[entry.key] ?? Colors.grey
        ..style = PaintingStyle.fill;
      
      // Draw piece
      final pieceRect = Rect.fromLTWH(
        bounds.left + 5,
        bounds.top + 5,
        bounds.width - 10,
        bounds.height - 10,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pieceRect, const Radius.circular(8)),
        paint,
      );
      
      // Draw piece label
      final textPainter = TextPainter(
        text: TextSpan(
          text: entry.key.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          bounds.center.dx - textPainter.width / 2,
          bounds.center.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawDraggingPiece(Canvas canvas) {
    if (dragPosition == null || draggingPiece == null) return;
    
    final canvasPoint = coordSystem.workspaceToCanvas(dragPosition!);
    final cellSize = coordSystem.config.gridCellSize * coordSystem.config.zoomLevel;
    
    final pieceColors = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
    };
    
    final paint = Paint()
      ..color = (pieceColors[draggingPiece] ?? Colors.grey).withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    // Draw semi-transparent dragging piece
    final pieceRect = Rect.fromCenter(
      center: Offset(canvasPoint.x, canvasPoint.y),
      width: cellSize - 10,
      height: cellSize - 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pieceRect, const Radius.circular(8)),
      paint,
    );
    
    // Draw piece label
    final textPainter = TextPainter(
      text: TextSpan(
        text: draggingPiece!.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        canvasPoint.x - textPainter.width / 2,
        canvasPoint.y - textPainter.height / 2,
      ),
    );
  }

  void _drawPerformanceOverlay(Canvas canvas, Size size) {
    final stats = coordSystem.getPerformanceStats();
    final avgTime = stats['averageTransformationTimeUs'] as double;
    final meetsTarget = stats['meetsTargetPerformance'] as bool;
    
    final text = 'Avg: ${avgTime.toStringAsFixed(1)}μs';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: meetsTarget ? Colors.green : Colors.orange,
          fontSize: 10,
          backgroundColor: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - textPainter.width - 10, 10),
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return coordSystem != oldDelegate.coordSystem ||
        pieces != oldDelegate.pieces ||
        draggingPiece != oldDelegate.draggingPiece ||
        dragPosition != oldDelegate.dragPosition ||
        highlightedCell != oldDelegate.highlightedCell;
  }
}
