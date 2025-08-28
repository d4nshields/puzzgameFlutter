/// Example integration of the Render Coordinator with all rendering layers
/// 
/// This demonstrates how to set up and use the complete rendering pipeline
/// with the coordinator managing static, dynamic, and effects layers.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/presentation/rendering/render_coordinator.dart';
import 'package:puzzgame_flutter/game_module2/presentation/rendering/effects_layer.dart';

/// Example game widget using the render coordinator
class CoordinatedGameWidget extends StatefulWidget {
  const CoordinatedGameWidget({super.key});

  @override
  State<CoordinatedGameWidget> createState() => _CoordinatedGameWidgetState();
}

class _CoordinatedGameWidgetState extends State<CoordinatedGameWidget> {
  late final RenderCoordinator _coordinator;
  late final StaticRenderLayer _staticLayer;
  late final DynamicRenderLayer _dynamicLayer;
  late final EffectsRenderLayer _effectsLayer;
  late final EffectsController _effectsController;

  @override
  void initState() {
    super.initState();
    _initializeRenderingPipeline();
  }

  void _initializeRenderingPipeline() {
    // Create the coordinator with custom configuration
    _coordinator = RenderCoordinator(
      config: RenderCoordinatorConfig(
        targetFrameRate: 60,
        initialQuality: QualityLevel.high,
        autoAdaptQuality: true,
        enableDeveloperTools: true,
      ),
    );

    // Create render layers
    _staticLayer = StaticRenderLayer(
      gameSize: const Size(800, 600),
      onUpdate: () => _coordinator.scheduleFrame(
        layers: {RenderLayerType.static},
        priority: RenderPriority.low,
      ),
    );

    _dynamicLayer = DynamicRenderLayer(
      gameSize: const Size(800, 600),
      onUpdate: () => _coordinator.scheduleFrame(
        layers: {RenderLayerType.dynamic},
        priority: RenderPriority.normal,
      ),
    );

    _effectsController = EffectsController();
    _effectsLayer = EffectsRenderLayer(
      controller: _effectsController,
      onUpdate: () => _coordinator.scheduleFrame(
        layers: {RenderLayerType.effects},
        priority: RenderPriority.high,
      ),
    );

    // Register layers with coordinator
    _coordinator.registerLayer(RenderLayerType.static, _staticLayer);
    _coordinator.registerLayer(RenderLayerType.dynamic, _dynamicLayer);
    _coordinator.registerLayer(RenderLayerType.effects, _effectsLayer);

    // Listen for coordinator notifications
    _coordinator.addListener(_onCoordinatorUpdate);
  }

