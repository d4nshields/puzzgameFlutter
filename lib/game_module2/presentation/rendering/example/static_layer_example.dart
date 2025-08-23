/// Example implementation demonstrating the Static Layer Renderer
/// 
/// This example shows how to integrate the static layer with:
/// - Picture caching for optimal performance
/// - Viewport culling for large game areas
/// - Level-of-detail system based on zoom
/// - Debug visualizations
/// - Performance monitoring

import 'package:flutter/material.dart';
import '../static_layer.dart';

/// Example game screen using the static layer renderer
class StaticLayerExample extends StatefulWidget {
  const StaticLayerExample({super.key});

  @override
  State<StaticLayerExample> createState() => _StaticLayerExampleState();
}

class _StaticLayerExampleState extends State<StaticLayerExample>
    with SingleTickerProviderStateMixin {
  // Game state
  late ExampleGameState _gameState;
  
  // Viewport control
  Offset _viewportOffset = Offset.zero;
  double _zoomLevel = 1.0;
  
  // Animation for auto-scrolling demo
  late AnimationController _scrollController;
  late Animation<Offset> _scrollAnimation;
  
  // Performance tracking is handled internally by the StaticLayer
  
  // Debug mode
  bool _debugMode = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize game state
    _gameState = ExampleGameState();
    
    // Setup animation for demo viewport movement
    _scrollController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    _scrollAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(500, 300),
    ).animate(CurvedAnimation(
      parent: _scrollController,
      curve: Curves.easeInOutSine,
    ));
    
    _scrollAnimation.addListener(() {
      setState(() {
        _viewportOffset = _scrollAnimation.value;
      });
    });
    
    // Start demo animation
    _scrollController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleGrid() {
    setState(() {
      _gameState.toggleGrid();
    });
  }

  void _completeSection() {
    setState(() {
      _gameState.completeNextSection();
    });
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel * 1.2).clamp(0.5, 3.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel / 1.2).clamp(0.5, 3.0);
    });
  }

  void _toggleDebugMode() {
    setState(() {
      _debugMode = !_debugMode;
    });
  }

  void _resetViewport() {
    setState(() {
      _viewportOffset = Offset.zero;
      _zoomLevel = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Static Layer Renderer Demo'),
        actions: [
          IconButton(
            icon: Icon(_debugMode ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: _toggleDebugMode,
            tooltip: 'Toggle Debug Mode',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control panel
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleGrid,
                  icon: Icon(_gameState.showGrid ? Icons.grid_on : Icons.grid_off),
                  label: const Text('Grid'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _completeSection,
                  icon: const Icon(Icons.check_circle),
                  label: Text('Complete (${_gameState.completedSections.length})'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _zoomIn,
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Zoom In',
                ),
                Text('${(_zoomLevel * 100).toStringAsFixed(0)}%'),
                IconButton(
                  onPressed: _zoomOut,
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _resetViewport,
                  icon: const Icon(Icons.center_focus_strong),
                  tooltip: 'Reset View',
                ),
                const Spacer(),
                if (_scrollController.isAnimating)
                  TextButton.icon(
                    onPressed: () {
                      _scrollController.stop();
                      setState(() {});
                    },
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  )
                else
                  TextButton.icon(
                    onPressed: () {
                      _scrollController.repeat(reverse: true);
                      setState(() {});
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
              ],
            ),
          ),
          
          // Game area with static layer
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final viewport = Rect.fromLTWH(
                  _viewportOffset.dx,
                  _viewportOffset.dy,
                  size.width / _zoomLevel,
                  size.height / _zoomLevel,
                );
                
                return GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _viewportOffset -= details.delta / _zoomLevel;
                      _viewportOffset = Offset(
                        _viewportOffset.dx.clamp(0, size.width - viewport.width),
                        _viewportOffset.dy.clamp(0, size.height - viewport.height),
                      );
                    });
                  },
                  child: Stack(
                    children: [
                      // Main static layer
                      ClipRect(
                        child: Transform.scale(
                          scale: _zoomLevel,
                          alignment: Alignment.topLeft,
                          child: Transform.translate(
                            offset: -_viewportOffset * _zoomLevel,
                            child: StaticLayer(
                              size: Size(size.width * 2, size.height * 2), // Large game area
                              gameState: _gameState,
                              viewport: viewport,
                              zoomLevel: _zoomLevel,
                              debugMode: _debugMode,
                            ),
                          ),
                        ),
                      ),
                      
                      // Performance overlay
                      if (_debugMode)
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: _buildPerformancePanel(),
                        ),
                      
                      // Minimap
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: _buildMinimap(size),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Info panel
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Text('Viewport: (${_viewportOffset.dx.toStringAsFixed(0)}, ${_viewportOffset.dy.toStringAsFixed(0)})'),
                const SizedBox(width: 20),
                Text('Zoom: ${(_zoomLevel * 100).toStringAsFixed(0)}%'),
                const SizedBox(width: 20),
                Text('Sections: ${_gameState.completedSections.length}'),
                const SizedBox(width: 20),
                Text('Grid: ${_gameState.showGrid ? "ON" : "OFF"}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformancePanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Monitor',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cache Strategy: Picture Recording',
            style: TextStyle(color: Colors.green.shade300, fontSize: 12),
          ),
          Text(
            'Viewport Culling: Active',
            style: TextStyle(color: Colors.green.shade300, fontSize: 12),
          ),
          Text(
            'LOD System: ${_getLODForZoom()}',
            style: TextStyle(color: Colors.blue.shade300, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Optimizations:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            '• Grid cached as ui.Picture',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          Text(
            '• Sections cached individually',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          Text(
            '• Paint objects reused',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          Text(
            '• Culling active: ${_getVisibleItemCount()}',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimap(Size mainSize) {
    const minimapSize = Size(150, 100);
    final scale = minimapSize.width / (mainSize.width * 2);
    
    return Container(
      width: minimapSize.width,
      height: minimapSize.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        color: Colors.white.withOpacity(0.9),
      ),
      child: CustomPaint(
        painter: MinimapPainter(
          gameState: _gameState,
          viewportOffset: _viewportOffset,
          viewportSize: Size(
            mainSize.width / _zoomLevel,
            mainSize.height / _zoomLevel,
          ),
          scale: scale,
        ),
      ),
    );
  }

  String _getLODForZoom() {
    if (_zoomLevel < 0.5) return 'Low';
    if (_zoomLevel < 1.0) return 'Medium';
    return 'High';
  }

  String _getVisibleItemCount() {
    // Calculate visible items based on viewport
    final visibleSections = _gameState.completedSections.where((section) {
      // Simplified check - in real implementation would check actual bounds
      return true;
    }).length;
    
    return '$visibleSections/${_gameState.completedSections.length} sections';
  }
}

/// Example game state implementation
class ExampleGameState implements GameState {
  bool _showGrid = true;
  final List<String> _completedSections = [];
  final Map<String, dynamic> _metadata = {
    'level': 1,
    'score': 0,
    'difficulty': 'medium',
  };

  @override
  bool get showGrid => _showGrid;

  @override
  List<String> get completedSections => _completedSections;

  @override
  Map<String, dynamic> get metadata => _metadata;

  void toggleGrid() {
    _showGrid = !_showGrid;
  }

  void completeNextSection() {
    final nextId = 'section_${_completedSections.length}';
    _completedSections.add(nextId);
    _metadata['score'] = (_metadata['score'] as int) + 100;
  }

  void reset() {
    _completedSections.clear();
    _metadata['score'] = 0;
  }
}

/// Minimap painter
class MinimapPainter extends CustomPainter {
  final GameState gameState;
  final Offset viewportOffset;
  final Size viewportSize;
  final double scale;

  MinimapPainter({
    required this.gameState,
    required this.viewportOffset,
    required this.viewportSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.grey.shade200,
    );
    
    // Draw completed sections
    final sectionPaint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < gameState.completedSections.length; i++) {
      final x = (i % 4) * 30 * scale;
      final y = (i ~/ 4) * 25 * scale;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 25 * scale, 20 * scale),
        sectionPaint,
      );
    }
    
    // Draw viewport rectangle
    final viewportPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawRect(
      Rect.fromLTWH(
        viewportOffset.dx * scale,
        viewportOffset.dy * scale,
        viewportSize.width * scale,
        viewportSize.height * scale,
      ),
      viewportPaint,
    );
  }

  @override
  bool shouldRepaint(MinimapPainter oldDelegate) {
    return oldDelegate.viewportOffset != viewportOffset ||
           oldDelegate.viewportSize != viewportSize ||
           oldDelegate.gameState.completedSections.length != 
           gameState.completedSections.length;
  }
}
