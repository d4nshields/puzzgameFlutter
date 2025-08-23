# Puzzle Nook - New Architecture Design Document
## Phase 2 - Complete Redesign Based on Vision

**Document Version:** 2.0  
**Date:** August 22, 2025  
**Author:** Flutter Game Architecture Team

---

## 1. Rendering Architecture Design

### 1.1 Hybrid Rendering Pipeline

We will implement a three-layer rendering architecture that combines the best of Flutter widgets, custom painting, and game engine capabilities:

```dart
/// Core rendering pipeline architecture
class HybridRenderingPipeline {
  // Layer 1: Static Background Layer (CustomPaint with Picture caching)
  // - Game board grid
  // - Completed puzzle sections
  // - Background effects
  // Updates: Only when pieces lock in place
  
  // Layer 2: Dynamic Piece Layer (Optimized Widgets)
  // - Active puzzle pieces
  // - Each piece in its own RepaintBoundary
  // - Hardware-accelerated transforms
  // Updates: Per-piece as needed
  
  // Layer 3: Effects Layer (Flame Engine)
  // - Particle systems
  // - Magnetic field visualizations
  // - Celebration animations
  // Updates: 60-120 FPS independent of other layers
}
```

#### 1.1.1 Static Background Renderer

```dart
class StaticBoardRenderer extends CustomPainter {
  final ui.Picture? _cachedPicture;
  final bool _needsRepaint;
  
  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedPicture == null || _needsRepaint) {
      _cachedPicture = _recordStaticElements(size);
    }
    canvas.drawPicture(_cachedPicture!);
  }
  
  ui.Picture _recordStaticElements(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw grid
    _drawPuzzleGrid(canvas, size);
    
    // Draw completed sections
    _drawCompletedSections(canvas);
    
    // Draw background field effects
    _drawStaticFieldEffects(canvas);
    
    return recorder.endRecording();
  }
}
```

#### 1.1.2 Dynamic Piece Renderer

```dart
class DynamicPieceLayer extends StatefulWidget {
  final List<RenderablePiece> pieces;
  final MagneticFieldSystem fieldSystem;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: pieces.map((piece) => 
        RepaintBoundary(
          key: ValueKey(piece.id),
          child: AnimatedPieceWidget(
            piece: piece,
            fieldInfluence: fieldSystem.getInfluence(piece),
            onTransformUpdate: (transform) => 
              fieldSystem.updatePieceTransform(piece.id, transform),
          ),
        ),
      ).toList(),
    );
  }
}
```

#### 1.1.3 Effects Layer Integration

```dart
class EffectsLayer extends GameWidget {
  @override
  Game createGame() => PuzzleEffectsGame();
}

class PuzzleEffectsGame extends FlameGame {
  late ParticleSystem magneticFieldParticles;
  late CelebrationSystem celebrationEffects;
  
  @override
  Future<void> onLoad() async {
    magneticFieldParticles = MagneticFieldParticleSystem();
    celebrationEffects = CelebrationSystem();
    
    add(magneticFieldParticles);
    add(celebrationEffects);
  }
}
```

### 1.2 Coordinate System Management

#### 1.2.1 Unified Coordinate System

```dart
/// Central coordinate system managing all transformations
class UnifiedCoordinateSystem {
  // Coordinate spaces
  final ScreenSpace screen;
  final CanvasSpace canvas;
  final GridSpace grid;
  final WorkspaceSpace workspace;
  
  // Transformation matrices
  Matrix4 screenToCanvas;
  Matrix4 canvasToGrid;
  Matrix4 gridToWorkspace;
  
  // Bidirectional transformations
  Offset screenToWorkspace(Offset screenPoint) {
    final canvasPoint = screen.toCanvas(screenPoint, screenToCanvas);
    final gridPoint = canvas.toGrid(canvasPoint, canvasToGrid);
    return grid.toWorkspace(gridPoint, gridToWorkspace);
  }
  
  Offset workspaceToScreen(Offset workspacePoint) {
    final gridPoint = workspace.toGrid(workspacePoint, gridToWorkspace.inverse());
    final canvasPoint = grid.toCanvas(gridPoint, canvasToGrid.inverse());
    return canvas.toScreen(canvasPoint, screenToCanvas.inverse());
  }
  
  // Viewport management
  Rect getVisibleWorkspaceRect() {
    final screenRect = Rect.fromLTWH(0, 0, screen.width, screen.height);
    return transformRect(screenRect, screenToWorkspace);
  }
}
```

