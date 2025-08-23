# Technical Architecture Vision
## Implementation Strategy for Puzzle Nook

*Version 1.0 - Technical Foundation*

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Presentation Layer                      │
│  ┌──────────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │ Game UI      │  │ Settings  │  │ Social Features  │  │
│  │ (Flutter)    │  │ UI        │  │ UI               │  │
│  └──────────────┘  └───────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────┘
                              │
┌──────────────────────────────────────────────────────────┐
│                    Business Logic Layer                    │
│  ┌──────────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │ Game Engine  │  │ AI Engine │  │ State Manager    │  │
│  │ (Magnetic)   │  │ (ML Kit)  │  │ (Event Sourced)  │  │
│  └──────────────┘  └───────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────┘
                              │
┌──────────────────────────────────────────────────────────┐
│                      Data Layer                           │
│  ┌──────────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │ Local DB     │  │ Asset     │  │ Analytics        │  │
│  │ (Hive/Isar)  │  │ Manager   │  │ (Firebase)       │  │
│  └──────────────┘  └───────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### 1.2 Core Module Structure

```dart
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   └── utils/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── data/
│   ├── models/
│   ├── datasources/
│   └── repositories/
├── presentation/
│   ├── screens/
│   ├── widgets/
│   └── controllers/
├── game_engine/
│   ├── physics/
│   ├── rendering/
│   ├── interaction/
│   └── ai/
└── main.dart
```

---

## 2. Game Engine Architecture

### 2.1 Magnetic Field System

```dart
abstract class MagneticFieldSystem {
  // Core field calculation engine
  class FieldCalculator {
    // Calculate field strength at a point
    double calculateFieldStrength(Vector2 point, Piece piece) {
      final distance = (piece.targetPosition - point).length;
      final normalizedDistance = distance / maxFieldRadius;
      
      // Inverse square law with cutoff
      if (normalizedDistance > 1.0) return 0.0;
      
      return fieldStrength * pow(1 - normalizedDistance, 2);
    }
    
    // Calculate force vector
    Vector2 calculateForce(Piece piece, Vector2 position) {
      final direction = (piece.targetPosition - position).normalized();
      final strength = calculateFieldStrength(position, piece);
      
      return direction * strength * magneticConstant;
    }
  }
  
  // Field visualization
  class FieldRenderer {
    void renderField(Canvas canvas, List<Piece> pieces) {
      // Use compute shader for field calculation
      final fieldTexture = calculateFieldTexture(pieces);
      
      // Render as overlay with custom shader
      canvas.drawImage(
        fieldTexture,
        Offset.zero,
        Paint()..blendMode = BlendMode.multiply,
      );
    }
  }
}
```

### 2.2 Physics Engine Integration

```dart
class PhysicsEngine {
  // Use Forge2D for physics simulation
  late World world;
  late ContactListener contactListener;
  
  void initialize() {
    world = World(Vector2(0, 0)); // No gravity for top-down view
    contactListener = PuzzleContactListener();
    world.setContactListener(contactListener);
  }
  
  // Create physics body for piece
  Body createPieceBody(Piece piece) {
    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = piece.position
      ..linearDamping = 0.8 // Smooth movement
      ..angularDamping = 0.9; // Controlled rotation
    
    final body = world.createBody(bodyDef);
    
    // Complex shape from piece outline
    final shape = ChainShape()
      ..createLoop(piece.outline);
    
    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..friction = 0.3
      ..restitution = 0.2;
    
    body.createFixture(fixtureDef);
    return body;
  }
  
  // Apply magnetic forces
  void applyMagneticForces(List<Piece> pieces) {
    for (final piece in pieces) {
      if (piece.state == PieceState.FLOATING) {
        final force = calculateMagneticForce(piece);
        piece.body.applyForceToCenter(force);
      }
    }
  }
}
```

### 2.3 Rendering Pipeline

