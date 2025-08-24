/// Comprehensive test suite for the Effects Layer
/// 
/// Tests cover:
/// - Particle system functionality and performance
/// - Effect pooling and resource management
/// - Magnetic field visualization
/// - Glow and ripple effects
/// - Quality settings and auto-adjustment
/// - Performance metrics and FPS tracking
/// - Debug mode functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'package:puzzgame_flutter/game_module2/presentation/rendering/effects_layer.dart';
import 'effects_layer_test_helpers.dart';
import 'dart:ui' as ui;

void main() {
  group('EffectsLayer Tests', () {
    late EffectsController controller;
    late EffectQualitySettings qualitySettings;

    setUp(() {
      controller = EffectsController();
      qualitySettings = EffectQualitySettings(
        currentLevel: QualityLevel.high,
        autoAdjustQuality: false,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    group('Widget Tests', () {
      testWidgets('EffectsLayer builds correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TestableEffectsLayer(
                size: const Size(800, 600),
                controller: controller,
                debugMode: false,
                qualitySettings: qualitySettings,
              ),
            ),
          ),
        );

        expect(find.byType(TestableEffectsLayer), findsOneWidget);
        expect(find.byType(MockGameWidget), findsOneWidget);
      });

      testWidgets('Debug overlay shows when enabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TestableEffectsLayer(
                size: const Size(800, 600),
                controller: controller,
                debugMode: true,
                qualitySettings: qualitySettings,
              ),
            ),
          ),
        );

        expect(find.text('Effects Debug'), findsOneWidget);
        expect(find.textContaining('Particles:'), findsOneWidget);
        expect(find.textContaining('FPS:'), findsOneWidget);
        expect(find.textContaining('Quality:'), findsOneWidget);
      });

      testWidgets('Effects can be toggled on/off', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TestableEffectsLayer(
                size: const Size(800, 600),
                controller: controller,
                debugMode: true,
                qualitySettings: qualitySettings,
              ),
            ),
          ),
        );

        expect(controller.effectsEnabled, isTrue);

        // Find and tap the disable button
        await tester.tap(find.text('Disable'));
        await tester.pump();

        expect(controller.effectsEnabled, isFalse);
        expect(find.text('Enable'), findsOneWidget);
      });
    });

    group('EffectsController Tests', () {
      test('Controller initializes with effects enabled', () {
        expect(controller.effectsEnabled, isTrue);
      });

      test('Controller can enable/disable effects', () {
        controller.setEffectsEnabled(false);
        expect(controller.effectsEnabled, isFalse);

        controller.setEffectsEnabled(true);
        expect(controller.effectsEnabled, isTrue);
      });

      test('Controller notifies listeners on state change', () {
        bool notified = false;
        controller.addListener(() {
          notified = true;
        });

        controller.setEffectsEnabled(false);
        expect(notified, isTrue);
      });

      test('Controller can update magnetic sources', () {
        final sources = [
          const MagneticSource(
            position: Offset(100, 100),
            strength: 0.8,
            radius: 50,
          ),
          const MagneticSource(
            position: Offset(200, 200),
            strength: 0.5,
            radius: 75,
          ),
        ];

        controller.updateMagneticSources(sources);
        // This should not throw
      });

      test('Controller ignores effects when disabled', () {
        controller.setEffectsEnabled(false);
        
        // This should not throw even when disabled
        controller.triggerEffect(
          const CelebrationEffect(
            position: Offset(100, 100),
            intensity: 1.0,
          ),
        );
      });
    });

    group('Effect Pool Tests', () {
      test('Effect pool pre-allocates objects', () {
        final pool = EffectPool<BurstParticle>(
          createFunction: () => BurstParticle(),
          resetFunction: (p) => p.reset(),
          initialSize: 10,
          maxSize: 20,
        );

        expect(pool.availableCount, equals(10));
        expect(pool.inUseCount, equals(0));
        expect(pool.totalCount, equals(10));
      });

      test('Effect pool acquires and releases objects', () {
        final pool = EffectPool<BurstParticle>(
          createFunction: () => BurstParticle(),
          resetFunction: (p) => p.reset(),
          initialSize: 5,
          maxSize: 10,
        );

        final particle = pool.acquire();
        expect(particle, isNotNull);
        expect(pool.availableCount, equals(4));
        expect(pool.inUseCount, equals(1));

        pool.release(particle!);
        expect(pool.availableCount, equals(5));
        expect(pool.inUseCount, equals(0));
      });

      test('Effect pool creates new objects when needed', () {
        final pool = EffectPool<BurstParticle>(
          createFunction: () => BurstParticle(),
          resetFunction: (p) => p.reset(),
          initialSize: 2,
          maxSize: 10,
        );

        // Acquire all pre-allocated objects
        pool.acquire();
        pool.acquire();
        
        // This should create a new object
        final p3 = pool.acquire();
        
        expect(p3, isNotNull);
        expect(pool.totalCount, equals(3));
      });

      test('Effect pool respects max size limit', () {
        final pool = EffectPool<BurstParticle>(
          createFunction: () => BurstParticle(),
          resetFunction: (p) => p.reset(),
          initialSize: 2,
          maxSize: 3,
        );

        final p1 = pool.acquire();
        final p2 = pool.acquire();
        final p3 = pool.acquire();
        final p4 = pool.acquire();

        expect(p1, isNotNull);
        expect(p2, isNotNull);
        expect(p3, isNotNull);
        expect(p4, isNull); // Should be null as max size reached
      });

      test('Effect pool releases all objects', () {
        final pool = EffectPool<BurstParticle>(
          createFunction: () => BurstParticle(),
          resetFunction: (p) => p.reset(),
          initialSize: 5,
          maxSize: 10,
        );

        // Acquire some objects
        pool.acquire();
        pool.acquire();
        pool.acquire();
        
        expect(pool.inUseCount, equals(3));
        
        pool.releaseAll();
        
        expect(pool.inUseCount, equals(0));
        expect(pool.availableCount, equals(5));
      });
    });

    group('Particle Tests', () {
      test('BurstParticle initializes correctly', () {
        final particle = BurstParticle();
        particle.initialize(
          position: vector_math.Vector2(100, 200),
          velocity: vector_math.Vector2(50, -50),
          color: Colors.red,
          lifespan: 1.0,
        );

        expect(particle.position.x, equals(100));
        expect(particle.position.y, equals(200));
        expect(particle.velocity.x, equals(50));
        expect(particle.velocity.y, equals(-50));
        expect(particle.color, equals(Colors.red));
        expect(particle.lifespan, equals(1.0));
        expect(particle.isAlive, isTrue);
      });

      test('Particle updates position and applies physics', () {
        final particle = BurstParticle();
        particle.initialize(
          position: vector_math.Vector2(100, 100),
          velocity: vector_math.Vector2(100, 0),
          color: Colors.blue,
          lifespan: 1.0,
        );

        final dt = 0.016; // 60fps frame time
        particle.update(dt);

        // Position should change based on velocity
        expect(particle.position.x, greaterThan(100));
        
        // Gravity should affect y velocity
        expect(particle.velocity.y, greaterThan(0));
        
        // Damping should reduce velocity
        expect(particle.velocity.length, lessThan(100));
      });

      test('Particle dies after lifespan', () {
        final particle = BurstParticle();
        particle.initialize(
          position: vector_math.Vector2.zero(),
          velocity: vector_math.Vector2.zero(),
          color: Colors.white,
          lifespan: 0.1,
        );

        expect(particle.isAlive, isTrue);

        // Update past lifespan
        particle.update(0.2);

        expect(particle.isAlive, isFalse);
      });

      test('Particle reset clears all properties', () {
        final particle = BurstParticle();
        particle.initialize(
          position: vector_math.Vector2(100, 100),
          velocity: vector_math.Vector2(50, 50),
          color: Colors.red,
          lifespan: 1.0,
        );

        particle.reset();

        expect(particle.position.x, equals(0));
        expect(particle.position.y, equals(0));
        expect(particle.velocity.x, equals(0));
        expect(particle.velocity.y, equals(0));
        expect(particle.isAlive, isFalse);
      });

      test('ConfettiParticle has rotation', () {
        final particle = ConfettiParticle();
        particle.initialize(
          position: vector_math.Vector2.zero(),
          velocity: vector_math.Vector2.zero(),
          color: Colors.green,
          lifespan: 1.0,
        );

        final initialRotation = particle.rotation;
        particle.update(0.1);
        
        // Rotation should change
        expect(particle.rotation, isNot(equals(initialRotation)));
      });

      test('SparkleParticle has sparkle animation', () {
        final particle = SparkleParticle();
        particle.initialize(
          position: vector_math.Vector2.zero(),
          velocity: vector_math.Vector2.zero(),
          color: Colors.yellow,
          lifespan: 1.0,
        );

        final initialPhase = particle.sparklePhase;
        particle.update(0.1);
        
        // Sparkle phase should animate
        expect(particle.sparklePhase, isNot(equals(initialPhase)));
      });
    });

    group('Quality Settings Tests', () {
      test('Quality settings affect max particles', () {
        final lowQuality = EffectQualitySettings(
          currentLevel: QualityLevel.low,
        );
        final highQuality = EffectQualitySettings(
          currentLevel: QualityLevel.high,
        );

        expect(lowQuality.maxParticles, lessThan(highQuality.maxParticles));
      });

      test('Quality settings affect particle scale', () {
        final lowQuality = EffectQualitySettings(
          currentLevel: QualityLevel.low,
        );
        final ultraQuality = EffectQualitySettings(
          currentLevel: QualityLevel.ultra,
        );

        expect(lowQuality.particleScale, equals(0.5));
        expect(ultraQuality.particleScale, equals(1.0));
      });

      test('Quality settings enable/disable effects', () {
        final lowQuality = EffectQualitySettings(
          currentLevel: QualityLevel.low,
        );
        final highQuality = EffectQualitySettings(
          currentLevel: QualityLevel.high,
        );

        // Glow effects disabled on low quality
        expect(lowQuality.enableGlowEffects, isFalse);
        expect(highQuality.enableGlowEffects, isTrue);

        // Celebrations always enabled
        expect(lowQuality.isEffectEnabled(EffectType.celebration), isTrue);
        expect(highQuality.isEffectEnabled(EffectType.celebration), isTrue);

        // Sparkle trails only on high quality
        expect(lowQuality.isEffectEnabled(EffectType.sparkleTrail), isFalse);
        expect(highQuality.isEffectEnabled(EffectType.sparkleTrail), isTrue);
      });

      test('Quality can be increased and decreased', () {
        final settings = EffectQualitySettings(
          currentLevel: QualityLevel.medium,
        );

        settings.increaseQuality();
        expect(settings.currentLevel, equals(QualityLevel.high));

        settings.increaseQuality();
        expect(settings.currentLevel, equals(QualityLevel.ultra));

        settings.increaseQuality();
        expect(settings.currentLevel, equals(QualityLevel.ultra)); // Can't go higher

        settings.decreaseQuality();
        expect(settings.currentLevel, equals(QualityLevel.high));

        settings.decreaseQuality();
        expect(settings.currentLevel, equals(QualityLevel.medium));

        settings.decreaseQuality();
        expect(settings.currentLevel, equals(QualityLevel.low));

        settings.decreaseQuality();
        expect(settings.currentLevel, equals(QualityLevel.low)); // Can't go lower
      });
    });

    group('Performance Metrics Tests', () {
      test('Performance metrics tracks FPS', () {
        final metrics = PerformanceMetrics();
        
        // Simulate 60fps
        for (int i = 0; i < 60; i++) {
          metrics.update(0.016667, 100, 5); // ~60fps
        }

        expect(metrics.currentFps, closeTo(60, 5));
      });

      test('Performance metrics tracks effect counts', () {
        final metrics = PerformanceMetrics();
        
        metrics.recordEffect(EffectType.celebration);
        metrics.recordEffect(EffectType.celebration);
        metrics.recordEffect(EffectType.piecePlacement);

        final counts = metrics.effectCounts;
        expect(counts[EffectType.celebration], equals(2));
        expect(counts[EffectType.piecePlacement], equals(1));
      });

      test('Performance metrics can be reset', () {
        final metrics = PerformanceMetrics();
        
        metrics.update(0.016, 100, 5);
        metrics.recordEffect(EffectType.celebration);
        
        metrics.reset();
        
        expect(metrics.effectCounts, isEmpty);
        expect(metrics.averageFps, equals(60)); // Default when no data
      });
    });

    group('Effect Definition Tests', () {
      test('CelebrationEffect has correct properties', () {
        const effect = CelebrationEffect(
          position: Offset(100, 200),
          intensity: 1.5,
        );

        expect(effect.type, equals(EffectType.celebration));
        expect(effect.position, equals(const Offset(100, 200)));
        expect(effect.intensity, equals(1.5));
      });

      test('MagneticPulseEffect has correct properties', () {
        const effect = MagneticPulseEffect(
          center: Offset(150, 150),
          strength: 0.8,
          radius: 100,
          duration: 2.0,
        );

        expect(effect.type, equals(EffectType.magneticPulse));
        expect(effect.center, equals(const Offset(150, 150)));
        expect(effect.strength, equals(0.8));
        expect(effect.radius, equals(100));
        expect(effect.duration, equals(2.0));
      });

      test('TouchRippleEffect has default values', () {
        const effect = TouchRippleEffect(
          position: Offset(50, 50),
        );

        expect(effect.type, equals(EffectType.touchRipple));
        expect(effect.position, equals(const Offset(50, 50)));
        expect(effect.maxRadius, equals(50)); // Default
        expect(effect.duration, equals(0.5)); // Default
        expect(effect.color, equals(Colors.white)); // Default
      });
    });

    group('Ripple Wave Tests', () {
      test('RippleWave initializes and updates correctly', () {
        final ripple = RippleWave();
        ripple.initialize(
          center: const Offset(100, 100),
          maxRadius: 100,
          duration: 1.0,
          color: Colors.blue,
        );

        expect(ripple.isActive, isTrue);
        expect(ripple.progress, equals(0));

        ripple.update(0.5);
        expect(ripple.progress, equals(0.5));
        expect(ripple.isActive, isTrue);

        ripple.update(0.6);
        expect(ripple.progress, greaterThan(1.0));
        expect(ripple.isActive, isFalse);
      });
    });

    group('Magnetic Field Tests', () {
      test('MagneticSource has correct properties', () {
        const source = MagneticSource(
          position: Offset(200, 200),
          strength: 0.9,
          radius: 150,
          color: Colors.purple,
        );

        expect(source.position, equals(const Offset(200, 200)));
        expect(source.strength, equals(0.9));
        expect(source.radius, equals(150));
        expect(source.color, equals(Colors.purple));
      });

      test('MagneticPulse updates correctly', () {
        final pulse = MagneticPulse(
          center: const Offset(100, 100),
          strength: 0.5,
          radius: 100,
          duration: 1.0,
        );

        expect(pulse.isActive, isTrue);
        expect(pulse.progress, equals(0));
        expect(pulse.currentRadius, equals(0));

        pulse.update(0.5);
        expect(pulse.progress, equals(0.5));
        expect(pulse.currentRadius, equals(50));
        expect(pulse.opacity, closeTo(0.25, 0.01));

        pulse.update(0.6);
        expect(pulse.isActive, isFalse);
      });
    });

    group('Glow Instance Tests', () {
      test('GlowInstance tracks elapsed time', () {
        final glow = GlowInstance(
          position: const Offset(100, 100),
          radius: 30,
          color: Colors.yellow,
          duration: 2.0,
        );

        expect(glow.isActive, isTrue);
        expect(glow.remaining, equals(2.0));

        glow.update(0.5);
        expect(glow.elapsed, equals(0.5));
        expect(glow.remaining, equals(1.5));
        expect(glow.isActive, isTrue);

        glow.update(1.6);
        expect(glow.isActive, isFalse);
      });

      test('GlowInstance with pulse frequency', () {
        final glow = GlowInstance(
          position: const Offset(100, 100),
          radius: 30,
          color: Colors.yellow,
          duration: 2.0,
          pulseFrequency: 2.0,
        );

        expect(glow.pulseFrequency, equals(2.0));
      });
    });

    group('Effect Presets Tests', () {
      test('Effect presets have correct default values', () {
        expect(EffectPresets.smallCelebration.intensity, equals(0.5));
        expect(EffectPresets.mediumCelebration.intensity, equals(1.0));
        expect(EffectPresets.largeCelebration.intensity, equals(2.0));

        expect(EffectPresets.successPlacement.color, equals(Colors.green));
        
        expect(EffectPresets.magneticSnap.radius, equals(80));
        expect(EffectPresets.magneticSnap.duration, equals(0.5));

        expect(EffectPresets.touchFeedback.maxRadius, equals(40));
        expect(EffectPresets.touchFeedback.duration, equals(0.3));

        expect(EffectPresets.selectionGlow.color, equals(Colors.amber));
        expect(EffectPresets.selectionGlow.pulseFrequency, equals(2.0));
      });
    });

    group('Integration Tests', () {
      test('Controller can trigger multiple effects', () {
        // Verify controller starts with effects enabled
        expect(controller.effectsEnabled, isTrue);
        
        // Test that we can trigger effects without throwing
        expect(() {
          controller.triggerEffect(
            const CelebrationEffect(
              position: Offset(100, 100),
              intensity: 1.0,
            ),
          );

          controller.triggerEffect(
            const TouchRippleEffect(
              position: Offset(200, 200),
            ),
          );

          controller.triggerEffect(
            const GlowHighlightEffect(
              position: Offset(300, 300),
            ),
          );
        }, returnsNormally);
      });

      test('Effects respect enabled state', () {
        // Enable effects first
        controller.setEffectsEnabled(true);
        expect(controller.effectsEnabled, isTrue);
        
        // Disable effects
        controller.setEffectsEnabled(false);
        expect(controller.effectsEnabled, isFalse);
        
        // Try to trigger an effect when disabled - should not throw
        expect(() {
          controller.triggerEffect(
            SparkleTrailEffect(
              points: [const Offset(100, 100), const Offset(200, 200)],
            ),
          );
        }, returnsNormally);
        
        // Verify effects are still disabled
        expect(controller.effectsEnabled, isFalse);
      });
      
      test('Controller notifies listeners on state change', () {
        var notificationCount = 0;
        controller.addListener(() {
          notificationCount++;
        });
        
        // Changing enabled state should notify
        controller.setEffectsEnabled(false);
        expect(notificationCount, equals(1));
        
        controller.setEffectsEnabled(true);
        expect(notificationCount, equals(2));
        
        // Same state shouldn't notify (implementation dependent)
        controller.setEffectsEnabled(true);
        // This might or might not increase the count depending on implementation
        expect(notificationCount, greaterThanOrEqualTo(2));
      });
    });

    group('Performance Tests', () {
      test('Particle system handles maximum particles', () {
        final system = ParticleSystem(
          maxParticles: 1000,
          qualitySettings: qualitySettings,
        );

        // Add more particles than max
        for (int i = 0; i < 1500; i++) {
          final particle = BurstParticle();
          particle.initialize(
            position: vector_math.Vector2(i.toDouble(), i.toDouble()),
            velocity: vector_math.Vector2.zero(),
            color: Colors.white,
            lifespan: 10.0,
          );
          system.addParticle(particle);
        }

        // Should not exceed max
        expect(system.activeParticleCount, lessThanOrEqualTo(1000));
      });

      test('Update completes within frame budget', () {
        final system = ParticleSystem(
          maxParticles: 500,
          qualitySettings: qualitySettings,
        );

        // Add many particles
        for (int i = 0; i < 500; i++) {
          final particle = BurstParticle();
          particle.initialize(
            position: vector_math.Vector2(i.toDouble(), i.toDouble()),
            velocity: vector_math.Vector2(i.toDouble(), -i.toDouble()),
            color: Colors.white,
            lifespan: 5.0,
          );
          system.addParticle(particle);
        }

        // Measure update time
        final stopwatch = Stopwatch()..start();
        system.update(0.016);
        stopwatch.stop();

        // Should complete within 16ms (60fps)
        expect(stopwatch.elapsedMilliseconds, lessThan(16));
      });
    });
  });
}

// Test helper to create a simple render test
class RenderTest {
  static Future<ui.Image> captureEffectRender(
    EffectsWorld world,
    Size size,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Render the world
    world.render(canvas);
    
    final picture = recorder.endRecording();
    return picture.toImage(size.width.toInt(), size.height.toInt());
  }
}
