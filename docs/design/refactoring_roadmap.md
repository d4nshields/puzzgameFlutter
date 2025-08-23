# Puzzle Nook - Refactoring Roadmap
## Safe, Incremental Implementation Plan

**Document Version:** 1.0  
**Date:** August 22, 2025  
**Timeline:** 4 Weeks

---

## Phase A: Foundation (Week 1)

### Step A1: Create Coordinate System Abstraction
**Duration:** 1 day

#### Files to Create:
- `/lib/game_module2/domain/services/coordinate_system.dart`
- `/lib/game_module2/domain/value_objects/coordinate_spaces.dart`
- `/test/game_module2/domain/services/coordinate_system_test.dart`

#### Implementation:
```dart
// coordinate_spaces.dart
class ScreenSpace {
  final Size screenSize;
  Offset toNormalized(Offset screenPoint) => 
    Offset(screenPoint.dx / screenSize.width, 
           screenPoint.dy / screenSize.height);
}

class CanvasSpace {
  final Size canvasSize;
  final double scale;
}

class GridSpace {
  final int rows;
  final int columns;
  final Size cellSize;
}

// coordinate_system.dart
class UnifiedCoordinateSystem {
  Matrix4 screenToCanvas;
  Matrix4 canvasToGrid;
  Matrix4 gridToWorkspace;
  
  Offset transformPoint(Offset point, CoordinateSpace from, CoordinateSpace to);
  Rect transformRect(Rect rect, CoordinateSpace from, CoordinateSpace to);
}
```

#### Testing Requirements:
- Unit tests for all transformation methods
- Property-based tests for inverse transformations
- Edge case handling (boundaries, negative coordinates)

#### Success Criteria:
- All coordinate transformations are bidirectional
- No precision loss in round-trip transformations
- Performance: < 0.1ms per transformation

#### Rollback Plan:
- Keep old coordinate calculations in parallel
- Feature flag: `useUnifiedCoordinates`

---

### Step A2: Implement Transformation Utilities
**Duration:** 1 day

#### Files to Create:
- `/lib/game_module2/domain/services/transformation_manager.dart`
- `/lib/game_module2/infrastructure/rendering/transform_cache.dart`

#### Implementation:
```dart
class TransformationManager {
  final TransformCache _cache;
  
  Matrix4 computePieceTransform(String pieceId) {
    return _cache.getOrCompute(pieceId, () => 
      _viewport * _piece * _magnetic * _animation
    );
  }
  
  void invalidateTransform(String pieceId) {
    _cache.invalidate(pieceId);
    _notifyListeners(pieceId);
  }
}
```

#### Testing Requirements:
- Cache hit/miss ratio monitoring
- Performance benchmarks
- Concurrent access testing

#### Success Criteria:
- 90%+ cache hit rate during normal gameplay
- Transform computation < 0.5ms

---

### Step A3: Build Rendering Pipeline Foundation
**Duration:** 2 days

#### Files to Create:
- `/lib/game_module2/presentation/rendering/hybrid_renderer.dart`
- `/lib/game_module2/presentation/rendering/static_layer.dart`
- `/lib/game_module2/presentation/rendering/dynamic_layer.dart`
- `/lib/game_module2/presentation/rendering/effects_layer.dart`

#### Implementation:
```dart
class HybridRenderer extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          child: StaticLayer(
            grid: gameState.grid,
            completedSections: gameState.completedSections,
          ),
        ),
        DynamicLayer(
          pieces: gameState.activePieces,
          transforms: transformationManager.transforms,
        ),
        if (effectsEnabled)
          EffectsLayer(
            effects: gameState.activeEffects,
          ),
      ],
    );
  }
}
```

#### Testing Requirements:
- Widget tests for each layer
- Performance profiling with DevTools
- Memory leak detection

#### Success Criteria:
- 60 FPS with 100+ pieces
- Memory usage < 200MB
- No unnecessary repaints

---

### Step A4: Write Comprehensive Tests
**Duration:** 1 day

#### Files to Create:
- `/test/game_module2/integration/rendering_pipeline_test.dart`
- `/test/game_module2/performance/frame_rate_test.dart`
- `/test/game_module2/golden/visual_regression_test.dart`