### 1.3 Transformation Hierarchy

```dart
class TransformationHierarchy {
  // Root transform (viewport)
  final ViewportTransform viewport;
  
  // Piece transforms
  final Map<String, PieceTransform> pieceTransforms = {};
  
  // Hierarchical update
  void updatePieceTransform(String pieceId, Matrix4 localTransform) {
    final globalTransform = viewport.transform * localTransform;
    pieceTransforms[pieceId] = PieceTransform(
      local: localTransform,
      global: globalTransform,
      timestamp: DateTime.now(),
    );
    
    // Notify dependent systems
    _notifyTransformListeners(pieceId, globalTransform);
  }
  
  // Batch transformations for performance
  void batchUpdate(Map<String, Matrix4> updates) {
    final batch = TransformBatch();
    updates.forEach((id, transform) {
      batch.add(id, viewport.transform * transform);
    });
    _applyBatch(batch);
  }
}
```

### 1.4 Repaint Optimization Strategy

```dart
class RepaintOptimizationStrategy {
  // Dirty region tracking
  final Set<Rect> _dirtyRegions = {};
  
  // Layer-specific optimization
  bool shouldRepaintStaticLayer() => _dirtyRegions.any((r) => r.overlaps(_staticLayerBounds));
  bool shouldRepaintPiece(String pieceId) => _piecesDirtyFlags[pieceId] ?? false;
  bool shouldRepaintEffects() => true; // Always update at target FPS
  
  // Intelligent batching
  void scheduleRepaint(RepaintRequest request) {
    if (request.priority == RepaintPriority.immediate) {
      _immediateRepaint(request);
    } else {
      _batchedRepaints.add(request);
      _scheduleNextBatch();
    }
  }
  
  // Frame budget management
  void _scheduleNextBatch() {
    const frameBudget = Duration(milliseconds: 8); // Half of 16ms frame
    
    Timer.run(() {
      final stopwatch = Stopwatch()..start();
      
      while (_batchedRepaints.isNotEmpty && 
             stopwatch.elapsed < frameBudget) {
        _processBatchedRepaint(_batchedRepaints.removeFirst());
      }
    });
  }
}
```

---

## 2. Interaction Layer Architecture

### 2.1 Gesture Recognition System

```dart
/// Advanced gesture recognition with magnetic field awareness
class MagneticGestureRecognizer extends OneSequenceGestureRecognizer {
  // Gesture states
  GestureState _state = GestureState.ready;
  
  // Magnetic field influence
  double _fieldStrength = 0.0;
  Vector2 _fieldDirection = Vector2.zero();
  
  @override
  void addPointer(PointerEvent event) {
    // Check if pointer is over a piece
    final piece = _hitTest(event.position);
    if (piece != null) {
      // Calculate magnetic influence
      _fieldStrength = magneticField.getStrengthAt(event.position);
      _fieldDirection = magneticField.getDirectionAt(event.position);
      
      // Adjust gesture recognition based on field
      _adjustSensitivity(_fieldStrength);
    }
    
    super.addPointer(event);
  }
  
  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      // Apply magnetic assistance to movement
      final adjustedDelta = _applyMagneticAssistance(event.delta);
      _processMovement(event.position, adjustedDelta);
    }
  }
  
  Offset _applyMagneticAssistance(Offset delta) {
    // Blend user input with magnetic field suggestion
    final magneticSuggestion = Offset(
      _fieldDirection.x * _fieldStrength,
      _fieldDirection.y * _fieldStrength,
    );
    
    // Weighted average based on field strength
    return delta * (1 - _fieldStrength * 0.3) + 
           magneticSuggestion * (_fieldStrength * 0.3);
  }
}
```

