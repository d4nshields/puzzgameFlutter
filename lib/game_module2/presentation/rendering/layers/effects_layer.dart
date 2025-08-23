part of '../hybrid_renderer.dart';

/// Controller for the effects layer
class EffectsLayerController extends ChangeNotifier {
  final CoordinateSystem coordinateSystem;
  final QualityManager qualityManager;
  
  final List<ParticleEffect> _activeEffects = [];
  final Map<String, ContinuousEffect> _continuousEffects = {};
  Timer? _updateTimer;

  EffectsLayerController({
    required this.coordinateSystem,
    required this.qualityManager,
  }) {
    _startUpdateLoop();
  }

  void _startUpdateLoop() {
    _updateTimer = Timer.periodic(
      const Duration(milliseconds: 16), // 60 FPS
      (_) => update(),
    );
  }

  void triggerEffect(ParticleEffect effect) {
    if (!qualityManager.currentQuality.enableParticles) return;
    
    _activeEffects.add(effect);
    notifyListeners();
    
    // Auto-remove after duration
    Future.delayed(effect.duration, () {
      _activeEffects.remove(effect);
      notifyListeners();
    });
  }

  String startContinuousEffect(ContinuousEffect effect) {
    if (!qualityManager.currentQuality.enableParticles) {
      return '';
    }
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _continuousEffects[id] = effect;
    notifyListeners();
    return id;
  }

  void stopContinuousEffect(String id) {
    _continuousEffects.remove(id);
    notifyListeners();
  }

  void update() {
    // Update all active effects
    bool needsRepaint = false;
    
    for (final effect in _activeEffects) {
      effect.update(0.016); // 16ms frame time
      needsRepaint = true;
    }
    
    for (final effect in _continuousEffects.values) {
      effect.update(0.016);
      needsRepaint = true;
    }
    
    if (needsRepaint) {
      notifyListeners();
    }
  }

  List<ParticleEffect> get activeEffects => _activeEffects;
  Map<String, ContinuousEffect> get continuousEffects => _continuousEffects;

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Effects layer widget
class EffectsLayer extends StatelessWidget {
  final EffectsLayerController controller;
  final Size size;
  final QualityLevel quality;

  const EffectsLayer({
    super.key,
    required this.controller,
    required this.size,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    if (!quality.enableParticles) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          size: size,
          painter: EffectsPainter(
            activeEffects: controller.activeEffects,
            continuousEffects: controller.continuousEffects,
            quality: quality,
          ),
        );
      },
    );
  }
}

/// Custom painter for particle effects
class EffectsPainter extends CustomPainter {
  final List<ParticleEffect> activeEffects;
  final Map<String, ContinuousEffect> continuousEffects;
  final QualityLevel quality;

  const EffectsPainter({
    required this.activeEffects,
    required this.continuousEffects,
    required this.quality,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw continuous effects first (background)
    for (final effect in continuousEffects.values) {
      _drawContinuousEffect(canvas, size, effect);
    }

    // Draw particle effects
    for (final effect in activeEffects) {
      _drawParticleEffect(canvas, size, effect);
    }
  }

  void _drawParticleEffect(Canvas canvas, Size size, ParticleEffect effect) {
    switch (effect.type) {
      case ParticleEffectType.burst:
        _drawBurstEffect(canvas, effect as BurstEffect);
        break;
      case ParticleEffectType.fountain:
        _drawFountainEffect(canvas, effect as FountainEffect);
        break;
      case ParticleEffectType.celebration:
        _drawCelebrationEffect(canvas, effect as CelebrationEffect);
        break;
    }
  }

  void _drawBurstEffect(Canvas canvas, BurstEffect effect) {
    for (final particle in effect.particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        particle.position,
        particle.size * quality.resolutionScale,
        paint,
      );
    }
  }