#### Implementation:
```dart
// Performance test example with FrameTimingRecorder implementation

// First, add this helper class for recording frame timings
class FrameTimingRecorder {
  final List<FrameTiming> _timings = [];
  
  void record(List<FrameTiming> timings) {
    _timings.addAll(timings);
  }
  
  int get droppedFrames {
    int dropped = 0;
    for (final timing in _timings) {
      // A frame is considered dropped if it took longer than 16.67ms (60 FPS)
      final frameDuration = timing.totalSpan.inMicroseconds;
      if (frameDuration > 16667) {
        dropped++;
      }
    }
    return dropped;
  }
  
  double get averageFps {
    if (_timings.isEmpty) return 0;
    
    double totalFps = 0;
    for (final timing in _timings) {
      final frameDuration = timing.totalSpan.inMicroseconds;
      if (frameDuration > 0) {
        // Convert microseconds to FPS (1,000,000 microseconds = 1 second)
        totalFps += 1000000.0 / frameDuration;
      }
    }
    return totalFps / _timings.length;
  }
  
  void clear() {
    _timings.clear();
  }
}

// Test implementation using the recorder
testWidgets('maintains 60fps during drag', (tester) async {
  final controller = GameController();
  await tester.pumpWidget(GameWidget(controller: controller));
  
  // Set up frame timing recording
  final recorder = FrameTimingRecorder();
  SchedulerBinding.instance.addTimingsCallback(recorder.record);
  
  try {
    // Simulate drag operation
    await tester.drag(find.byType(PuzzlePiece), const Offset(100, 100));
    await tester.pumpAndSettle();
    
    // Verify performance metrics
    expect(recorder.droppedFrames, equals(0),
        reason: 'Should have no dropped frames during drag');
    expect(recorder.averageFps, greaterThan(59),
        reason: 'Should maintain at least 59 FPS');
  } finally {
    // Clean up: remove the timing callback
    SchedulerBinding.instance.removeTimingsCallback(recorder.record);
  }
});
```

---

## Phase B: Interaction Layer (Week 2)

### Step B1: Implement Gesture Detection System
**Duration:** 1.5 days

#### Files to Create:
- `/lib/game_module2/presentation/gestures/magnetic_gesture_recognizer.dart`
- `/lib/game_module2/presentation/gestures/gesture_coordinator.dart`

#### Implementation:
```dart
class MagneticGestureRecognizer extends OneSequenceGestureRecognizer {
  double magneticInfluence = 0.0;
  
  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      final adjustedDelta = applyMagneticAssistance(
        event.delta,
        magneticInfluence,
      );
      onUpdate?.call(adjustedDelta);
    }
  }
}
```

#### Testing Requirements:
- Gesture recognition accuracy tests
- Multi-touch handling
- Gesture conflict resolution

---

### Step B2: Create Piece State Machine
**Duration:** 1 day

#### Files to Create:
- `/lib/game_module2/domain/services/piece_state_machine.dart`
- `/lib/game_module2/domain/value_objects/piece_states.dart`

#### Implementation:
```dart
class PieceStateMachine {
  final Map<PieceState, Map<Event, PieceState>> transitions = {
    PieceState.idle: {
      Event.pickup: PieceState.dragging,
      Event.hover: PieceState.hovering,
    },
    // ... more transitions
  };
  
  void transition(String pieceId, Event event) {
    final current = states[pieceId];
    final next = transitions[current]?[event];
    if (next != null) {
      exitState(pieceId, current);
      enterState(pieceId, next);
      states[pieceId] = next;
    }
  }
}
```

---

### Step B3: Build Feedback Controller
**Duration:** 1.5 days

#### Files to Create:
- `/lib/game_module2/application/feedback_controller.dart`
- `/lib/game_module2/infrastructure/haptic_adapter.dart`
- `/lib/game_module2/infrastructure/audio_adapter.dart`

#### Implementation:
```dart
class FeedbackController {
  void provideFeedback(FeedbackEvent event, Context context) {
    final pattern = patterns[event];
    
    haptic.play(pattern.haptic, context);
    audio.play(pattern.audio, context);
    visual.trigger(pattern.visual, context);
  }
}
```

---

### Step B4: Integrate with Game Session
**Duration:** 1 day

#### Files to Modify:
- `/lib/game_module2/puzzle_game_module2.dart`
- `/lib/game_module2/application/workspace_controller.dart`

#### Integration Points:
- Connect gesture recognizer to state machine
- Wire feedback controller to state transitions
- Update workspace controller with new systems

---

## Phase C: Visual Enhancement (Week 3)

### Step C1: Implement Smooth Animations
**Duration:** 2 days

#### Files to Create:
- `/lib/game_module2/presentation/animations/animation_orchestrator.dart`
- `/lib/game_module2/presentation/animations/spring_physics.dart`
- `/lib/game_module2/presentation/animations/animation_definitions.dart`

#### Implementation:
```dart
class AnimationOrchestrator {
  final Map<AnimationType, AnimationDefinition> definitions;
  final Pool<AnimationController> controllerPool;
  
  String startAnimation(String targetId, AnimationType type) {
    final controller = controllerPool.acquire();
    final animation = createAnimation(type, controller);
    activeAnimations[targetId] = animation;
    return animation.id;
  }
}
```

---

### Step C2: Add Visual Feedback Effects
**Duration:** 1.5 days

#### Files to Create:
- `/lib/game_module2/presentation/effects/particle_system.dart`
- `/lib/game_module2/presentation/effects/glow_effect.dart`
- `/lib/game_module2/presentation/effects/magnetic_field_visualizer.dart`

