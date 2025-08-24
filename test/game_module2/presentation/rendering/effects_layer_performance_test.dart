/// Performance benchmark tests for the Effects Layer
/// 
/// These tests ensure the effects system meets performance requirements:
/// - 60fps minimum with all effects active
/// - Support for 1000+ simultaneous particles
/// - Efficient memory usage
/// - Fast effect pooling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'package:puzzgame_flutter/game_module2/presentation/rendering/effects_layer.dart';
import 'package:puzzgame_flutter/game_module2/presentation/rendering/render_coordinator.dart' show QualityLevel;
import 'dart:math' as math;

// Benchmark for particle system update performance
class ParticleSystemBenchmark extends BenchmarkBase {
  late ParticleSystem system;
  final int particleCount;
  final List<BurstParticle> particles = [];

  ParticleSystemBenchmark(this.particleCount)
      : super('ParticleSystem-$particleCount');

  @override
  void setup() {
    system = ParticleSystem(
      maxParticles: particleCount * 2,
      qualitySettings: EffectQualitySettings(
        currentLevel: QualityLevel.high,
      ),
    );

    // Pre-create particles
    final random = math.Random(42); // Fixed seed for reproducibility
    for (int i = 0; i < particleCount; i++) {
      final particle = BurstParticle();
      particle.initialize(
        position: vector_math.Vector2(
          random.nextDouble() * 800,
          random.nextDouble() * 600,
        ),
        velocity: vector_math.Vector2(
          (random.nextDouble() - 0.5) * 200,
          (random.nextDouble() - 0.5) * 200,
        ),
        color: Colors.primaries[random.nextInt(Colors.primaries.length)],
        lifespan: random.nextDouble() * 3 + 1,
      );
      particles.add(particle);
      system.addParticle(particle);
    }
  }

  @override
  void run() {
    // Simulate one frame update (16ms at 60fps)
    system.update(0.016);
  }

  @override
  void teardown() {
    particles.clear();
  }
}

// Benchmark for effect pool performance
class EffectPoolBenchmark extends BenchmarkBase {
  late EffectPool<BurstParticle> pool;
  final int poolSize;
  final int operations;

  EffectPoolBenchmark({
    required this.poolSize,
    required this.operations,
  }) : super('EffectPool-$poolSize-ops$operations');

  @override
  void setup() {
    pool = EffectPool<BurstParticle>(
      createFunction: () => BurstParticle(),
      resetFunction: (p) => p.reset(),
      initialSize: poolSize,
      maxSize: poolSize * 2,
    );
  }

  @override
  void run() {
    final acquired = <BurstParticle>[];
    
    // Acquire half the operations
    for (int i = 0; i < operations ~/ 2; i++) {
      final particle = pool.acquire();
      if (particle != null) {
        acquired.add(particle);
      }
    }
    
    // Release all
    for (final particle in acquired) {
      pool.release(particle);
    }
  }
}

// Benchmark for magnetic field visualization
class MagneticFieldBenchmark extends BenchmarkBase {
  late MagneticFieldVisualizer visualizer;
  final int sourceCount;
  final List<MagneticSource> sources = [];

  MagneticFieldBenchmark(this.sourceCount)
      : super('MagneticField-$sourceCount-sources');

  @override
  void setup() {
    visualizer = MagneticFieldVisualizer(
      size: const Size(800, 600),
      qualitySettings: EffectQualitySettings(
        currentLevel: QualityLevel.high,
      ),
    );

    // Create magnetic sources
    final random = math.Random(42);
    for (int i = 0; i < sourceCount; i++) {
      sources.add(MagneticSource(
        position: Offset(
          random.nextDouble() * 800,
          random.nextDouble() * 600,
        ),
        strength: random.nextDouble(),
        radius: random.nextDouble() * 100 + 50,
      ));
    }
  }

  @override
  void run() {
    visualizer.updateSources(sources);
    visualizer.update(0.016);
  }
}

// Benchmark for multiple simultaneous effects
class SimultaneousEffectsBenchmark extends BenchmarkBase {
  late EffectsController controller;
  late EffectsWorld world;
  final int effectCount;
  final List<EffectDefinition> effects = [];

  SimultaneousEffectsBenchmark(this.effectCount)
      : super('SimultaneousEffects-$effectCount');

