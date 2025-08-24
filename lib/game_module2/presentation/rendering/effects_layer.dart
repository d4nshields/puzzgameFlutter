/// Advanced Particle Effects Layer for Puzzle Nook
/// 
/// This implementation provides a high-performance particle effects system
/// using the Flame engine for visual effects and celebrations.
/// 
/// Features:
/// - ParticleSystem for celebrations with multiple effect types
/// - MagneticFieldVisualizer for dynamic field line rendering
/// - GlowEffect for piece highlighting with animated intensity
/// - RippleEffect for touch feedback with wave propagation
/// - Effect pooling for performance optimization
/// - Toggleable effects for performance tuning
/// - Debug mode with particle count and performance metrics
/// 
/// Performance Targets:
/// - 60fps minimum with all effects active
/// - Support for 1000+ simultaneous particles
/// - Memory-efficient effect pooling
/// - Automatic quality adjustment based on performance

import 'dart:collection';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;

/// Main effects layer that integrates with Flame engine
class EffectsLayer extends StatefulWidget {
  final Size size;
  final EffectsController controller;
  final bool debugMode;
  final EffectQualitySettings qualitySettings;

  EffectsLayer({
    super.key,
    required this.size,
    required this.controller,
    this.debugMode = false,
    EffectQualitySettings? qualitySettings,
  }) : qualitySettings = qualitySettings ?? EffectQualitySettings();

  @override
  State<EffectsLayer> createState() => _EffectsLayerState();
}

class _EffectsLayerState extends State<EffectsLayer> {
  late final FlameGame _game;
  late final EffectsWorld _world;

  @override
  void initState() {
    super.initState();
    _initializeFlameGame();
    widget.controller._attachToLayer(this);
  }

  void _initializeFlameGame() {
    _world = EffectsWorld(
      size: widget.size,
      controller: widget.controller,
      qualitySettings: widget.qualitySettings,
      debugMode: widget.debugMode,
    );
    
    _game = FlameGame(world: _world);
  }