### 2.2 Piece Interaction State Machine

```dart
/// State machine managing all piece interaction states
class PieceStateMachine {
  // States
  enum PieceState {
    idle,
    hovering,
    selected,
    dragging,
    snapping,
    magnetized,
    placed,
    locked,
    celebrating,
  }
  
  // Transitions
  final Map<PieceState, Map<InteractionEvent, PieceState>> _transitions = {
    PieceState.idle: {
      InteractionEvent.pointerEnter: PieceState.hovering,
      InteractionEvent.tap: PieceState.selected,
    },
    PieceState.hovering: {
      InteractionEvent.pointerExit: PieceState.idle,
      InteractionEvent.dragStart: PieceState.dragging,
      InteractionEvent.tap: PieceState.selected,
    },
    PieceState.selected: {
      InteractionEvent.tap: PieceState.idle,
      InteractionEvent.dragStart: PieceState.dragging,
      InteractionEvent.targetFound: PieceState.magnetized,
    },
    PieceState.dragging: {
      InteractionEvent.dragEnd: PieceState.idle,
      InteractionEvent.nearTarget: PieceState.snapping,
    },
    PieceState.snapping: {
      InteractionEvent.snapComplete: PieceState.placed,
      InteractionEvent.dragContinue: PieceState.dragging,
    },
    PieceState.magnetized: {
      InteractionEvent.release: PieceState.placed,
      InteractionEvent.dragAway: PieceState.dragging,
    },
    PieceState.placed: {
      InteractionEvent.validate: PieceState.locked,
      InteractionEvent.reject: PieceState.idle,
    },
    PieceState.locked: {
      InteractionEvent.puzzleComplete: PieceState.celebrating,
    },
  };
  
  // Current states for all pieces
  final Map<String, PieceState> _pieceStates = {};
  
  // State change handlers
  final Map<PieceState, StateHandler> _stateHandlers = {};
  
  void transition(String pieceId, InteractionEvent event) {
    final currentState = _pieceStates[pieceId] ?? PieceState.idle;
    final nextState = _transitions[currentState]?[event];
    
    if (nextState != null) {
      _exitState(pieceId, currentState);
      _enterState(pieceId, nextState);
      _pieceStates[pieceId] = nextState;
      
      // Notify listeners
      _notifyStateChange(pieceId, currentState, nextState);
    }
  }
}
```

### 2.3 Feedback Controller Architecture

```dart
/// Multi-channel feedback orchestrator
class FeedbackController {
  // Feedback channels
  final HapticChannel haptic;
  final AudioChannel audio;
  final VisualChannel visual;
  
  // Feedback patterns
  final Map<FeedbackEvent, FeedbackPattern> patterns = {
    FeedbackEvent.piecePickup: FeedbackPattern(
      haptic: HapticFeedback.lightImpact(),
      audio: SoundEffect('pickup.wav', volume: 0.3),
      visual: GlowEffect(color: Colors.blue, intensity: 0.5),
    ),
    FeedbackEvent.nearSnap: FeedbackPattern(
      haptic: HapticFeedback.continuous(
        pattern: SineWave(frequency: 2.0),
        intensity: (distance) => 1.0 - (distance / snapRadius),
      ),
      audio: ProximityTone(
        baseFrequency: 440,
        modulation: (distance) => 440 + (100 * (1 - distance / snapRadius)),
      ),
      visual: MagneticFieldLines(
        density: (distance) => 5 + (10 * (1 - distance / snapRadius)),
      ),
    ),
    FeedbackEvent.successfulSnap: FeedbackPattern(
      haptic: HapticFeedback.compound([
        HapticFeedback.mediumImpact(),
        HapticFeedback.delay(50),
        HapticFeedback.lightImpact(),
      ]),
      audio: SoundEffect('snap.wav', volume: 0.5),
      visual: ParticleBurst(
        particleCount: 20,
        colors: [Colors.green, Colors.yellow],
      ),
    ),
  };
  
  // Orchestrated feedback
  void provideFeedback(FeedbackEvent event, FeedbackContext context) {
    final pattern = patterns[event];
    if (pattern == null) return;
    
    // Apply pattern with context
    haptic.play(pattern.haptic, context);
    audio.play(pattern.audio, context);
    visual.play(pattern.visual, context);
    
    // Record for analytics
    _analytics.recordFeedback(event, context);
  }
}
```