```dart
class RenderingPipeline {
  // Multi-layer rendering system
  late PictureRecorder backgroundRecorder;
  late PictureRecorder foregroundRecorder;
  late PictureRecorder effectsRecorder;
  
  // Render complete frame
  void renderFrame(Canvas canvas, Size size, GameState state) {
    // Layer 1: Static background (cached)
    if (backgroundDirty) {
      backgroundPicture = renderBackground(state);
      backgroundDirty = false;
    }
    canvas.drawPicture(backgroundPicture);
    
    // Layer 2: Dynamic pieces
    renderPieces(canvas, state.pieces);
    
    // Layer 3: Effects and particles
    renderEffects(canvas, state.effects);
    
    // Layer 4: UI overlay
    renderUI(canvas, state.ui);
  }
  
  // Optimized piece rendering
  void renderPieces(Canvas canvas, List<Piece> pieces) {
    // Sort by render layer
    pieces.sort((a, b) => a.layer.compareTo(b.layer));
    
    for (final piece in pieces) {
      canvas.save();
      
      // Apply transformations
      canvas.translate(piece.position.x, piece.position.y);
      canvas.rotate(piece.rotation);
      canvas.scale(piece.scale);
      
      // Use cached picture if available
      if (piece.cachedPicture != null) {
        canvas.drawPicture(piece.cachedPicture!);
      } else {
        piece.cachedPicture = renderPiece(piece);
        canvas.drawPicture(piece.cachedPicture!);
      }
      
      // Render dynamic effects
      if (piece.hasEffects) {
        renderPieceEffects(canvas, piece);
      }
      
      canvas.restore();
    }
  }
}
```

---

## 3. State Management Architecture

### 3.1 Event-Sourced State System

```dart
// Event sourcing for perfect replay and undo
abstract class GameEvent {
  final DateTime timestamp;
  final String playerId;
  
  GameState apply(GameState state);
  GameState rollback(GameState state);
}

class PiecePlacedEvent extends GameEvent {
  final String pieceId;
  final Vector2 position;
  final double rotation;
  
  @override
  GameState apply(GameState state) {
    return state.copyWith(
      pieces: state.pieces.map((p) {
        if (p.id == pieceId) {
          return p.copyWith(
            position: position,
            rotation: rotation,
            state: PieceState.PLACED,
          );
        }
        return p;
      }).toList(),
      score: state.score + calculateScore(),
    );
  }
  
  @override
  GameState rollback(GameState state) {
    return state.copyWith(
      pieces: state.pieces.map((p) {
        if (p.id == pieceId) {
          return p.copyWith(
            state: PieceState.FLOATING,
            position: p.previousPosition,
          );
        }
        return p;
      }).toList(),
      score: state.score - calculateScore(),
    );
  }
}

class EventStore {
  final List<GameEvent> _events = [];
  final StreamController<GameEvent> _eventStream = StreamController.broadcast();
  
  // Add event to store
  void addEvent(GameEvent event) {
    _events.add(event);
    _eventStream.add(event);
    _persistEvent(event);
  }
  
  // Rebuild state from events
  GameState rebuildState() {
    return _events.fold(
      GameState.initial(),
      (state, event) => event.apply(state),
    );
  }
  
  // Time travel debugging
  GameState getStateAt(DateTime timestamp) {
    final relevantEvents = _events
        .where((e) => e.timestamp.isBefore(timestamp))
        .toList();
    
    return relevantEvents.fold(
      GameState.initial(),
      (state, event) => event.apply(state),
    );
  }
}
```

### 3.2 Reactive State Management