  void _drawFountainEffect(Canvas canvas, FountainEffect effect) {
    for (final particle in effect.particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      // Draw particle with trail
      final path = Path()
        ..moveTo(particle.position.dx, particle.position.dy)
        ..lineTo(
          particle.position.dx - particle.velocity.dx * 0.1,
          particle.position.dy - particle.velocity.dy * 0.1,
        );

      canvas.drawPath(
        path,
        Paint()
          ..color = particle.color.withOpacity(particle.opacity * 0.5)
          ..strokeWidth = particle.size * quality.resolutionScale
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      canvas.drawCircle(
        particle.position,
        particle.size * quality.resolutionScale,
        paint,
      );
    }
  }

  void _drawCelebrationEffect(Canvas canvas, CelebrationEffect effect) {
    for (final confetti in effect.confettiPieces) {
      final paint = Paint()
        ..color = confetti.color.withOpacity(confetti.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(confetti.position.dx, confetti.position.dy);
      canvas.rotate(confetti.rotation);

      // Draw confetti shape
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: confetti.size.width * quality.resolutionScale,
        height: confetti.size.height * quality.resolutionScale,
      );

      canvas.drawRect(rect, paint);
      canvas.restore();
    }
  }

  void _drawContinuousEffect(Canvas canvas, Size size, ContinuousEffect effect) {
    switch (effect.type) {
      case ContinuousEffectType.magneticField:
        _drawMagneticFieldEffect(canvas, size, effect as MagneticFieldEffect);
        break;
      case ContinuousEffectType.glow:
        _drawGlowEffect(canvas, effect as GlowEffect);
        break;
      case ContinuousEffectType.trail:
        _drawTrailEffect(canvas, effect as TrailEffect);
        break;
    }
  }

  void _drawMagneticFieldEffect(
    Canvas canvas,
    Size size,
    MagneticFieldEffect effect,
  ) {
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * quality.resolutionScale;

    // Draw field lines
    for (final line in effect.fieldLines) {
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

      // Animate opacity based on line phase
      paint.color = Colors.blueAccent.withOpacity(
        0.1 + 0.1 * math.sin(line.phase),
      );
      
      canvas.drawPath(path, paint);
    }
  }

  void _drawGlowEffect(Canvas canvas, GlowEffect effect) {
    final paint = Paint()
      ..color = effect.color.withOpacity(effect.intensity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        effect.radius * quality.resolutionScale,
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(effect.position, effect.radius, paint);
  }

  void _drawTrailEffect(Canvas canvas, TrailEffect effect) {
    if (effect.points.isEmpty) return;

    final path = Path();
    path.moveTo(effect.points.first.dx, effect.points.first.dy);

    for (int i = 1; i < effect.points.length; i++) {
      final point = effect.points[i];
      final prevPoint = effect.points[i - 1];
      
      // Use quadratic bezier for smooth curves
      final controlPoint = Offset(
        (prevPoint.dx + point.dx) / 2,
        (prevPoint.dy + point.dy) / 2,
      );
      
      path.quadraticBezierTo(
        controlPoint.dx,
        controlPoint.dy,
        point.dx,
        point.dy,
      );
    }

    // Draw with gradient opacity
    for (int i = 0; i < effect.points.length - 1; i++) {
      final opacity = (i / effect.points.length) * effect.maxOpacity;
      final paint = Paint()
        ..color = effect.color.withOpacity(opacity)
        ..strokeWidth = effect.width * quality.resolutionScale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final segment = Path();
      segment.moveTo(effect.points[i].dx, effect.points[i].dy);
      segment.lineTo(effect.points[i + 1].dx, effect.points[i + 1].dy);
      
      canvas.drawPath(segment, paint);
    }
  }

  @override
  bool shouldRepaint(EffectsPainter oldDelegate) {
    return true; // Always repaint for smooth animations
  }
}

/// Base class for particle effects
abstract class ParticleEffect {
  final ParticleEffectType type;
  final Offset position;
  final Duration duration;

  ParticleEffect({
    required this.type,
    required this.position,
    required this.duration,
  });

  void update(double deltaTime);
}

/// Types of particle effects
enum ParticleEffectType {
  burst,
  fountain,
  celebration,
}

/// Burst effect with particles exploding outward
class BurstEffect extends ParticleEffect {
  final List<Particle> particles = [];
  final int particleCount;
  final List<Color> colors;
  final double speed;

  BurstEffect({
    required super.position,
    super.duration = const Duration(milliseconds: 500),
    this.particleCount = 20,
    List<Color>? colors,
    this.speed = 100,
  })  : colors = colors ?? [Colors.yellow, Colors.orange],
        super(type: ParticleEffectType.burst) {
    _initializeParticles();
  }

  void _initializeParticles() {
    final random = math.Random();
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final velocity = Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );
      
      particles.add(Particle(
        position: position,
        velocity: velocity,
        color: colors[random.nextInt(colors.length)],
        size: random.nextDouble() * 3 + 2,
        opacity: 1.0,
      ));
    }
  }

  @override
  void update(double deltaTime) {
    for (final particle in particles) {
      particle.position += particle.velocity * deltaTime;
      particle.velocity *= 0.98; // Damping
      particle.opacity = math.max(0, particle.opacity - deltaTime * 2);
    }
  }
}

/// Fountain effect with continuous particle stream
class FountainEffect extends ParticleEffect {
  final List<Particle> particles = [];
  final double emissionRate;
  final double spreadAngle;
  double _timeSinceLastEmission = 0;

  FountainEffect({
    required super.position,
    super.duration = const Duration(seconds: 2),
    this.emissionRate = 30,
    this.spreadAngle = math.pi / 4,
  }) : super(type: ParticleEffectType.fountain);

  @override
  void update(double deltaTime) {
    _timeSinceLastEmission += deltaTime;
    
    // Emit new particles
    while (_timeSinceLastEmission > 1 / emissionRate) {
      _emitParticle();
      _timeSinceLastEmission -= 1 / emissionRate;
    }

    // Update existing particles
    particles.removeWhere((particle) {
      particle.position += particle.velocity * deltaTime;
      particle.velocity += const Offset(0, 200) * deltaTime; // Gravity
      particle.opacity = math.max(0, particle.opacity - deltaTime);
      return particle.opacity <= 0;
    });
  }