### 2.4 Animation Orchestration System

```dart
/// Coordinates all animations in the game
class AnimationOrchestrator {
  // Animation controllers pool
  final Pool<AnimationController> _controllerPool;
  
  // Active animations
  final Map<String, ActiveAnimation> _activeAnimations = {};
  
  // Animation definitions
  final Map<AnimationType, AnimationDefinition> _definitions = {
    AnimationType.piecePickup: AnimationDefinition(
      duration: Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      properties: [
        AnimatedProperty.scale(from: 1.0, to: 1.1),
        AnimatedProperty.elevation(from: 0, to: 8),
      ],
    ),
    AnimationType.magneticSnap: AnimationDefinition(
      duration: Duration(milliseconds: 200),
      curve: SpringCurve(damping: 0.8),
      properties: [
        AnimatedProperty.position(interpolator: MagneticInterpolator()),
        AnimatedProperty.rotation(autoAlign: true),
      ],
    ),
    AnimationType.celebration: AnimationDefinition(
      duration: Duration(milliseconds: 1000),
      curve: Curves.elasticOut,
      properties: [
        AnimatedProperty.scale(
          sequence: [1.0, 1.2, 0.9, 1.1, 1.0],
          times: [0, 0.2, 0.4, 0.6, 1.0],
        ),
        AnimatedProperty.rotation(
          from: 0,
          to: 2 * math.pi,
          wobble: 0.1,
        ),
      ],
    ),
  };
  
  // Start animation
  String startAnimation(
    String targetId,
    AnimationType type,
    Map<String, dynamic> params,
  ) {
    final definition = _definitions[type]!;
    final controller = _controllerPool.acquire();
    
    final animation = ActiveAnimation(
      id: _generateAnimationId(),
      targetId: targetId,
      controller: controller,
      definition: definition,
      startTime: DateTime.now(),
    );
    
    _activeAnimations[animation.id] = animation;
    
    // Setup controller
    controller.duration = definition.duration;
    controller.forward().then((_) {
      _completeAnimation(animation.id);
    });
    
    return animation.id;
  }
  
  // Chain animations
  Future<void> chainAnimations(
    String targetId,
    List<AnimationType> sequence,
  ) async {
    for (final type in sequence) {
      final animId = startAnimation(targetId, type, {});
      await waitForAnimation(animId);
    }
  }
}
```

---

## 3. State Management Architecture

### 3.1 Event-Sourced Game State

```dart
/// Event-sourced state management for perfect replay and undo
class EventSourcedGameState {
  // Event store
  final List<GameEvent> _eventHistory = [];
  
  // Current state (derived from events)
  GameState _currentState;
  
  // State snapshots for performance
  final Map<int, GameState> _snapshots = {};
  static const int snapshotInterval = 50;
  
  // Apply event to state
  GameState applyEvent(GameEvent event) {
    // Store event
    _eventHistory.add(event);
    
    // Apply to current state
    _currentState = event.apply(_currentState);
    
    // Create snapshot if needed
    if (_eventHistory.length % snapshotInterval == 0) {
      _snapshots[_eventHistory.length] = _currentState.clone();
    }
    
    // Publish state change
    _stateStream.add(_currentState);
    
    return _currentState;
  }
  
  // Time travel
  GameState replayToEvent(int eventIndex) {
    // Find nearest snapshot
    final snapshotIndex = (eventIndex ~/ snapshotInterval) * snapshotInterval;
    final snapshot = _snapshots[snapshotIndex] ?? GameState.initial();
    
    // Replay events from snapshot
    var state = snapshot;
    for (int i = snapshotIndex; i < eventIndex; i++) {
      state = _eventHistory[i].apply(state);
    }
    
    return state;
  }
  
  // Undo/Redo
  void undo() {
    if (_eventHistory.isEmpty) return;
    
    final lastEvent = _eventHistory.removeLast();
    _redoStack.add(lastEvent);
    
    // Rebuild state
    _currentState = replayToEvent(_eventHistory.length);
  }
}
```