  void triggerEffect(EffectDefinition effect) {
    _world.triggerEffect(effect);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Flame game widget for effects
        GameWidget(game: _game),
        
        // Debug overlay
        if (widget.debugMode)
          Positioned(
            top: 10,
            left: 10,
            child: _DebugOverlay(
              controller: widget.controller,
              world: _world,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    widget.controller._detachFromLayer();
    super.dispose();
  }
}

/// Flame world for effects rendering
class EffectsWorld extends World with HasGameRef<FlameGame> {
  final Size size;
  final EffectsController controller;
  final EffectQualitySettings qualitySettings;
  final bool debugMode;

  // Effect systems
  late final ParticleSystem _particleSystem;
  late final MagneticFieldVisualizer _magneticFieldVisualizer;
  late final GlowEffectSystem _glowEffectSystem;
  late final RippleEffectSystem _rippleEffectSystem;

  // Effect pools for performance
  late final EffectPool<BurstParticle> _burstPool;
  late final EffectPool<ConfettiParticle> _confettiPool;
  late final EffectPool<SparkleParticle> _sparklePool;
  late final EffectPool<RippleWave> _ripplePool;

  // Performance tracking
  int _activeParticleCount = 0;
  int _activeEffectCount = 0;
  final _performanceMetrics = PerformanceMetrics();

  EffectsWorld({
    required this.size,
    required this.controller,
    required this.qualitySettings,
    required this.debugMode,
  }) {
    _initializeSystems();
    _initializeEffectPools();
  }

  void _initializeSystems() {
    // Initialize particle system
    _particleSystem = ParticleSystem(
      maxParticles: qualitySettings.maxParticles,
      qualitySettings: qualitySettings,
    );
    add(_particleSystem);

    // Initialize magnetic field visualizer
    _magneticFieldVisualizer = MagneticFieldVisualizer(
      size: size,
      qualitySettings: qualitySettings,
    );
    add(_magneticFieldVisualizer);

    // Initialize glow effect system
    _glowEffectSystem = GlowEffectSystem(
      qualitySettings: qualitySettings,
    );
    add(_glowEffectSystem);

    // Initialize ripple effect system
    _rippleEffectSystem = RippleEffectSystem(
      qualitySettings: qualitySettings,
    );
    add(_rippleEffectSystem);
  }

  void _initializeEffectPools() {
    // Create object pools for different particle types
    _burstPool = EffectPool<BurstParticle>(
      createFunction: () => BurstParticle(),
      resetFunction: (particle) => particle.reset(),
      initialSize: 100,
      maxSize: 500,
    );

    _confettiPool = EffectPool<ConfettiParticle>(
      createFunction: () => ConfettiParticle(),
      resetFunction: (particle) => particle.reset(),
      initialSize: 200,
      maxSize: 1000,
    );

    _sparklePool = EffectPool<SparkleParticle>(
      createFunction: () => SparkleParticle(),
      resetFunction: (particle) => particle.reset(),
      initialSize: 50,
      maxSize: 200,
    );

    _ripplePool = EffectPool<RippleWave>(
      createFunction: () => RippleWave(),
      resetFunction: (wave) => wave.reset(),
      initialSize: 10,
      maxSize: 50,
    );
  }

  void triggerEffect(EffectDefinition effect) {
    if (!qualitySettings.isEffectEnabled(effect.type)) {
      return;
    }

    _activeEffectCount++;

    switch (effect.type) {
      case EffectType.celebration:
        _triggerCelebration(effect as CelebrationEffect);
        break;
      case EffectType.piecePlacement:
        _triggerPiecePlacement(effect as PiecePlacementEffect);
        break;
      case EffectType.magneticPulse:
        _triggerMagneticPulse(effect as MagneticPulseEffect);
        break;
      case EffectType.touchRipple:
        _triggerTouchRipple(effect as TouchRippleEffect);
        break;
      case EffectType.glowHighlight:
        _triggerGlowHighlight(effect as GlowHighlightEffect);
        break;
      case EffectType.sparkleTrail:
        _triggerSparkleTrail(effect as SparkleTrailEffect);
        break;
    }

    // Update performance metrics
    _performanceMetrics.recordEffect(effect.type);
  }

  void _triggerCelebration(CelebrationEffect effect) {
    // Create burst of confetti
    const confettiCount = 100;
    for (int i = 0; i < confettiCount; i++) {
      final confetti = _confettiPool.acquire();
      if (confetti != null) {
        confetti.initialize(
          position: vector_math.Vector2(effect.position.dx, effect.position.dy),
          velocity: _randomVelocity(200, 400),
          color: _randomCelebrationColor(),
          lifespan: 3.0,
        );
        _particleSystem.addParticle(confetti);
        _activeParticleCount++;
      }
    }

    // Add firework burst
    _createFireworkBurst(effect.position, effect.intensity);
  }

  void _triggerPiecePlacement(PiecePlacementEffect effect) {
    // Create radial burst
    const particleCount = 20;
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final particle = _burstPool.acquire();
      if (particle != null) {
        particle.initialize(
          position: vector_math.Vector2(effect.position.dx, effect.position.dy),
          velocity: vector_math.Vector2(
            math.cos(angle) * 150,
            math.sin(angle) * 150,
          ),
          color: effect.color,
          lifespan: 0.5,
        );
        _particleSystem.addParticle(particle);
        _activeParticleCount++;
      }
    }

    // Add glow effect
    _glowEffectSystem.addGlow(
      position: effect.position,
      radius: 50,
      color: effect.color,
      duration: 0.3,
    );
  }

  void _triggerMagneticPulse(MagneticPulseEffect effect) {
    _magneticFieldVisualizer.addPulse(
      MagneticPulse(
        center: effect.center,
        strength: effect.strength,
        radius: effect.radius,
        duration: effect.duration,
      ),
    );
  }

  void _triggerTouchRipple(TouchRippleEffect effect) {
    final ripple = _ripplePool.acquire();
    if (ripple != null) {
      ripple.initialize(
        center: effect.position,
        maxRadius: effect.maxRadius,
        duration: effect.duration,
        color: effect.color,
      );
      _rippleEffectSystem.addRipple(ripple);
    }
  }

  void _triggerGlowHighlight(GlowHighlightEffect effect) {
    _glowEffectSystem.addGlow(
      position: effect.position,
      radius: effect.radius,
      color: effect.color,
      duration: effect.duration,
      pulseFrequency: effect.pulseFrequency,
    );
  }

  void _triggerSparkleTrail(SparkleTrailEffect effect) {
    for (final point in effect.points) {
      final sparkle = _sparklePool.acquire();
      if (sparkle != null) {
        sparkle.initialize(
          position: vector_math.Vector2(point.dx, point.dy),
          velocity: _randomVelocity(10, 30),
          color: effect.color,
          lifespan: 0.5,
        );
        _particleSystem.addParticle(sparkle);
        _activeParticleCount++;
      }
    }
  }

  void _createFireworkBurst(Offset center, double intensity) {
    // Create multi-stage firework effect
    final burstCount = (intensity * 50).toInt();
    final colors = [
      Colors.red,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
    ];

    for (int i = 0; i < burstCount; i++) {
      final particle = _sparklePool.acquire();
      if (particle != null) {
        final angle = math.Random().nextDouble() * 2 * math.pi;
        final speed = math.Random().nextDouble() * 200 + 100;
        
        particle.initialize(
          position: vector_math.Vector2(center.dx, center.dy),
          velocity: vector_math.Vector2(
            math.cos(angle) * speed,
            math.sin(angle) * speed,
          ),
          color: colors[math.Random().nextInt(colors.length)],
          lifespan: 1.5,
        );
        
        _particleSystem.addParticle(particle);
        _activeParticleCount++;
      }
    }
  }

  vector_math.Vector2 _randomVelocity(double minSpeed, double maxSpeed) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = random.nextDouble() * (maxSpeed - minSpeed) + minSpeed;
    return vector_math.Vector2(
      math.cos(angle) * speed,
      math.sin(angle) * speed,
    );
  }