#### Implementation:
```dart
class ParticleSystem {
  void triggerBurst(Offset position, ParticleBurstConfig config) {
    for (int i = 0; i < config.count; i++) {
      particles.add(Particle(
        position: position,
        velocity: randomVelocity(config.speed),
        color: config.colors.random(),
        lifetime: config.duration,
      ));
    }
  }
}
```

---

### Step C3: Optimize Rendering Performance
**Duration:** 1.5 days

#### Files to Modify:
- `/lib/game_module2/presentation/rendering/hybrid_renderer.dart`
- `/lib/game_module2/presentation/widgets/puzzle_workspace_widget.dart`

#### Optimizations:
- Implement dirty region tracking
- Add picture caching for static elements
- Use compute shaders for effects
- Implement LOD system for pieces

---

### Step C4: Polish and Fine-tune
**Duration:** 1 day

#### Tasks:
- Adjust animation timings
- Fine-tune magnetic field strength
- Calibrate haptic feedback intensity
- Color and visual polish

---

## Phase D: Testing & Polish (Week 4)

### Step D1: Comprehensive Integration Testing
**Duration:** 2 days

#### Test Scenarios:
- Complete puzzle solving flow
- Edge cases and error conditions
- Multi-device testing
- Accessibility testing

---

### Step D2: Performance Profiling
**Duration:** 1 day

#### Metrics to Measure:
- Frame rate consistency
- Memory allocation patterns
- Battery usage
- Thermal performance

---

### Step D3: Accessibility Testing
**Duration:** 1 day

#### Features to Validate:
- Screen reader support
- Keyboard navigation
- High contrast mode
- Reduced motion mode

---

### Step D4: Bug Fixes and Refinement
**Duration:** 1 day

#### Priority Order:
1. Crashes and data loss
2. Performance issues
3. Visual glitches
4. Minor UX issues

---

## Risk Mitigation Strategies

### Feature Flags
```dart
class FeatureFlags {
  static const bool useNewRenderer = true;
  static const bool enableMagneticField = true;
  static const bool useNeuralSuggestions = false;
  static const bool enableParticleEffects = true;
}
```

### Gradual Rollout
1. Internal testing with team
2. Beta testing with 10% of users
3. A/B testing of individual features
4. Full rollout with monitoring

### Compatibility Layers
```dart
class CompatibilityBridge {
  // Adapter to work with old game session
  PuzzleGameSession2 adaptToLegacy(NewGameState state) {
    // Convert new state to old format
  }
  
  NewGameState adaptFromLegacy(PuzzleGameSession2 session) {
    // Convert old format to new state
  }
}
```

### Performance Monitoring
```dart
class PerformanceMonitor {
  void trackFrameRate() {
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        if (timing.totalSpan.inMilliseconds > 16) {
          analytics.logSlowFrame(timing);
        }
      }
    });
  }
}
```

---

## Documentation Requirements

### Architecture Decision Records (ADRs)
- ADR-001: Hybrid Rendering Architecture
- ADR-002: Event Sourcing for State Management
- ADR-003: Magnetic Field Interaction Model
- ADR-004: Coordinate System Design

### API Documentation
- Complete dartdoc for all public APIs
- Usage examples for each component
- Migration guide from old to new system

### Performance Benchmarks
- Baseline measurements before refactoring
- Target metrics for each phase
- Final performance report

---

## Success Metrics

### Technical Metrics
- ✅ 60 FPS on devices from 2020+
- ✅ Memory usage < 500MB
- ✅ Battery drain < 5% per hour
- ✅ Load time < 2 seconds

### Quality Metrics
- ✅ Test coverage > 80%
- ✅ Zero critical bugs
- ✅ Crash rate < 0.1%

### User Experience Metrics
- ✅ Touch latency < 20ms
- ✅ Smooth animations (no jank)
- ✅ Intuitive interactions
- ✅ Accessibility compliance

---

## Team Assignments

### Week 1: Foundation
- **Lead Developer**: Coordinate system and transformations
- **Senior Developer**: Rendering pipeline
- **QA Engineer**: Test framework setup

### Week 2: Interaction
- **Lead Developer**: State machine and gestures
- **Senior Developer**: Feedback systems
- **QA Engineer**: Integration testing

### Week 3: Visual Enhancement
- **Lead Developer**: Animation system
- **Senior Developer**: Particle effects
- **Designer**: Visual polish
- **QA Engineer**: Performance testing

### Week 4: Polish
- **Entire Team**: Bug fixes and optimization
- **QA Engineer**: Final validation
- **Product Owner**: Sign-off

---

This roadmap provides a safe, incremental path to implementing the new architecture while maintaining the ability to rollback at any point. Each phase builds on the previous one, and feature flags allow for gradual rollout and A/B testing.