### 3.2 Piece State Management

```dart
/// Individual piece state management with magnetic field influence
class PieceStateManager {
  // Piece states
  final Map<String, PieceState> _pieceStates = {};
  
  // Magnetic field influences
  final Map<String, MagneticInfluence> _magneticInfluences = {};
  
  // State update
  void updatePieceState(String pieceId, StateUpdate update) {
    final currentState = _pieceStates[pieceId] ?? PieceState.initial();
    
    // Apply magnetic influence
    final magneticInfluence = _magneticInfluences[pieceId];
    final adjustedUpdate = magneticInfluence != null
      ? _applyMagneticInfluence(update, magneticInfluence)
      : update;
    
    // Update state
    final newState = currentState.apply(adjustedUpdate);
    _pieceStates[pieceId] = newState;
    
    // Check for state-based triggers
    _checkTriggers(pieceId, newState);
  }
  
  StateUpdate _applyMagneticInfluence(
    StateUpdate update,
    MagneticInfluence influence,
  ) {
    return StateUpdate(
      position: update.position != null
        ? _magnetizePosition(update.position!, influence)
        : null,
      rotation: update.rotation != null
        ? _magnetizeRotation(update.rotation!, influence)
        : null,
      scale: update.scale,
      metadata: update.metadata,
    );
  }
  
  Offset _magnetizePosition(Offset position, MagneticInfluence influence) {
    // Calculate magnetic attraction
    final attraction = influence.getAttractionVector(position);
    
    // Blend with user input (more influence when closer to target)
    final blendFactor = influence.strength.clamp(0.0, 0.5);
    return position + (attraction * blendFactor);
  }
}
```

### 3.3 Undo/Redo System

```dart
/// Complete undo/redo system with event replay
class UndoRedoSystem {
  // Command pattern for actions
  abstract class Command {
    void execute(GameState state);
    void undo(GameState state);
    String get description;
  }
  
  // Command history
  final List<Command> _history = [];
  int _currentIndex = -1;
  
  // Execute command
  void execute(Command command) {
    // Remove any commands after current index (branching)
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    
    // Add and execute
    _history.add(command);
    _currentIndex++;
    command.execute(_gameState);
    
    // Update UI
    _notifyListeners();
  }
  
  // Undo
  bool undo() {
    if (!canUndo) return false;
    
    final command = _history[_currentIndex];
    command.undo(_gameState);
    _currentIndex--;
    
    _notifyListeners();
    return true;
  }
  
  // Redo
  bool redo() {
    if (!canRedo) return false;
    
    _currentIndex++;
    final command = _history[_currentIndex];
    command.execute(_gameState);
    
    _notifyListeners();
    return true;
  }
  
  // Multi-level undo
  void undoMultiple(int steps) {
    for (int i = 0; i < steps && canUndo; i++) {
      undo();
    }
  }
  
  bool get canUndo => _currentIndex >= 0;
  bool get canRedo => _currentIndex < _history.length - 1;
}
```

### 3.4 Persistence Layer

```dart
/// Persistence layer for save/load functionality
class PersistenceLayer {
  // Save strategies
  abstract class SaveStrategy {
    Future<void> save(GameState state);
    Future<GameState?> load(String id);
  }
  
  // Event-based persistence
  class EventPersistence implements SaveStrategy {
    @override
    Future<void> save(GameState state) async {
      final events = state.eventHistory;
      final compressed = _compressEvents(events);
      
      await _storage.write('events_${state.id}', compressed);
      
      // Also save snapshot for quick load
      await _storage.write('snapshot_${state.id}', state.toJson());
    }
    
    @override
    Future<GameState?> load(String id) async {
      try {
        // Try to load snapshot first
        final snapshot = await _storage.read('snapshot_$id');
        if (snapshot != null) {
          return GameState.fromJson(snapshot);
        }
        
        // Fallback to event replay
        final events = await _storage.read('events_$id');
        if (events != null) {
          return _replayEvents(_decompressEvents(events));
        }
      } catch (e) {
        print('Failed to load game state: $e');
      }
      
      return null;
    }
  }
  
  // Auto-save functionality
  class AutoSave {
    Timer? _timer;
    final Duration interval;
    
    void start() {
      _timer?.cancel();
      _timer = Timer.periodic(interval, (_) {
        _performAutoSave();
      });
    }
    
    void _performAutoSave() async {
      final state = _gameState.current;
      await _persistence.save(state);
      
      // Keep only last N auto-saves
      await _cleanupOldSaves();
    }
  }
}
```