  @override
  void setup() {
    controller = EffectsController();
    world = EffectsWorld(
      size: const Size(800, 600),
      controller: controller,
      qualitySettings: EffectQualitySettings(
        currentLevel: QualityLevel.high,
      ),
      debugMode: false,
    );

    // Pre-create various effects
    final random = math.Random(42);
    for (int i = 0; i < effectCount; i++) {
      final effectType = i % 6;
      switch (effectType) {
        case 0:
          effects.add(CelebrationEffect(
            position: Offset(
              random.nextDouble() * 800,
              random.nextDouble() * 600,
            ),
            intensity: random.nextDouble() + 0.5,
          ));
          break;
        case 1:
          effects.add(PiecePlacementEffect(
            position: Offset(
              random.nextDouble() * 800,
              random.nextDouble() * 600,
            ),
            color: Colors.primaries[random.nextInt(Colors.primaries.length)],
          ));
          break;
        case 2:
          effects.add(MagneticPulseEffect(
            center: Offset(
              random.nextDouble() * 800,
              random.nextDouble() * 600,
            ),
            strength: random.nextDouble(),
            radius: random.nextDouble() * 50 + 50,
          ));
          break;
        case 3:
          effects.add(TouchRippleEffect(
            position: Offset(
              random.nextDouble() * 800,
              random.nextDouble() * 600,
            ),
            maxRadius: random.nextDouble() * 30 + 20,
          ));
          break;
        case 4:
          effects.add(GlowHighlightEffect(
            position: Offset(
              random.nextDouble() * 800,
              random.nextDouble() * 600,
            ),
            radius: random.nextDouble() * 20 + 10,
          ));
          break;
        case 5:
          final points = <Offset>[];
          for (int j = 0; j < 10; j++) {
            points.add(Offset(
              random.nextDouble() * 800,
              random.nextDouble() * 600,
            ));
          }
          effects.add(SparkleTrailEffect(points: points));
          break;
      }
    }
  }

  @override
  void run() {
    // Trigger all effects
    for (final effect in effects) {
      world.triggerEffect(effect);
    }
    
    // Update for one frame
    world.update(0.016);
  }

  @override
  void teardown() {
    controller.dispose();
  }
}

// Memory allocation benchmark
class MemoryAllocationBenchmark extends BenchmarkBase {
  final int allocations;

  MemoryAllocationBenchmark(this.allocations)
      : super('MemoryAllocation-$allocations');

  @override
  void run() {
    final particles = <BaseParticle>[];
    
    for (int i = 0; i < allocations; i++) {
      final type = i % 3;
      BaseParticle particle;
      
      switch (type) {
        case 0:
          particle = BurstParticle();
          break;
        case 1:
          particle = ConfettiParticle();
          break;
        case 2:
          particle = SparkleParticle();
          break;
        default:
          particle = BurstParticle();
      }
      
      particle.initialize(
        position: vector_math.Vector2(i.toDouble(), i.toDouble()),
        velocity: vector_math.Vector2.zero(),
        color: Colors.white,
        lifespan: 1.0,
      );
      
      particles.add(particle);
    }
    
    // Clear to trigger garbage collection in next iteration
    particles.clear();
  }
}