  void _onCoordinatorUpdate() {
    // React to coordinator state changes
    setState(() {
      // Update UI based on coordinator state
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordinated Rendering Example'),
        actions: [
          // Profiling mode selector
          PopupMenuButton<ProfilingMode>(
            onSelected: _coordinator.setProfilingMode,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ProfilingMode.off,
                child: Text('Profiling Off'),
              ),
              const PopupMenuItem(
                value: ProfilingMode.basic,
                child: Text('Basic Profiling'),
              ),
              const PopupMenuItem(
                value: ProfilingMode.detailed,
                child: Text('Detailed Profiling'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main game rendering area
          _buildGameArea(),
          
          // Developer overlay (if enabled)
          if (_coordinator.getDeveloperOverlay() != null)
            _coordinator.getDeveloperOverlay()!,
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'effects',
            onPressed: _triggerEffects,
            tooltip: 'Trigger Effects',
            child: const Icon(Icons.auto_awesome),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'quality',
            onPressed: _cycleQuality,
            tooltip: 'Change Quality',
            child: const Icon(Icons.tune),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'message',
            onPressed: _sendTestMessage,
            tooltip: 'Send Test Message',
            child: const Icon(Icons.message),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Static layer widget
            CustomPaint(
              size: constraints.biggest,
              painter: StaticLayerPainter(layer: _staticLayer),
            ),
            
            // Dynamic layer widget
            DynamicLayerWidget(
              layer: _dynamicLayer,
              size: constraints.biggest,
            ),
            
            // Effects layer
            EffectsLayer(
              size: constraints.biggest,
              controller: _effectsController,
              debugMode: false,
            ),
          ],
        );
      },
    );
  }

  void _triggerEffects() {
    // Trigger various effects through the coordinator
    _effectsController.triggerEffect(
      const CelebrationEffect(
        position: Offset(400, 300),
        intensity: 1.5,
      ),
    );

    // Schedule high-priority frame for effects
    _coordinator.scheduleFrame(
      layers: {RenderLayerType.effects},
      priority: RenderPriority.critical,
      metadata: {'effect': 'celebration'},
    );
  }

  void _cycleQuality() {
    final snapshot = _coordinator.getPerformanceSnapshot();
    final currentQuality = snapshot.currentQuality;
    
    QualityLevel newQuality;
    switch (currentQuality) {
      case QualityLevel.low:
        newQuality = QualityLevel.medium;
        break;
      case QualityLevel.medium:
        newQuality = QualityLevel.high;
        break;
      case QualityLevel.high:
        newQuality = QualityLevel.ultra;
        break;
      case QualityLevel.ultra:
        newQuality = QualityLevel.low;
        break;
    }
    
    // Send quality change message through coordinator
    _coordinator.sendMessage(LayerMessage(
      type: MessageType.qualityChanged,
      sender: RenderLayerType.coordinator,
      data: {'quality': newQuality},
    ));
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quality changed to ${newQuality.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _sendTestMessage() {
    // Send a test message through the communication bus
    _coordinator.sendMessage(LayerMessage(
      type: MessageType.custom,
      sender: RenderLayerType.coordinator,
      data: {
        'action': 'test',
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Inter-layer communication test',
      },
    ));
    
    // Force a frame update across all layers
    _coordinator.forceFrame();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test message sent to all layers'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _coordinator.removeListener(_onCoordinatorUpdate);
    _coordinator.dispose();
    _effectsController.dispose();
    super.dispose();
  }
}

/// Example static layer implementation
class StaticRenderLayer extends RenderLayer {
  final Size gameSize;
  final VoidCallback onUpdate;
  
  // Static content (e.g., background, grid)
  final List<Rect> gridCells = [];
  Color backgroundColor = Colors.blueGrey.shade900;
  
  StaticRenderLayer({
    required this.gameSize,
    required this.onUpdate,
  }) {
    _initializeGrid();
  }
  
  void _initializeGrid() {
    const cellSize = 50.0;
    for (double x = 0; x < gameSize.width; x += cellSize) {
      for (double y = 0; y < gameSize.height; y += cellSize) {
        gridCells.add(Rect.fromLTWH(x, y, cellSize, cellSize));
      }
    }
  }
  
  @override
  void performRender() {
    // Static layer rendering logic
    // This would typically update a canvas or texture
  }
  
  @override
  void handleMessage(LayerMessage message) {
    if (message.type == MessageType.qualityChanged) {
      final quality = message.data['quality'] as QualityLevel;
      _adjustRenderingForQuality(quality);
    }
  }
  
  void _adjustRenderingForQuality(QualityLevel quality) {
    // Adjust static layer rendering based on quality
    switch (quality) {
      case QualityLevel.low:
        // Reduce detail
        break;
      case QualityLevel.medium:
        // Standard detail
        break;
      case QualityLevel.high:
        // High detail
        break;
      case QualityLevel.ultra:
        // Maximum detail
        break;
    }
  }
  
  @override
  void updateQuality(QualityLevel quality) {
    _adjustRenderingForQuality(quality);
    markNeedsUpdate();
  }
  
  @override
  RenderLayerType get layerType => RenderLayerType.static;
}

/// Example dynamic layer implementation
class DynamicRenderLayer extends RenderLayer {
  final Size gameSize;
  final VoidCallback onUpdate;
  
  // Dynamic content (e.g., puzzle pieces)
  final List<AnimatedPiece> pieces = [];
  
  DynamicRenderLayer({
    required this.gameSize,
    required this.onUpdate,
  }) {
    _initializePieces();
  }
  
  void _initializePieces() {
    // Create example animated pieces
    for (int i = 0; i < 10; i++) {
      pieces.add(AnimatedPiece(
        position: Offset(
          (i * 80.0) % gameSize.width,
          ((i * 60.0) % gameSize.height),
        ),
        size: const Size(60, 60),
      ));
    }
  }
  
  @override
  void performRender() {
    // Update animations
    for (final piece in pieces) {
      piece.update();
    }
  }
  
  @override
  void handleMessage(LayerMessage message) {
    if (message.type == MessageType.custom) {
      debugPrint('Dynamic layer received: ${message.data}');
    }
  }
  
  @override
  void updateQuality(QualityLevel quality) {
    // Adjust animation smoothness based on quality
    for (final piece in pieces) {
      piece.setQuality(quality);
    }
  }
  
  @override
  RenderLayerType get layerType => RenderLayerType.dynamic;
}

/// Example effects layer implementation
class EffectsRenderLayer extends RenderLayer {
  final EffectsController controller;
  final VoidCallback onUpdate;
  
  EffectsRenderLayer({
    required this.controller,
    required this.onUpdate,
  }) {
    controller.addListener(onUpdate);
  }
  
  @override
  void performRender() {
    // Effects are rendered through the EffectsController
    // This method would sync with the effects system
  }
  
  @override
  void handleMessage(LayerMessage message) {
    if (message.type == MessageType.custom) {
      // Trigger a visual effect in response
      controller.triggerEffect(
        const TouchRippleEffect(
          position: Offset(400, 300),
          color: Colors.white70,
        ),
      );
    }
  }
  
  @override
  void updateQuality(QualityLevel quality) {
    // Effects controller handles quality internally
  }
  
  @override
  RenderLayerType get layerType => RenderLayerType.effects;
}

/// Custom painter for static layer
class StaticLayerPainter extends CustomPainter {
  final StaticRenderLayer layer;
  
  StaticLayerPainter({required this.layer});
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = layer.backgroundColor,
    );
    
    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (final cell in layer.gridCells) {
      canvas.drawRect(cell, gridPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant StaticLayerPainter oldDelegate) {
    return layer.needsUpdate;
  }
}

/// Widget for dynamic layer
class DynamicLayerWidget extends StatelessWidget {
  final DynamicRenderLayer layer;
  final Size size;
  
  const DynamicLayerWidget({
    super.key,
    required this.layer,
    required this.size,
  });
  
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: DynamicLayerPainter(layer: layer),
    );
  }
}

/// Custom painter for dynamic layer
class DynamicLayerPainter extends CustomPainter {
  final DynamicRenderLayer layer;
  
  DynamicLayerPainter({required this.layer});
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw animated pieces
    for (final piece in layer.pieces) {
      piece.draw(canvas);
    }
  }
  
  @override
  bool shouldRepaint(covariant DynamicLayerPainter oldDelegate) {
    return true; // Always repaint for animations
  }
}

/// Example animated piece
class AnimatedPiece {
  Offset position;
  final Size size;
  double rotation = 0;
  double scale = 1.0;
  Color color = Colors.primaries[DateTime.now().millisecond % Colors.primaries.length];
  
  AnimatedPiece({
    required this.position,
    required this.size,
  });
  
  void update() {
    // Simple animation
    rotation += 0.01;
    scale = 1.0 + 0.1 * math.sin(DateTime.now().millisecondsSinceEpoch / 1000.0);
  }
  
  void setQuality(QualityLevel quality) {
    // Adjust animation complexity based on quality
  }
  
  void draw(Canvas canvas) {
    canvas.save();
    
    // Apply transformations
    canvas.translate(position.dx + size.width / 2, position.dy + size.height / 2);
    canvas.rotate(rotation);
    canvas.scale(scale);
    
    // Draw piece
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );
    
    canvas.restore();
  }
}