```dart
// Using Riverpod for reactive state
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  return GameStateNotifier(ref);
});

class GameStateNotifier extends StateNotifier<GameState> {
  final Ref ref;
  late final EventStore eventStore;
  late final PhysicsEngine physics;
  
  GameStateNotifier(this.ref) : super(GameState.initial()) {
    eventStore = EventStore();
    physics = PhysicsEngine();
    _initialize();
  }
  
  // Handle user input
  void handlePieceGrab(String pieceId, Vector2 position) {
    final event = PieceGrabbedEvent(
      pieceId: pieceId,
      position: position,
      timestamp: DateTime.now(),
    );
    
    // Optimistic update
    state = event.apply(state);
    
    // Store event
    eventStore.addEvent(event);
    
    // Start physics simulation
    physics.startDragging(pieceId);
  }
  
  // Undo/Redo support
  void undo() {
    if (eventStore.canUndo) {
      final lastEvent = eventStore.getLastEvent();
      state = lastEvent.rollback(state);
      eventStore.removeLastEvent();
    }
  }
}
```

---

## 4. AI and Machine Learning

### 4.1 Neural Suggestion Engine

```dart
class NeuralSuggestionEngine {
  late Interpreter interpreter;
  late List<double> userPattern;
  
  Future<void> initialize() async {
    // Load TensorFlow Lite model
    final modelData = await rootBundle.load('assets/ml/suggestion_model.tflite');
    interpreter = Interpreter.fromBuffer(modelData.buffer.asUint8List());
    
    // Initialize user pattern vector
    userPattern = List.filled(64, 0.0);
  }
  
  // Analyze user behavior
  void updateUserPattern(UserAction action) {
    // Extract features
    final features = extractFeatures(action);
    
    // Update pattern using exponential moving average
    for (int i = 0; i < features.length; i++) {
      userPattern[i] = userPattern[i] * 0.9 + features[i] * 0.1;
    }
  }
  
  // Get piece suggestions
  List<String> getSuggestedPieces(GameState state) {
    // Prepare input tensor
    final input = [
      ...userPattern,
      ...encodeGameState(state),
      ...encodeAvailablePieces(state.pieces),
    ];
    
    // Run inference
    final output = List.filled(state.pieces.length, 0.0);
    interpreter.run(input, output);
    
    // Sort pieces by suggestion score
    final suggestions = state.pieces
        .asMap()
        .entries
        .map((e) => MapEntry(e.key, output[e.key]))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Return top 5 suggestions
    return suggestions
        .take(5)
        .map((e) => state.pieces[e.key].id)
        .toList();
  }
}
```

### 4.2 Adaptive Difficulty System

```dart
class AdaptiveDifficultyEngine {
  // Player skill estimation
  double estimatedSkillLevel = 0.5; // 0.0 to 1.0
  
  // Performance metrics
  final RollingAverage successRate = RollingAverage(window: 20);
  final RollingAverage timePerPiece = RollingAverage(window: 10);
  final RollingAverage mistakeRate = RollingAverage(window: 15);
  
  // Update skill estimation
  void updateSkillEstimate(PlayerAction action) {
    if (action is SuccessfulPlacement) {
      successRate.add(1.0);
      timePerPiece.add(action.duration.inSeconds.toDouble());
    } else if (action is FailedPlacement) {
      successRate.add(0.0);
      mistakeRate.add(1.0);
    }
    
    // Bayesian skill estimation
    estimatedSkillLevel = calculateBayesianSkillEstimate(
      successRate.average,
      timePerPiece.average,
      mistakeRate.average,
    );
  }
  
  // Adjust game parameters
  DifficultyParameters getAdjustedParameters() {
    return DifficultyParameters(
      magneticRadius: lerp(20, 50, 1.0 - estimatedSkillLevel),
      magneticStrength: lerp(0.5, 2.0, 1.0 - estimatedSkillLevel),
      ghostPreviewOpacity: lerp(0.0, 0.5, 1.0 - estimatedSkillLevel),
      autoRotationAssist: estimatedSkillLevel < 0.3,
      suggestionsEnabled: estimatedSkillLevel < 0.5,
      hintsDelay: lerp(2.0, 10.0, estimatedSkillLevel),
    );
  }
}
```

---

## 5. Performance Optimization

### 5.1 Memory Management