void main() {
  group('Performance Benchmarks', () {
    test('Particle system update benchmark - 100 particles', () {
      final benchmark = ParticleSystemBenchmark(100);
      final result = benchmark.measure();
      
      // Should complete in less than 1ms for 100 particles
      expect(result, lessThan(1000)); // microseconds
      print('100 particles update: ${result / 1000}ms');
    });

    test('Particle system update benchmark - 500 particles', () {
      final benchmark = ParticleSystemBenchmark(500);
      final result = benchmark.measure();
      
      // Should complete in less than 5ms for 500 particles
      expect(result, lessThan(5000));
      print('500 particles update: ${result / 1000}ms');
    });

    test('Particle system update benchmark - 1000 particles', () {
      final benchmark = ParticleSystemBenchmark(1000);
      final result = benchmark.measure();
      
      // Should complete in less than 10ms for 1000 particles
      expect(result, lessThan(10000));
      print('1000 particles update: ${result / 1000}ms');
    });

    test('Particle system update benchmark - 2000 particles', () {
      final benchmark = ParticleSystemBenchmark(2000);
      final result = benchmark.measure();
      
      // Should complete in less than 16ms for 2000 particles (60fps)
      expect(result, lessThan(16000));
      print('2000 particles update: ${result / 1000}ms');
    });

    test('Effect pool acquire/release benchmark', () {
      final benchmark = EffectPoolBenchmark(
        poolSize: 100,
        operations: 200,
      );
      final result = benchmark.measure();
      
      // Should be very fast
      expect(result, lessThan(500));
      print('Pool operations (200): ${result / 1000}ms');
    });

    test('Large effect pool benchmark', () {
      final benchmark = EffectPoolBenchmark(
        poolSize: 1000,
        operations: 2000,
      );
      final result = benchmark.measure();
      
      // Should still be fast even with large pool
      expect(result, lessThan(2000));
      print('Large pool operations (2000): ${result / 1000}ms');
    });

    test('Magnetic field update benchmark - 5 sources', () {
      final benchmark = MagneticFieldBenchmark(5);
      final result = benchmark.measure();
      
      // Should be fast for typical number of sources
      expect(result, lessThan(2000));
      print('Magnetic field (5 sources): ${result / 1000}ms');
    });

    test('Magnetic field update benchmark - 20 sources', () {
      final benchmark = MagneticFieldBenchmark(20);
      final result = benchmark.measure();
      
      // Should still maintain performance with many sources
      expect(result, lessThan(8000));
      print('Magnetic field (20 sources): ${result / 1000}ms');
    });

    test('Simultaneous effects benchmark - 10 effects', () {
      final benchmark = SimultaneousEffectsBenchmark(10);
      final result = benchmark.measure();
      
      // Should handle multiple effects easily
      expect(result, lessThan(5000));
      print('Simultaneous effects (10): ${result / 1000}ms');
    });

    test('Simultaneous effects benchmark - 50 effects', () {
      final benchmark = SimultaneousEffectsBenchmark(50);
      final result = benchmark.measure();
      
      // Should still be within frame budget
      expect(result, lessThan(16000));
      print('Simultaneous effects (50): ${result / 1000}ms');
    });

    test('Memory allocation benchmark - 100 particles', () {
      final benchmark = MemoryAllocationBenchmark(100);
      final result = benchmark.measure();
      
      // Allocation should be fast
      expect(result, lessThan(1000));
      print('Memory allocation (100): ${result / 1000}ms');
    });

    test('Memory allocation benchmark - 1000 particles', () {
      final benchmark = MemoryAllocationBenchmark(1000);
      final result = benchmark.measure();
      
      // Even large allocations should be reasonable
      expect(result, lessThan(10000));
      print('Memory allocation (1000): ${result / 1000}ms');
    });

    test('Frame budget compliance test', () {
      // Test that typical workload fits in 16ms frame budget
      final particleBenchmark = ParticleSystemBenchmark(500);
      final poolBenchmark = EffectPoolBenchmark(
        poolSize: 100,
        operations: 50,
      );
      final fieldBenchmark = MagneticFieldBenchmark(5);
      
      final particleTime = particleBenchmark.measure();
      final poolTime = poolBenchmark.measure();
      final fieldTime = fieldBenchmark.measure();
      
      final totalTime = particleTime + poolTime + fieldTime;
      
      print('Frame budget test:');
      print('  Particles: ${particleTime / 1000}ms');
      print('  Pool: ${poolTime / 1000}ms');
      print('  Field: ${fieldTime / 1000}ms');
      print('  Total: ${totalTime / 1000}ms');
      print('  Budget remaining: ${(16000 - totalTime) / 1000}ms');
      
      // Should fit within 16ms frame budget (60fps)
      expect(totalTime, lessThan(16000));
    });

    test('Stress test - maximum load', () {
      // Test absolute maximum the system can handle
      final benchmark = ParticleSystemBenchmark(2000);
      final effectsBenchmark = SimultaneousEffectsBenchmark(100);
      
      final particleTime = benchmark.measure();
      final effectsTime = effectsBenchmark.measure();
      
      print('Stress test:');
      print('  2000 particles: ${particleTime / 1000}ms');
      print('  100 effects: ${effectsTime / 1000}ms');
      
      // Even under extreme load, should not exceed 33ms (30fps minimum)
      expect(particleTime, lessThan(33000));
      expect(effectsTime, lessThan(33000));
    });
  });

  group('Quality Settings Performance', () {
    test('Low quality performance', () {
      final system = ParticleSystem(
        maxParticles: 100,
        qualitySettings: EffectQualitySettings(
          currentLevel: QualityLevel.low,
        ),
      );

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 60; i++) {
        system.update(0.016);
      }
      stopwatch.stop();

      // Low quality should be very fast
      final avgFrameTime = stopwatch.elapsedMicroseconds / 60;
      expect(avgFrameTime, lessThan(1000)); // Less than 1ms per frame
      print('Low quality avg frame: ${avgFrameTime / 1000}ms');
    });

    test('Ultra quality performance', () {
      final system = ParticleSystem(
        maxParticles: 2000,
        qualitySettings: EffectQualitySettings(
          currentLevel: QualityLevel.ultra,
        ),
      );

      // Add particles
      for (int i = 0; i < 500; i++) {
        final particle = BurstParticle();
        particle.initialize(
          position: vector_math.Vector2(i.toDouble(), i.toDouble()),
          velocity: vector_math.Vector2.zero(),
          color: Colors.white,
          lifespan: 10.0,
        );
        system.addParticle(particle);
      }

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 60; i++) {
        system.update(0.016);
      }
      stopwatch.stop();

      // Ultra quality should still maintain 60fps
      final avgFrameTime = stopwatch.elapsedMicroseconds / 60;
      expect(avgFrameTime, lessThan(16000)); // Less than 16ms per frame
      print('Ultra quality avg frame: ${avgFrameTime / 1000}ms');
    });
  });
}