  Color _randomCelebrationColor() {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.pink,
    ];
    return colors[math.Random().nextInt(colors.length)];
  }

  void updateMagneticField(List<MagneticSource> sources) {
    _magneticFieldVisualizer.updateSources(sources);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update particle count
    _activeParticleCount = _particleSystem.activeParticleCount;
    
    // Update performance metrics
    _performanceMetrics.update(dt, _activeParticleCount, _activeEffectCount);
    
    // Auto-adjust quality if needed
    if (qualitySettings.autoAdjustQuality) {
      _adjustQualityBasedOnPerformance();
    }
  }

  void _adjustQualityBasedOnPerformance() {
    final fps = _performanceMetrics.currentFps;
    
    if (fps < 55 && qualitySettings.currentLevel > QualityLevel.low) {
      qualitySettings.decreaseQuality();
      _applyQualitySettings();
    } else if (fps > 58 && qualitySettings.currentLevel < QualityLevel.ultra) {
      qualitySettings.increaseQuality();
      _applyQualitySettings();
    }
  }

  void _applyQualitySettings() {
    _particleSystem.maxParticles = qualitySettings.maxParticles;
    _magneticFieldVisualizer.updateQuality(qualitySettings);
    _glowEffectSystem.updateQuality(qualitySettings);
    _rippleEffectSystem.updateQuality(qualitySettings);
  }

  int get activeParticleCount => _activeParticleCount;
  int get activeEffectCount => _activeEffectCount;
  PerformanceMetrics get performanceMetrics => _performanceMetrics;
}

/// Particle system component for managing all particles
class ParticleSystem extends Component with HasGameRef {
  int maxParticles;
  final EffectQualitySettings qualitySettings;
  final List<BaseParticle> _particles = [];

  ParticleSystem({
    required this.maxParticles,
    required this.qualitySettings,
  });

  void addParticle(BaseParticle particle) {
    if (_particles.length >= maxParticles) {
      // Remove oldest particle if at capacity
      if (_particles.isNotEmpty) {
        _particles.removeAt(0);
      }
    }
    _particles.add(particle);
  }

  @override
  void update(double dt) {
    // Update all particles
    _particles.removeWhere((particle) {
      particle.update(dt);
      return !particle.isAlive;
    });
  }

  @override
  void render(Canvas canvas) {
    for (final particle in _particles) {
      particle.render(canvas, qualitySettings);
    }
  }

  int get activeParticleCount => _particles.length;
}

/// Magnetic field visualizer component
class MagneticFieldVisualizer extends Component {
  final Size size;
  EffectQualitySettings qualitySettings;
  final List<MagneticSource> _sources = [];
  final List<FieldLine> _fieldLines = [];
  final List<MagneticPulse> _pulses = [];
  double _animationTime = 0;

  MagneticFieldVisualizer({
    required this.size,
    required this.qualitySettings,
  }) {
    _generateFieldLines();
  }

  void updateSources(List<MagneticSource> sources) {
    _sources.clear();
    _sources.addAll(sources);
    _generateFieldLines();
  }

  void addPulse(MagneticPulse pulse) {
    _pulses.add(pulse);
  }

  void _generateFieldLines() {
    _fieldLines.clear();
    
    if (!qualitySettings.showMagneticField) return;
    
    for (final source in _sources) {
      final lineCount = qualitySettings.fieldLineCount;
      for (int i = 0; i < lineCount; i++) {
        final angle = (i / lineCount) * 2 * math.pi;
        _fieldLines.add(FieldLine(
          points: _calculateFieldLine(source, angle),
          strength: source.strength,
          color: source.color,
        ));
      }
    }
  }

  List<Offset> _calculateFieldLine(MagneticSource source, double startAngle) {
    final points = <Offset>[];
    const steps = 30;
    final maxRadius = source.radius;
    
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final r = maxRadius * (0.1 + t * 0.9);
      
      // Add spiral effect for visual interest
      final spiralFactor = t * source.strength * 0.5;
      final angle = startAngle + spiralFactor;
      
      // Apply field distortion
      final distortion = math.sin(t * math.pi) * 0.2;
      
      points.add(Offset(
        source.position.dx + r * math.cos(angle) * (1 + distortion),
        source.position.dy + r * math.sin(angle) * (1 + distortion),
      ));
    }
    
