// Example usage of the hybrid renderer
import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/presentation/rendering/hybrid_renderer.dart';

class GameRenderingExample extends StatefulWidget {
  const GameRenderingExample({super.key});

  @override
  State<GameRenderingExample> createState() => _GameRenderingExampleState();
}

class _GameRenderingExampleState extends State<GameRenderingExample> {
  final List<ExamplePiece> _pieces = [];
  final ExampleGameState _gameState = ExampleGameState();

  @override
  void initState() {
    super.initState();
    _initializePieces();
  }

  void _initializePieces() {
    // Create some example pieces
    for (int i = 0; i < 10; i++) {
      _pieces.add(ExamplePiece(
        id: 'piece_$i',
        position: Offset(i * 100.0, i * 50.0),
        size: const Size(80, 80),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hybrid Renderer Example'),
      ),
      body: HybridRenderer(
        gameSize: const Size(800, 600),
        pieces: _pieces,
        gameState: _gameState,
        config: const RenderingConfig(
          initialQuality: QualityLevel.high,
          autoAdjustQuality: true,
          showDebugOverlay: true,
        ),
        onPerformanceUpdate: (metrics) {
          debugPrint('FPS: ${metrics.fps}, Quality: ${metrics.quality.name}');
        },
        onFrameDropped: () {
          debugPrint('Frame dropped!');
        },
      ),
    );
  }
}

// Example implementation of RenderablePiece
class ExamplePiece implements RenderablePiece {
  @override
  final String id;
  
  @override
  Offset position;
  
  @override
  double rotation;
  
  @override
  final Size size;
  
  @override
  bool isSelected;
  
  @override
  bool isPlaced;
  
  @override
  bool isDragging;

  ExamplePiece({
    required this.id,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.isSelected = false,
    this.isPlaced = false,
    this.isDragging = false,
  });
}

// Example implementation of GameState
class ExampleGameState implements GameState {
  @override
  bool get showGrid => true;
  
  @override
  List<String> get completedSections => ['section1', 'section2'];
  
  @override
  Map<String, dynamic> get metadata => {
    'level': 1,
    'score': 100,
  };
}