---

## 4. Component Specifications

### 4.1 Magnetic Field System (Port)

```dart
/// Port: Magnetic field calculations
abstract class MagneticFieldSystem {
  /// Calculate field strength at a position
  double getFieldStrength(Offset position);
  
  /// Get field direction vector at a position
  Vector2 getFieldDirection(Offset position);
  
  /// Get all field sources affecting a position
  List<FieldSource> getFieldSources(Offset position);
  
  /// Update field source
  void updateFieldSource(String sourceId, FieldSource source);
  
  /// Calculate magnetic influence on a piece
  MagneticInfluence calculateInfluence(PieceState piece);
}

/// Implementation (Adapter)
class ForgesMagneticFieldAdapter implements MagneticFieldSystem {
  final Forge2DWorld _physicsWorld;
  final Map<String, MagneticBody> _magneticBodies = {};
  
  @override
  double getFieldStrength(Offset position) {
    double totalStrength = 0.0;
    
    for (final body in _magneticBodies.values) {
      final distance = (body.position - position).distance;
      if (distance < body.fieldRadius) {
        // Inverse square law with cutoff
        final strength = body.strength / (1 + distance * distance);
        totalStrength += strength;
      }
    }
    
    return totalStrength.clamp(0.0, 1.0);
  }
  
  @override
  Vector2 getFieldDirection(Offset position) {
    Vector2 totalDirection = Vector2.zero();
    
    for (final body in _magneticBodies.values) {
      final distance = (body.position - position).distance;
      if (distance < body.fieldRadius) {
        final direction = (body.position - position).normalized();
        final strength = body.strength / (1 + distance * distance);
        totalDirection += direction * strength;
      }
    }
    
    return totalDirection.normalized();
  }
}
```

### 4.2 Neural Suggestion Engine (Port)

```dart
/// Port: AI-powered piece suggestions
abstract class NeuralSuggestionEngine {
  /// Get suggested pieces based on current state
  Future<List<SuggestedPiece>> getSuggestions(GameState state);
  
  /// Update model with user action
  void recordAction(UserAction action);
  
  /// Train model with session data
  Future<void> trainModel(SessionData data);
  
  /// Get confidence score for a potential move
  double getMoveConfidence(PieceMove move);
}

/// Implementation (Adapter)
class TensorFlowLiteSuggestionAdapter implements NeuralSuggestionEngine {
  late Interpreter _interpreter;
  final List<UserAction> _actionHistory = [];
  
  @override
  Future<List<SuggestedPiece>> getSuggestions(GameState state) async {
    // Prepare input tensor
    final input = _prepareInput(state);
    
    // Run inference
    final output = List.filled(10 * 4, 0.0).reshape([10, 4]);
    _interpreter.run(input, output);
    
    // Parse output
    return _parseOutput(output, state);
  }
  
  List<double> _prepareInput(GameState state) {
    // Feature extraction
    return [
      // Spatial features
      ...state.getPieceDensityMap(),
      // Temporal features
      state.timeSinceLastPlacement.inSeconds.toDouble(),
      state.averagePlacementTime.inSeconds.toDouble(),
      // User pattern features
      ..._extractUserPatterns(),
    ];
  }
}
```

### 4.3 Particle Effects System (Port)