    return points;
  }

  @override
  void update(double dt) {
    _animationTime += dt;
    
    // Update pulses
    _pulses.removeWhere((pulse) {
      pulse.update(dt);
      return !pulse.isActive;
    });
  }

  @override
  void render(Canvas canvas) {
    if (!qualitySettings.showMagneticField) return;
    
    // Render field lines with animation
    for (final line in _fieldLines) {
      _renderFieldLine(canvas, line);
    }
    
    // Render pulses
    for (final pulse in _pulses) {
      _renderPulse(canvas, pulse);
    }
  }

  void _renderFieldLine(Canvas canvas, FieldLine line) {
    final path = Path();
    bool first = true;
    
    for (final point in line.points) {
      if (first) {
        path.moveTo(point.dx, point.dy);
        first = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    
    // Animated opacity based on field strength and time
    final opacity = (0.1 + 0.1 * math.sin(_animationTime * 2 + line.strength)) *
        qualitySettings.effectOpacity;
    
    final paint = Paint()
      ..color = line.color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * qualitySettings.particleScale
      ..strokeCap = StrokeCap.round;
    
    // Add glow effect for higher quality
    if (qualitySettings.currentLevel >= QualityLevel.high) {
      final glowPaint = Paint()
        ..color = line.color.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0 * qualitySettings.particleScale
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
      canvas.drawPath(path, glowPaint);
    }
    
    canvas.drawPath(path, paint);
  }

  void _renderPulse(Canvas canvas, MagneticPulse pulse) {
    final paint = Paint()
      ..color = pulse.color.withOpacity(pulse.opacity * qualitySettings.effectOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * qualitySettings.particleScale;
    
    canvas.drawCircle(
      pulse.center,
      pulse.currentRadius,
      paint,
    );
    
    // Add inner rings for higher quality
    if (qualitySettings.currentLevel >= QualityLevel.medium) {
      for (int i = 1; i <= 3; i++) {
        final innerOpacity = pulse.opacity * (1 - i * 0.3);
        if (innerOpacity > 0) {
          canvas.drawCircle(
            pulse.center,
            pulse.currentRadius * (1 - i * 0.2),
            Paint()
              ..color = pulse.color.withOpacity(innerOpacity * qualitySettings.effectOpacity)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0 * qualitySettings.particleScale,
          );
        }
      }
    }
  }

  void updateQuality(EffectQualitySettings newSettings) {
    qualitySettings = newSettings;
    _generateFieldLines();
  }
}

/// Glow effect system component
class GlowEffectSystem extends Component {
  EffectQualitySettings qualitySettings;
  final List<GlowInstance> _glows = [];

  GlowEffectSystem({
    required this.qualitySettings,
  });

  void addGlow({
    required Offset position,
    required double radius,
    required Color color,
    required double duration,
    double pulseFrequency = 0,
  }) {
    if (!qualitySettings.enableGlowEffects) return;
    
    _glows.add(GlowInstance(
      position: position,
      radius: radius,
      color: color,
      duration: duration,
      pulseFrequency: pulseFrequency,
    ));
  }

  @override
  void update(double dt) {
    _glows.removeWhere((glow) {
      glow.update(dt);
      return !glow.isActive;
    });
  }

  @override
  void render(Canvas canvas) {
    if (!qualitySettings.enableGlowEffects) return;
    
    for (final glow in _glows) {
      _renderGlow(canvas, glow);
    }
  }

  void _renderGlow(Canvas canvas, GlowInstance glow) {
    // Calculate animated intensity
    double intensity = glow.baseIntensity;
    if (glow.pulseFrequency > 0) {
      intensity *= 0.8 + 0.2 * math.sin(glow.elapsed * glow.pulseFrequency * 2 * math.pi);
    }
    
    // Fade in/out
    if (glow.elapsed < 0.1) {
      intensity *= glow.elapsed / 0.1;
    } else if (glow.remaining < 0.1) {
      intensity *= glow.remaining / 0.1;
    }
    
    // Multi-layer glow for quality
    final layers = qualitySettings.currentLevel == QualityLevel.ultra ? 4 :
                   qualitySettings.currentLevel == QualityLevel.high ? 3 :
                   qualitySettings.currentLevel == QualityLevel.medium ? 2 : 1;
    
    for (int i = layers - 1; i >= 0; i--) {
      final layerIntensity = intensity * (1 - i * 0.2) * qualitySettings.effectOpacity;
      final layerRadius = glow.radius * (1 + i * 0.5);
      
      final paint = Paint()
        ..color = glow.color.withOpacity(layerIntensity * 0.3)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          layerRadius * 0.3,
        )
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(glow.position, layerRadius, paint);
    }
  }

  void updateQuality(EffectQualitySettings newSettings) {
    qualitySettings = newSettings;
  }
}

/// Ripple effect system component
class RippleEffectSystem extends Component {
  EffectQualitySettings qualitySettings;
  final List<RippleWave> _ripples = [];

  RippleEffectSystem({
    required this.qualitySettings,
  });

  void addRipple(RippleWave ripple) {
    if (!qualitySettings.enableRippleEffects) return;
    _ripples.add(ripple);
  }

  @override
  void update(double dt) {
    _ripples.removeWhere((ripple) {
      ripple.update(dt);
      return !ripple.isActive;
    });
  }

  @override
  void render(Canvas canvas) {
    if (!qualitySettings.enableRippleEffects) return;
    
    for (final ripple in _ripples) {
      _renderRipple(canvas, ripple);
    }
  }

  void _renderRipple(Canvas canvas, RippleWave ripple) {
    final waveCount = qualitySettings.currentLevel == QualityLevel.ultra ? 3 :
                      qualitySettings.currentLevel == QualityLevel.high ? 2 : 1;
    
    for (int i = 0; i < waveCount; i++) {
      final waveProgress = (ripple.progress - i * 0.15).clamp(0.0, 1.0);
      if (waveProgress <= 0) continue;
      
      final waveRadius = ripple.maxRadius * waveProgress;
      final waveOpacity = (1 - waveProgress) * qualitySettings.effectOpacity;
      
      final paint = Paint()
        ..color = ripple.color.withOpacity(waveOpacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * qualitySettings.particleScale * (1 - waveProgress * 0.5);
      
      canvas.drawCircle(ripple.center, waveRadius, paint);
    }
  }

  void updateQuality(EffectQualitySettings newSettings) {
    qualitySettings = newSettings;
  }
}

/// Base particle class
abstract class BaseParticle {
  vector_math.Vector2 position = vector_math.Vector2.zero();
  vector_math.Vector2 velocity = vector_math.Vector2.zero();
  Color color = Colors.white;
  double lifespan = 1.0;
  double elapsed = 0.0;
  bool isAlive = true;

  void initialize({
    required vector_math.Vector2 position,
    required vector_math.Vector2 velocity,
    required Color color,
    required double lifespan,
  }) {
    this.position = position.clone();
    this.velocity = velocity.clone();
    this.color = color;
    this.lifespan = lifespan;
    elapsed = 0.0;
    isAlive = true;
  }

  void update(double dt) {
    if (!isAlive) return;
    
    elapsed += dt;
    if (elapsed >= lifespan) {
      isAlive = false;
      return;
    }
    
    // Update position
    position += velocity * dt;
    
    // Apply physics
    applyPhysics(dt);
  }

  void applyPhysics(double dt) {
    // Apply gravity
    velocity.y += 300 * dt;
    
    // Apply damping
    velocity *= 0.98;
  }

  void render(Canvas canvas, EffectQualitySettings quality);

  void reset() {
    position.setZero();
    velocity.setZero();
    color = Colors.white;
    lifespan = 1.0;
    elapsed = 0.0;
    isAlive = false;
  }

  double get progress => elapsed / lifespan;
  double get opacity => math.max(0, 1 - progress);
}

/// Burst particle implementation
class BurstParticle extends BaseParticle {
  @override
  void render(Canvas canvas, EffectQualitySettings quality) {
    final paint = Paint()
      ..color = color.withOpacity(opacity * quality.effectOpacity)
      ..style = PaintingStyle.fill;
    
    final size = 3.0 * quality.particleScale * (1 - progress * 0.5);
    canvas.drawCircle(
      Offset(position.x, position.y),
      size,
      paint,
    );
  }
}

/// Confetti particle implementation
class ConfettiParticle extends BaseParticle {
  double rotation = 0;
  double rotationSpeed = 0;
  Size size = const Size(8, 4);

  @override
  void initialize({
    required vector_math.Vector2 position,
    required vector_math.Vector2 velocity,
    required Color color,
    required double lifespan,
  }) {
    super.initialize(
      position: position,
      velocity: velocity,
      color: color,
      lifespan: lifespan,
    );
    
    final random = math.Random();
    rotation = random.nextDouble() * 2 * math.pi;
    rotationSpeed = (random.nextDouble() - 0.5) * 10;
    size = Size(
      random.nextDouble() * 6 + 4,
      random.nextDouble() * 3 + 2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    rotation += rotationSpeed * dt;
  }

  @override
  void render(Canvas canvas, EffectQualitySettings quality) {
    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(rotation);
    
    final paint = Paint()
      ..color = color.withOpacity(opacity * quality.effectOpacity)
      ..style = PaintingStyle.fill;
    
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * quality.particleScale,
      height: size.height * quality.particleScale,
    );
    
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  void reset() {
    super.reset();
    rotation = 0;
    rotationSpeed = 0;
    size = const Size(8, 4);
  }
}

/// Sparkle particle implementation
class SparkleParticle extends BaseParticle {
  double sparklePhase = 0;

  @override
  void initialize({
    required vector_math.Vector2 position,
    required vector_math.Vector2 velocity,
    required Color color,
    required double lifespan,
  }) {
    super.initialize(
      position: position,
      velocity: velocity,
      color: color,
      lifespan: lifespan,
    );
    sparklePhase = math.Random().nextDouble() * 2 * math.pi;
  }

  @override
  void update(double dt) {
    super.update(dt);
    sparklePhase += dt * 10;
  }

  @override
  void applyPhysics(double dt) {
    // Sparkles have different physics - they float more
    velocity.y += 100 * dt; // Less gravity
    velocity *= 0.95; // More damping
  }

  @override
  void render(Canvas canvas, EffectQualitySettings quality) {
    final sparkle = 0.5 + 0.5 * math.sin(sparklePhase);
    final paint = Paint()
      ..color = color.withOpacity(opacity * sparkle * quality.effectOpacity)
      ..style = PaintingStyle.fill;
    
    // Draw star shape
    final size = 4.0 * quality.particleScale * (1 - progress * 0.3);
    final center = Offset(position.x, position.y);
    
    // Simple 4-point star
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final radius = i.isEven ? size : size * 0.3;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  void reset() {
    super.reset();
    sparklePhase = 0;
  }
}

/// Ripple wave implementation
class RippleWave {
  Offset center = Offset.zero;
  double maxRadius = 100;
  double duration = 1.0;
  Color color = Colors.white;
  double elapsed = 0;
  bool isActive = true;

  void initialize({
    required Offset center,
    required double maxRadius,
    required double duration,
    required Color color,
  }) {
    this.center = center;
    this.maxRadius = maxRadius;
    this.duration = duration;
    this.color = color;
    elapsed = 0;
    isActive = true;
  }

  void update(double dt) {
    elapsed += dt;
    if (elapsed >= duration) {
      isActive = false;
    }
  }

  void reset() {
    center = Offset.zero;
    maxRadius = 100;
    duration = 1.0;
    color = Colors.white;
    elapsed = 0;
    isActive = false;
  }

  double get progress => elapsed / duration;
}

/// Effect pool for object reuse
class EffectPool<T> {
  final T Function() createFunction;
  final void Function(T) resetFunction;
  final int maxSize;
  final Queue<T> _available = Queue();
  final Set<T> _inUse = {};

  EffectPool({
    required this.createFunction,
    required this.resetFunction,
    required int initialSize,
    required this.maxSize,
  }) {
    // Pre-allocate initial objects
    for (int i = 0; i < initialSize; i++) {
      _available.add(createFunction());
    }
  }

  T? acquire() {
    T object;
    
    if (_available.isNotEmpty) {
      object = _available.removeFirst();
    } else if (_inUse.length < maxSize) {
      object = createFunction();
    } else {
      return null; // Pool exhausted
    }
    
    _inUse.add(object);
    return object;
  }

  void release(T object) {
    if (_inUse.remove(object)) {
      resetFunction(object);
      _available.add(object);
    }
  }

  void releaseAll() {
    for (final object in _inUse) {
      resetFunction(object);
      _available.add(object);
    }
    _inUse.clear();
  }

  int get availableCount => _available.length;
  int get inUseCount => _inUse.length;
  int get totalCount => availableCount + inUseCount;
}

/// Controller for managing effects
class EffectsController extends ChangeNotifier {
  _EffectsLayerState? _layerState;
  final List<MagneticSource> _magneticSources = [];
  bool _effectsEnabled = true;

  void _attachToLayer(_EffectsLayerState state) {
    _layerState = state;
  }

  void _detachFromLayer() {
    _layerState = null;
  }

  void triggerEffect(EffectDefinition effect) {
    if (!_effectsEnabled) return;
    _layerState?.triggerEffect(effect);
  }

  void updateMagneticSources(List<MagneticSource> sources) {
    _magneticSources.clear();
    _magneticSources.addAll(sources);
    _layerState?._world.updateMagneticField(sources);
  }

  void setEffectsEnabled(bool enabled) {
    _effectsEnabled = enabled;
    notifyListeners();
  }

  bool get effectsEnabled => _effectsEnabled;
}

/// Effect quality settings
class EffectQualitySettings {
  QualityLevel currentLevel;
  final bool autoAdjustQuality;
  
  EffectQualitySettings({
    this.currentLevel = QualityLevel.high,
    this.autoAdjustQuality = true,
  });

  int get maxParticles {
    switch (currentLevel) {
      case QualityLevel.low:
        return 100;
      case QualityLevel.medium:
        return 500;
      case QualityLevel.high:
        return 1000;
      case QualityLevel.ultra:
        return 2000;
    }
  }

  double get particleScale {
    switch (currentLevel) {
      case QualityLevel.low:
        return 0.5;
      case QualityLevel.medium:
        return 0.75;
      case QualityLevel.high:
        return 1.0;
      case QualityLevel.ultra:
        return 1.0;
    }
  }

  double get effectOpacity {
    switch (currentLevel) {
      case QualityLevel.low:
        return 0.6;
      case QualityLevel.medium:
        return 0.8;
      case QualityLevel.high:
        return 1.0;
      case QualityLevel.ultra:
        return 1.0;
    }
  }

  bool get enableGlowEffects => currentLevel >= QualityLevel.medium;
  bool get enableRippleEffects => currentLevel >= QualityLevel.medium;
  bool get showMagneticField => currentLevel >= QualityLevel.low;
  int get fieldLineCount {
    switch (currentLevel) {
      case QualityLevel.low:
        return 6;
      case QualityLevel.medium:
        return 12;
      case QualityLevel.high:
        return 18;
      case QualityLevel.ultra:
        return 24;
    }
  }

  bool isEffectEnabled(EffectType type) {
    switch (type) {
      case EffectType.celebration:
        return true; // Always enabled
      case EffectType.piecePlacement:
        return currentLevel >= QualityLevel.low;
      case EffectType.magneticPulse:
        return currentLevel >= QualityLevel.medium;
      case EffectType.touchRipple:
        return currentLevel >= QualityLevel.medium;
      case EffectType.glowHighlight:
        return currentLevel >= QualityLevel.medium;
      case EffectType.sparkleTrail:
        return currentLevel >= QualityLevel.high;
    }
  }

  void increaseQuality() {
    switch (currentLevel) {
      case QualityLevel.low:
        currentLevel = QualityLevel.medium;
        break;
      case QualityLevel.medium:
        currentLevel = QualityLevel.high;
        break;
      case QualityLevel.high:
        currentLevel = QualityLevel.ultra;
        break;
      case QualityLevel.ultra:
        // Already at maximum
        break;
    }
  }

  void decreaseQuality() {
    switch (currentLevel) {
      case QualityLevel.ultra:
        currentLevel = QualityLevel.high;
        break;
      case QualityLevel.high:
        currentLevel = QualityLevel.medium;
        break;
      case QualityLevel.medium:
        currentLevel = QualityLevel.low;
        break;
      case QualityLevel.low:
        // Already at minimum
        break;
    }
  }
}

/// Quality levels with numeric values for comparison
enum QualityLevel {
  low(0),
  medium(1),
  high(2),
  ultra(3);

  final int value;
  const QualityLevel(this.value);

  bool operator >(QualityLevel other) => value > other.value;
  bool operator <(QualityLevel other) => value < other.value;
  bool operator >=(QualityLevel other) => value >= other.value;
  bool operator <=(QualityLevel other) => value <= other.value;
}

/// Performance metrics tracking
class PerformanceMetrics {
  final Queue<double> _frameTimes = Queue();
  final Map<EffectType, int> _effectCounts = {};
  double _totalTime = 0;
  int _frameCount = 0;

  void update(double dt, int particleCount, int effectCount) {
    _frameTimes.add(dt);
    if (_frameTimes.length > 60) {
      _frameTimes.removeFirst();
    }
    
    _totalTime += dt;
    _frameCount++;
  }

  void recordEffect(EffectType type) {
    _effectCounts[type] = (_effectCounts[type] ?? 0) + 1;
  }

  double get currentFps {
    if (_frameTimes.isEmpty) return 60;
    final averageFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    return averageFrameTime > 0 ? 1.0 / averageFrameTime : 60;
  }

  double get averageFps {
    if (_totalTime == 0) return 60;
    return _frameCount / _totalTime;
  }

  Map<EffectType, int> get effectCounts => Map.from(_effectCounts);

  void reset() {
    _frameTimes.clear();
    _effectCounts.clear();
    _totalTime = 0;
    _frameCount = 0;
  }
}

/// Debug overlay widget
class _DebugOverlay extends StatelessWidget {
  final EffectsController controller;
  final EffectsWorld world;

  const _DebugOverlay({
    required this.controller,
    required this.world,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Effects Debug',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Particles: ${world.activeParticleCount}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'Effects: ${world.activeEffectCount}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'FPS: ${world.performanceMetrics.currentFps.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'Quality: ${world.qualitySettings.currentLevel.name}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => controller.setEffectsEnabled(!controller.effectsEnabled),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                ),
                child: Text(
                  controller.effectsEnabled ? 'Disable' : 'Enable',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Effect definitions and presets

/// Base effect definition
abstract class EffectDefinition {
  final EffectType type;
  final Offset position;

  const EffectDefinition({
    required this.type,
    required this.position,
  });
}

/// Effect types
enum EffectType {
  celebration,
  piecePlacement,
  magneticPulse,
  touchRipple,
  glowHighlight,
  sparkleTrail,
}

/// Celebration effect definition
class CelebrationEffect extends EffectDefinition {
  final double intensity;

  const CelebrationEffect({
    required super.position,
    this.intensity = 1.0,
  }) : super(type: EffectType.celebration);
}

/// Piece placement effect definition
class PiecePlacementEffect extends EffectDefinition {
  final Color color;

  const PiecePlacementEffect({
    required super.position,
    this.color = Colors.blue,
  }) : super(type: EffectType.piecePlacement);
}

/// Magnetic pulse effect definition
class MagneticPulseEffect extends EffectDefinition {
  final Offset center;
  final double strength;
  final double radius;
  final double duration;

  const MagneticPulseEffect({
    required this.center,
    required this.strength,
    this.radius = 100,
    this.duration = 1.0,
  }) : super(
    type: EffectType.magneticPulse,
    position: center,
  );
}

/// Touch ripple effect definition
class TouchRippleEffect extends EffectDefinition {
  final double maxRadius;
  final double duration;
  final Color color;

  const TouchRippleEffect({
    required super.position,
    this.maxRadius = 50,
    this.duration = 0.5,
    this.color = Colors.white,
  }) : super(type: EffectType.touchRipple);
}

/// Glow highlight effect definition
class GlowHighlightEffect extends EffectDefinition {
  final double radius;
  final Color color;
  final double duration;
  final double pulseFrequency;

  const GlowHighlightEffect({
    required super.position,
    this.radius = 30,
    this.color = Colors.yellow,
    this.duration = 2.0,
    this.pulseFrequency = 2.0,
  }) : super(type: EffectType.glowHighlight);
}

/// Sparkle trail effect definition
class SparkleTrailEffect extends EffectDefinition {
  final List<Offset> points;
  final Color color;

  SparkleTrailEffect({
    required this.points,
    this.color = Colors.white,
  }) : super(
    type: EffectType.sparkleTrail,
    position: points.isNotEmpty ? points.first : Offset.zero,
  );
}

/// Magnetic source for field visualization
class MagneticSource {
  final Offset position;
  final double strength;
  final double radius;
  final Color color;

  const MagneticSource({
    required this.position,
    required this.strength,
    required this.radius,
    this.color = Colors.blue,
  });
}

/// Magnetic pulse for animated field effects
class MagneticPulse {
  final Offset center;
  final Color color;
  final double maxRadius;
  final double duration;
  double elapsed = 0;
  
  MagneticPulse({
    required this.center,
    required double strength,
    required double radius,
    required this.duration,
  }) : maxRadius = radius,
       color = Colors.blue.withOpacity(0.5);

  void update(double dt) {
    elapsed += dt;
  }

  bool get isActive => elapsed < duration;
  double get progress => elapsed / duration;
  double get currentRadius => maxRadius * progress;
  double get opacity => (1 - progress) * 0.5;
}

/// Field line for magnetic visualization
class FieldLine {
  final List<Offset> points;
  final double strength;
  final Color color;

  const FieldLine({
    required this.points,
    required this.strength,
    required this.color,
  });
}

/// Glow instance for tracking individual glows
class GlowInstance {
  final Offset position;
  final double radius;
  final Color color;
  final double duration;
  final double pulseFrequency;
  double elapsed = 0;
  double baseIntensity = 0.5;

  GlowInstance({
    required this.position,
    required this.radius,
    required this.color,
    required this.duration,
    this.pulseFrequency = 0,
  });

  void update(double dt) {
    elapsed += dt;
  }

  bool get isActive => elapsed < duration;
  double get remaining => duration - elapsed;
}

/// Effect presets for common scenarios
class EffectPresets {
  static const smallCelebration = CelebrationEffect(
    position: Offset.zero,
    intensity: 0.5,
  );

  static const mediumCelebration = CelebrationEffect(
    position: Offset.zero,
    intensity: 1.0,
  );

  static const largeCelebration = CelebrationEffect(
    position: Offset.zero,
    intensity: 2.0,
  );

  static const successPlacement = PiecePlacementEffect(
    position: Offset.zero,
    color: Colors.green,
  );

  static const magneticSnap = MagneticPulseEffect(
    center: Offset.zero,
    strength: 1.0,
    radius: 80,
    duration: 0.5,
  );

  static const touchFeedback = TouchRippleEffect(
    position: Offset.zero,
    maxRadius: 40,
    duration: 0.3,
    color: Colors.white70,
  );

  static const selectionGlow = GlowHighlightEffect(
    position: Offset.zero,
    radius: 35,
    color: Colors.amber,
    duration: 1.0,
    pulseFrequency: 2.0,
  );
}