```dart
class MemoryManager {
  // Object pooling for frequently created objects
  final ObjectPool<Particle> particlePool = ObjectPool(
    create: () => Particle(),
    reset: (p) => p.reset(),
    maxSize: 1000,
  );
  
  final ObjectPool<Matrix4> matrixPool = ObjectPool(
    create: () => Matrix4.identity(),
    reset: (m) => m.setIdentity(),
    maxSize: 100,
  );
  
  // Texture atlas management
  late ui.Image textureAtlas;
  final Map<String, Rect> textureRegions = {};
  
  Future<void> loadTextureAtlas() async {
    // Load combined texture atlas
    final data = await rootBundle.load('assets/textures/atlas.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 2048,
      targetHeight: 2048,
    );
    textureAtlas = (await codec.getNextFrame()).image;
    
    // Load region definitions
    final json = await rootBundle.loadString('assets/textures/atlas.json');
    final regions = jsonDecode(json) as Map<String, dynamic>;
    
    regions.forEach((key, value) {
      textureRegions[key] = Rect.fromLTWH(
        value['x'].toDouble(),
        value['y'].toDouble(),
        value['width'].toDouble(),
        value['height'].toDouble(),
      );
    });
  }
  
  // Aggressive disposal
  void dispose() {
    particlePool.dispose();
    matrixPool.dispose();
    textureAtlas.dispose();
  }
}
```

### 5.2 Rendering Optimization

```dart
class RenderOptimizer {
  // Culling system
  List<Piece> cullPieces(List<Piece> pieces, Rect viewport) {
    return pieces.where((piece) {
      final bounds = piece.getBounds();
      return viewport.overlaps(bounds);
    }).toList();
  }
  
  // Level of detail system
  RenderQuality getQualityForPiece(Piece piece, double zoom) {
    final screenSize = piece.size * zoom;
    
    if (screenSize < 50) {
      return RenderQuality.LOW; // Simple rect
    } else if (screenSize < 200) {
      return RenderQuality.MEDIUM; // Basic shape
    } else {
      return RenderQuality.HIGH; // Full detail
    }
  }
  
  // Batch rendering
  void batchRender(Canvas canvas, List<RenderCommand> commands) {
    // Sort by texture to minimize state changes
    commands.sort((a, b) => a.textureId.compareTo(b.textureId));
    
    String? currentTexture;
    final Paint paint = Paint();
    
    for (final command in commands) {
      if (command.textureId != currentTexture) {
        // Change texture binding
        currentTexture = command.textureId;
        paint.shader = getTextureShader(currentTexture);
      }
      
      canvas.drawRect(command.destination, paint);
    }
  }
}
```

---

## 6. Testing Strategy

### 6.1 Unit Testing

```dart
// Test magnetic field calculations
void main() {
  group('MagneticField', () {
    test('calculates correct field strength', () {
      final field = MagneticField(
        center: Vector2(100, 100),
        strength: 1.0,
        radius: 50,
      );
      
      expect(field.getStrengthAt(Vector2(100, 100)), equals(1.0));
      expect(field.getStrengthAt(Vector2(150, 100)), equals(0.0));
      expect(field.getStrengthAt(Vector2(125, 100)), closeTo(0.25, 0.01));
    });
    
    test('applies correct force direction', () {
      final field = MagneticField(
        center: Vector2(100, 100),
        strength: 1.0,
        radius: 50,
      );
      
      final force = field.getForceAt(Vector2(80, 100));
      expect(force.x, greaterThan(0)); // Points toward center
      expect(force.y, equals(0));
    });
  });
}
```

### 6.2 Widget Testing

```dart
// Test piece interaction
void main() {
  testWidgets('Piece responds to drag', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(),
      ),
    );
    
    // Find a piece
    final piece = find.byType(PieceWidget).first;
    
    // Drag it
    await tester.drag(piece, Offset(100, 0));
    await tester.pump();
    
    // Verify it moved
    final renderBox = tester.renderObject<RenderBox>(piece);
    expect(renderBox.localToGlobal(Offset.zero).dx, greaterThan(0));
  });
}
```