```dart
/// Port: Particle effects and celebrations
abstract class ParticleEffectsSystem {
  /// Trigger a particle effect
  void trigger(ParticleEffect effect, Offset position);
  
  /// Create continuous effect
  String startContinuousEffect(
    ParticleEffect effect,
    Offset position,
  );
  
  /// Stop continuous effect
  void stopEffect(String effectId);
  
  /// Update all active effects
  void update(double dt);
}

/// Implementation using Flame
class FlameParticleAdapter implements ParticleEffectsSystem {
  final FlameGame _game;
  final Map<String, Component> _activeEffects = {};
  
  @override
  void trigger(ParticleEffect effect, Offset position) {
    final component = _createParticleComponent(effect, position);
    _game.add(component);
    
    // Auto-remove after duration
    Future.delayed(effect.duration, () {
      component.removeFromParent();
    });
  }
  
  Component _createParticleComponent(
    ParticleEffect effect,
    Offset position,
  ) {
    switch (effect.type) {
      case EffectType.burst:
        return ParticleBurst(
          position: position.toVector2(),
          particleCount: effect.particleCount,
          colors: effect.colors,
          speed: effect.speed,
        );
      case EffectType.fountain:
        return ParticleFountain(
          position: position.toVector2(),
          rate: effect.rate,
          angle: effect.angle,
        );
      case EffectType.fieldLines:
        return MagneticFieldLines(
          center: position.toVector2(),
          strength: effect.strength,
          density: effect.density,
        );
    }
  }
}
```

### 4.4 Audio System (Port)

```dart
/// Port: Spatial audio and musical feedback
abstract class AudioSystem {
  /// Play a sound effect
  void playSound(String soundId, {double volume = 1.0});
  
  /// Play spatial audio
  void playSpatial(
    String soundId,
    Offset position,
    Offset listenerPosition,
  );
  
  /// Start musical sequence
  void startSequence(MusicalSequence sequence);
  
  /// Modulate ongoing audio
  void modulateAudio(String audioId, AudioModulation modulation);
}

/// Implementation
class AudioPoolAdapter implements AudioSystem {
  final AudioPool _pool;
  final Map<String, AudioSource> _sources = {};
  
  @override
  void playSpatial(
    String soundId,
    Offset position,
    Offset listenerPosition,
  ) {
    final distance = (position - listenerPosition).distance;
    final pan = _calculatePan(position, listenerPosition);
    final volume = _calculateVolume(distance);
    
    _pool.play(
      soundId,
      volume: volume,
      pan: pan,
    );
  }
  
  double _calculatePan(Offset source, Offset listener) {
    final delta = source - listener;
    return (delta.dx / 1000).clamp(-1.0, 1.0);
  }
  
  double _calculateVolume(double distance) {
    const maxDistance = 500.0;
    return (1.0 - (distance / maxDistance)).clamp(0.0, 1.0);
  }
}
```

---

## Testing Strategy

### Unit Tests
- Coordinate system transformations
- Magnetic field calculations
- State machine transitions
- Event sourcing and replay
- Undo/redo operations

### Widget Tests
- Piece interaction workflows
- Gesture recognition
- Animation sequences
- Feedback triggering

### Integration Tests
- Full puzzle solving flow
- Save/load functionality
- Multi-layer rendering
- Performance under load

### Performance Tests
- Frame rate monitoring
- Memory allocation tracking
- Battery usage measurement
- Gesture latency testing

---

## Architecture Diagrams

### System Overview
```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Widgets │  │ Painters │  │  Flame   │  │  Gestures│  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Controllers │  │   Use Cases  │  │  Orchestrator│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                       Domain Layer                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Entities │  │  Value   │  │  Domain  │  │   Ports  │  │
│  │          │  │ Objects  │  │ Services │  │          │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Magnetic │  │  Neural  │  │ Particle │  │   Audio  │  │
│  │  Field   │  │    AI    │  │  Effects │  │  System  │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow
```
User Input → Gesture Recognition → Magnetic Adjustment →
State Machine → Event Store → State Update →
Rendering Pipeline → Visual/Audio/Haptic Feedback → User
```

---

This architecture provides a solid foundation for implementing the innovative features outlined in the vision documents while maintaining clean separation of concerns and excellent performance.