  void _emitParticle() {
    final random = math.Random();
    final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * spreadAngle;
    final speed = random.nextDouble() * 50 + 100;
    
    particles.add(Particle(
      position: position,
      velocity: Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      ),
      color: Colors.blueAccent,
      size: random.nextDouble() * 2 + 1,
      opacity: 1.0,
    ));
  }
}

/// Celebration effect with confetti
class CelebrationEffect extends ParticleEffect {
  final List<ConfettiPiece> confettiPieces = [];

  CelebrationEffect({
    required super.position,
    super.duration = const Duration(seconds: 3),
  }) : super(type: ParticleEffectType.celebration) {
    _initializeConfetti();
  }

  void _initializeConfetti() {
    final random = math.Random();
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
    ];

    for (int i = 0; i < 50; i++) {
      confettiPieces.add(ConfettiPiece(
        position: position + Offset(
          (random.nextDouble() - 0.5) * 100,
          (random.nextDouble() - 0.5) * 100,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 200,
          -random.nextDouble() * 300 - 100,
        ),
        color: colors[random.nextInt(colors.length)],
        size: Size(
          random.nextDouble() * 10 + 5,
          random.nextDouble() * 5 + 2,
        ),
        rotation: random.nextDouble() * 2 * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 10,
        opacity: 1.0,
      ));
    }
  }

  @override
  void update(double deltaTime) {
    for (final piece in confettiPieces) {
      piece.position += piece.velocity * deltaTime;
      piece.velocity += const Offset(0, 300) * deltaTime; // Gravity
      piece.rotation += piece.rotationSpeed * deltaTime;
      piece.opacity = math.max(0, piece.opacity - deltaTime * 0.5);
    }
  }
}

/// Base class for continuous effects
abstract class ContinuousEffect {
  final ContinuousEffectType type;

  ContinuousEffect({required this.type});

  void update(double deltaTime);
}

/// Types of continuous effects
enum ContinuousEffectType {
  magneticField,
  glow,
  trail,
}

/// Magnetic field visualization effect
class MagneticFieldEffect extends ContinuousEffect {
  final List<FieldLine> fieldLines = [];
  final Offset center;
  final double radius;

  MagneticFieldEffect({
    required this.center,
    required this.radius,
  }) : super(type: ContinuousEffectType.magneticField) {
    _initializeFieldLines();
  }

  void _initializeFieldLines() {
    const lineCount = 12;
    for (int i = 0; i < lineCount; i++) {
      final angle = (i / lineCount) * 2 * math.pi;
      final line = FieldLine(
        points: _generateFieldLinePoints(angle),
        phase: i * 0.5,
      );
      fieldLines.add(line);
    }
  }

  List<Offset> _generateFieldLinePoints(double startAngle) {
    final points = <Offset>[];
    const steps = 20;
    
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final r = radius * (0.2 + t * 0.8);
      final angle = startAngle + t * 0.3 * math.sin(t * math.pi);
      
      points.add(Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      ));
    }
    
    return points;
  }

  @override
  void update(double deltaTime) {
    for (final line in fieldLines) {
      line.phase += deltaTime * 2;
      if (line.phase > 2 * math.pi) {
        line.phase -= 2 * math.pi;
      }
    }
  }
}

/// Glow effect
class GlowEffect extends ContinuousEffect {
  final Offset position;
  final Color color;
  double intensity;
  final double radius;
  double _time = 0;

  GlowEffect({
    required this.position,
    required this.color,
    this.intensity = 0.5,
    this.radius = 20,
  }) : super(type: ContinuousEffectType.glow);

  @override
  void update(double deltaTime) {
    _time += deltaTime;
    intensity = 0.3 + 0.2 * math.sin(_time * 2);
  }
}

/// Trail effect
class TrailEffect extends ContinuousEffect {
  final List<Offset> points = [];
  final Color color;
  final double width;
  final double maxOpacity;
  final int maxPoints;

  TrailEffect({
    required this.color,
    this.width = 3,
    this.maxOpacity = 0.8,
    this.maxPoints = 20,
  }) : super(type: ContinuousEffectType.trail);

  void addPoint(Offset point) {
    points.add(point);
    if (points.length > maxPoints) {
      points.removeAt(0);
    }
  }

  @override
  void update(double deltaTime) {
    // Trail naturally fades, no update needed
  }
}

/// Individual particle data
class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
  });
}

/// Confetti piece data
class ConfettiPiece {
  Offset position;
  Offset velocity;
  Color color;
  Size size;
  double rotation;
  double rotationSpeed;
  double opacity;

  ConfettiPiece({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.opacity,
  });
}

/// Field line data
class FieldLine {
  final List<Offset> points;
  double phase;

  FieldLine({
    required this.points,
    required this.phase,
  });
}