### 6.3 Integration Testing

```dart
// Test complete puzzle flow
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Complete puzzle flow', (tester) async {
    await tester.pumpWidget(MyApp());
    
    // Start new puzzle
    await tester.tap(find.text('New Puzzle'));
    await tester.pumpAndSettle();
    
    // Select difficulty
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();
    
    // Complete puzzle (simplified for test)
    for (int i = 0; i < 9; i++) {
      final piece = find.byKey(Key('piece_$i'));
      final target = find.byKey(Key('target_$i'));
      
      await tester.drag(piece, tester.getCenter(target));
      await tester.pumpAndSettle();
    }
    
    // Verify completion
    expect(find.text('Puzzle Complete!'), findsOneWidget);
  });
}
```

### 6.4 Performance Testing

```dart
// Benchmark rendering performance
void main() {
  test('Maintains 60 FPS with 100 pieces', () async {
    final stopwatch = Stopwatch()..start();
    final frames = <Duration>[];
    
    final game = GameEngine();
    await game.initialize();
    
    // Add 100 pieces
    for (int i = 0; i < 100; i++) {
      game.addPiece(Piece.random());
    }
    
    // Render 600 frames (10 seconds at 60 FPS)
    for (int i = 0; i < 600; i++) {
      final frameStart = stopwatch.elapsed;
      game.update(1/60);
      game.render();
      frames.add(stopwatch.elapsed - frameStart);
    }
    
    // Calculate statistics
    final avgFrameTime = frames.reduce((a, b) => a + b) ~/ frames.length;
    final maxFrameTime = frames.reduce((a, b) => a > b ? a : b);
    
    // Assert performance targets
    expect(avgFrameTime.inMilliseconds, lessThan(16)); // 60 FPS average
    expect(maxFrameTime.inMilliseconds, lessThan(33)); // No frame > 30 FPS
  });
}
```

---

## 7. Platform-Specific Optimizations

### 7.1 Android Optimizations

```dart
// Android-specific rendering hints
if (Platform.isAndroid) {
  // Enable hardware acceleration
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  
  // Use Vulkan renderer if available
  if (await isVulkanAvailable()) {
    FlutterView.setRenderBackend(RenderBackend.vulkan);
  }
  
  // Optimize for battery life
  if (await BatteryLevel.isLow()) {
    RenderSettings.reduceQuality();
    ParticleEffects.disable();
  }
}
```

### 7.2 Linux Desktop Optimizations

```dart
// Linux-specific optimizations
if (Platform.isLinux) {
  // Use native window decorations
  await windowManager.setTitleBarStyle(TitleBarStyle.normal);
  
  // Enable GPU acceleration
  setEnvironmentVariable('FLUTTER_GL_BACKEND', 'gl');
  
  // Optimize for desktop input
  GestureSettings.setMousePrecision(high);
  GestureSettings.enableHoverEffects(true);
  
  // Use desktop-specific layouts
  LayoutSettings.setMinWindowSize(Size(800, 600));
  LayoutSettings.enableResizableUI(true);
}
```

---

## Conclusion

This technical architecture provides a solid foundation for implementing the revolutionary interaction model defined in our vision. Key architectural decisions include:

1. **Event-sourced state** for perfect undo/redo and replay
2. **Hybrid rendering pipeline** for optimal performance
3. **Physics-based interactions** for natural feel
4. **ML-powered assistance** for adaptive difficulty
5. **Comprehensive testing** for reliability
6. **Platform-specific optimizations** for best experience

The architecture is designed to be:
- **Scalable**: Can handle complex puzzles with hundreds of pieces
- **Maintainable**: Clear separation of concerns and modular design
- **Testable**: Comprehensive testing at all levels
- **Performant**: Optimized for 60+ FPS on modern devices
- **Accessible**: Support for all interaction modes

This foundation will enable us to deliver on our vision of creating the most innovative and satisfying puzzle game experience on mobile and desktop platforms.
