import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Import FeedbackIntensity from feedback_controller
import '../application/feedback_controller.dart' show FeedbackIntensity;

/// Represents a haptic pattern intensity
enum HapticIntensity {
  light(0.3),
  medium(0.6),
  heavy(1.0);

  final double value;
  const HapticIntensity(this.value);
}

/// Wave types for continuous patterns
enum WaveType {
  sine,
  square,
  sawtooth,
  triangle,
}

/// Represents a single haptic event
class HapticEvent {
  final Duration delay;
  final Duration duration;
  final double intensity;
  final WaveType? waveType;

  const HapticEvent({
    this.delay = Duration.zero,
    required this.duration,
    required this.intensity,
    this.waveType,
  });
}

/// Complex haptic pattern definition
class HapticPattern {
  final String name;
  final List<HapticEvent> events;
  final bool loop;
  final Duration? totalDuration;

  const HapticPattern({
    required this.name,
    required this.events,
    this.loop = false,
    this.totalDuration,
  });

  /// Calculate total pattern duration
  Duration get calculatedDuration {
    if (totalDuration != null) return totalDuration!;
    
    Duration total = Duration.zero;
    for (final event in events) {
      final eventEnd = event.delay + event.duration;
      if (eventEnd > total) {
        total = eventEnd;
      }
    }
    return total;
  }
}

/// Adaptive haptic pattern that changes based on input
class AdaptiveHapticPattern {
  final String name;
  final double Function(double input) intensityCurve;
  final Duration Function(double input) durationCurve;
  final WaveType Function(double input)? waveTypeCurve;

  const AdaptiveHapticPattern({
    required this.name,
    required this.intensityCurve,
    required this.durationCurve,
    this.waveTypeCurve,
  });

  /// Generate pattern based on input value
  HapticPattern generatePattern(double input) {
    final intensity = intensityCurve(input).clamp(0.0, 1.0);
    final duration = durationCurve(input);
    final waveType = waveTypeCurve?.call(input);

    return HapticPattern(
      name: '$name-${input.toStringAsFixed(2)}',
      events: [
        HapticEvent(
          duration: duration,
          intensity: intensity,
          waveType: waveType,
        ),
      ],
    );
  }
}

/// Main haptic pattern library
class HapticPatternLibrary {
  final bool testMode;
  Timer? _patternTimer;
  StreamController<HapticEvent>? _activePattern;
  
  // Platform-specific haptic engines
  static const MethodChannel _channel = MethodChannel('haptic_feedback');
  
  // Pattern definitions
  final Map<String, HapticPattern> _patterns = {};
  final Map<String, AdaptiveHapticPattern> _adaptivePatterns = {};
  
  // Analytics
  final Map<String, int> _patternPlayCounts = {};
  DateTime? _lastHapticTime;

  HapticPatternLibrary({this.testMode = false}) {
    _initializePatterns();
    _initializeAdaptivePatterns();
  }

  /// Initialize predefined patterns
  void _initializePatterns() {
    // Simple impact patterns
    _patterns['light_tap'] = const HapticPattern(
      name: 'light_tap',
      events: [
        HapticEvent(duration: Duration(milliseconds: 10), intensity: 0.3),
      ],
    );

    _patterns['medium_tap'] = const HapticPattern(
      name: 'medium_tap',
      events: [
        HapticEvent(duration: Duration(milliseconds: 15), intensity: 0.6),
      ],
    );

    _patterns['heavy_tap'] = const HapticPattern(
      name: 'heavy_tap',
      events: [
        HapticEvent(duration: Duration(milliseconds: 20), intensity: 1.0),
      ],
    );

    // Complex patterns
    _patterns['heartbeat'] = const HapticPattern(
      name: 'heartbeat',
      events: [
        HapticEvent(duration: Duration(milliseconds: 100), intensity: 0.8),
        HapticEvent(
          delay: Duration(milliseconds: 150),
          duration: Duration(milliseconds: 120),
          intensity: 1.0,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 500),
          duration: Duration(milliseconds: 100),
          intensity: 0.8,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 650),
          duration: Duration(milliseconds: 120),
          intensity: 1.0,
        ),
      ],
      loop: true,
      totalDuration: Duration(milliseconds: 1000),
    );

    _patterns['morse_sos'] = const HapticPattern(
      name: 'morse_sos',
      events: [
        // S (...)
        HapticEvent(duration: Duration(milliseconds: 50), intensity: 0.8),
        HapticEvent(
          delay: Duration(milliseconds: 100),
          duration: Duration(milliseconds: 50),
          intensity: 0.8,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 200),
          duration: Duration(milliseconds: 50),
          intensity: 0.8,
        ),
        // O (---)
        HapticEvent(
          delay: Duration(milliseconds: 400),
          duration: Duration(milliseconds: 150),
          intensity: 0.8,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 600),
          duration: Duration(milliseconds: 150),
          intensity: 0.8,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 800),
          duration: Duration(milliseconds: 150),
          intensity: 0.8,
        ),
        // S (...)
        HapticEvent(
          delay: Duration(milliseconds: 1100),
          duration: Duration(milliseconds: 50),
          intensity: 0.8,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 1200),
          duration: Duration(milliseconds: 50),
          intensity: 0.8,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 1300),
          duration: Duration(milliseconds: 50),
          intensity: 0.8,
        ),
      ],
    );

    _patterns['success'] = const HapticPattern(
      name: 'success',
      events: [
        HapticEvent(duration: Duration(milliseconds: 30), intensity: 0.4),
        HapticEvent(
          delay: Duration(milliseconds: 50),
          duration: Duration(milliseconds: 40),
          intensity: 0.6,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 110),
          duration: Duration(milliseconds: 60),
          intensity: 1.0,
        ),
      ],
    );

    _patterns['error'] = const HapticPattern(
      name: 'error',
      events: [
        HapticEvent(duration: Duration(milliseconds: 100), intensity: 1.0),
        HapticEvent(
          delay: Duration(milliseconds: 150),
          duration: Duration(milliseconds: 100),
          intensity: 1.0),
      ],
    );

    _patterns['warning'] = const HapticPattern(
      name: 'warning',
      events: [
        HapticEvent(duration: Duration(milliseconds: 200), intensity: 0.5),
        HapticEvent(
          delay: Duration(milliseconds: 250),
          duration: Duration(milliseconds: 200),
          intensity: 0.5,
        ),
      ],
    );

    // Musical patterns
    _patterns['musical_rise'] = const HapticPattern(
      name: 'musical_rise',
      events: [
        HapticEvent(duration: Duration(milliseconds: 50), intensity: 0.3),
        HapticEvent(
          delay: Duration(milliseconds: 70),
          duration: Duration(milliseconds: 50),
          intensity: 0.5,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 140),
          duration: Duration(milliseconds: 50),
          intensity: 0.7,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 210),
          duration: Duration(milliseconds: 80),
          intensity: 1.0,
        ),
      ],
    );

    _patterns['drumroll'] = const HapticPattern(
      name: 'drumroll',
      events: [
        HapticEvent(duration: Duration(milliseconds: 20), intensity: 0.5),
        HapticEvent(
          delay: Duration(milliseconds: 30),
          duration: Duration(milliseconds: 20),
          intensity: 0.5,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 60),
          duration: Duration(milliseconds: 20),
          intensity: 0.6,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 90),
          duration: Duration(milliseconds: 20),
          intensity: 0.7,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 120),
          duration: Duration(milliseconds: 20),
          intensity: 0.8,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 150),
          duration: Duration(milliseconds: 20),
          intensity: 0.9,
        ),
        HapticEvent(
          delay: Duration(milliseconds: 180),
          duration: Duration(milliseconds: 40),
          intensity: 1.0,
        ),
      ],
    );
  }

  /// Initialize adaptive patterns
  void _initializeAdaptivePatterns() {
    // Proximity-based pattern
    _adaptivePatterns['proximity'] = AdaptiveHapticPattern(
      name: 'proximity',
      intensityCurve: (distance) {
        // Intensity increases as distance decreases
        return math.pow(1.0 - distance, 2).toDouble();
      },
      durationCurve: (distance) {
        // Shorter pulses when very close
        final ms = (20 + distance * 100).round();
        return Duration(milliseconds: ms);
      },
      waveTypeCurve: (distance) {
        // Change wave type based on distance
        if (distance < 0.2) return WaveType.square;
        if (distance < 0.5) return WaveType.triangle;
        return WaveType.sine;
      },
    );

    // Speed-based pattern
    _adaptivePatterns['velocity'] = AdaptiveHapticPattern(
      name: 'velocity',
      intensityCurve: (speed) {
        // Normalize speed (0-1000) to intensity
        return (speed / 1000).clamp(0.1, 1.0);
      },
      durationCurve: (speed) {
        // Faster speed = shorter duration
        final ms = (200 - speed * 0.15).round().clamp(20, 200) as int;
        return Duration(milliseconds: ms);
      },
    );

    // Progress-based pattern
    _adaptivePatterns['progress'] = AdaptiveHapticPattern(
      name: 'progress',
      intensityCurve: (progress) {
        // Gentle increase with strong finish
        if (progress < 0.9) {
          return 0.3 + progress * 0.4;
        }
        return 1.0;
      },
      durationCurve: (progress) {
        if (progress >= 1.0) {
          return const Duration(milliseconds: 500); // Celebration
        }
        return const Duration(milliseconds: 50);
      },
    );
  }

  /// Play a simple impact
  Future<void> playImpact(HapticIntensity intensity) async {
    if (testMode) {
      _logHaptic('impact', intensity.value);
      return;
    }

    if (Platform.isIOS) {
      await HapticFeedback.mediumImpact();
    } else if (Platform.isAndroid) {
      await _playAndroidHaptic(intensity.value, const Duration(milliseconds: 20));
    }
  }

  /// Play continuous vibration
  Future<void> playContinuous({
    required FeedbackIntensity intensity,
    required Duration duration,
    WaveType waveType = WaveType.sine,
  }) async {
    if (testMode) {
      _logHaptic('continuous', intensity.value);
      return;
    }

    final pattern = HapticPattern(
      name: 'continuous',
      events: [
        HapticEvent(
          duration: duration,
          intensity: intensity.value,
          waveType: waveType,
        ),
      ],
    );

    await _playPattern(pattern);
  }

  /// Play pickup feedback
  Future<void> playPickup(FeedbackIntensity intensity) async {
    final patternName = intensity.value < 0.5 ? 'light_tap' : 'medium_tap';
    await playPattern(patternName, intensity);
  }

  /// Play magnetic feedback
  Future<void> playMagnetic({
    required double strength,
    required FeedbackIntensity intensity,
  }) async {
    final adaptive = _adaptivePatterns['proximity'];
    if (adaptive != null) {
      final pattern = adaptive.generatePattern(1.0 - strength);
      await _playPattern(pattern);
    }
  }

  /// Play success feedback
  Future<void> playSuccess(FeedbackIntensity intensity) async {
    await playPattern('success', intensity);
  }

  /// Play perfect placement feedback
  Future<void> playPerfectPlacement() async {
    await playPattern('musical_rise', FeedbackIntensity.maximum);
  }

  /// Play error feedback
  Future<void> playError() async {
    await playPattern('error', FeedbackIntensity.strong);
  }

  /// Play combo feedback
  Future<void> playCombo(int count, FeedbackIntensity intensity) async {
    // Create dynamic pattern based on combo count
    final events = <HapticEvent>[];
    for (int i = 0; i < math.min(count, 5); i++) {
      events.add(HapticEvent(
        delay: Duration(milliseconds: i * 50),
        duration: const Duration(milliseconds: 30),
        intensity: 0.5 + (i * 0.1),
      ));
    }
    
    final pattern = HapticPattern(
      name: 'combo-$count',
      events: events,
    );
    
    await _playPattern(pattern);
  }

  /// Play celebration pattern
  Future<void> playCelebration(String type, FeedbackIntensity intensity) async {
    switch (type) {
      case 'section_complete':
        await playPattern('drumroll', intensity);
        break;
      case 'puzzle_complete':
        await _playComplexCelebration();
        break;
      default:
        await playPattern('success', intensity);
    }
  }

  /// Play achievement unlock
  Future<void> playAchievement() async {
    // Special pattern for achievements
    final pattern = HapticPattern(
      name: 'achievement',
      events: [
        const HapticEvent(duration: Duration(milliseconds: 50), intensity: 0.5),
        const HapticEvent(
          delay: Duration(milliseconds: 100),
          duration: Duration(milliseconds: 50),
          intensity: 0.7,
        ),
        const HapticEvent(
          delay: Duration(milliseconds: 200),
          duration: Duration(milliseconds: 100),
          intensity: 1.0,
        ),
        const HapticEvent(
          delay: Duration(milliseconds: 350),
          duration: Duration(milliseconds: 30),
          intensity: 0.8,
        ),
        const HapticEvent(
          delay: Duration(milliseconds: 400),
          duration: Duration(milliseconds: 30),
          intensity: 0.8,
        ),
      ],
    );
    
    await _playPattern(pattern);
  }

  /// Play a named pattern
  Future<void> playPattern(String name, FeedbackIntensity intensity) async {
    final pattern = _patterns[name];
    if (pattern == null) {
      debugPrint('Haptic pattern not found: $name');
      return;
    }

    // Adjust pattern intensity
    final adjustedPattern = _adjustPatternIntensity(pattern, intensity.value);
    await _playPattern(adjustedPattern);
    
    // Analytics
    _patternPlayCounts[name] = (_patternPlayCounts[name] ?? 0) + 1;
  }

  /// Play a complex celebration
  Future<void> _playComplexCelebration() async {
    final pattern = HapticPattern(
      name: 'complex_celebration',
      events: List.generate(10, (i) {
        final delay = i * 100;
        final intensity = 0.5 + (math.sin(i * 0.5) * 0.5);
        return HapticEvent(
          delay: Duration(milliseconds: delay),
          duration: const Duration(milliseconds: 50),
          intensity: intensity.clamp(0.3, 1.0),
        );
      }),
    );
    
    await _playPattern(pattern);
  }

  /// Internal pattern player
  Future<void> _playPattern(HapticPattern pattern) async {
    if (testMode) {
      _logHaptic(pattern.name, pattern.events.length.toDouble());
      return;
    }

    // Cancel any active pattern
    _patternTimer?.cancel();
    _activePattern?.close();
    
    _activePattern = StreamController<HapticEvent>();
    
    // Schedule events
    for (final event in pattern.events) {
      Timer(event.delay, () async {
        if (_activePattern?.isClosed ?? true) return;
        
        if (Platform.isIOS) {
          await _playIOSHaptic(event);
        } else if (Platform.isAndroid) {
          await _playAndroidHaptic(event.intensity, event.duration);
        }
        
        _activePattern?.add(event);
      });
    }

    // Handle looping
    if (pattern.loop) {
      _patternTimer = Timer.periodic(pattern.calculatedDuration, (_) {
        _playPattern(pattern);
      });
    }

    _lastHapticTime = DateTime.now();
  }

  /// Play iOS haptic
  Future<void> _playIOSHaptic(HapticEvent event) async {
    // Use Taptic Engine
    if (event.intensity < 0.4) {
      await HapticFeedback.lightImpact();
    } else if (event.intensity < 0.7) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Play Android haptic
  Future<void> _playAndroidHaptic(double intensity, Duration duration) async {
    // Use VibrationEffect API
    try {
      await _channel.invokeMethod('vibrate', {
        'duration': duration.inMilliseconds,
        'amplitude': (intensity * 255).round(),
      });
    } catch (e) {
      // Fallback to standard vibration
      await HapticFeedback.vibrate();
    }
  }

  /// Adjust pattern intensity
  HapticPattern _adjustPatternIntensity(HapticPattern pattern, double multiplier) {
    return HapticPattern(
      name: pattern.name,
      events: pattern.events.map((event) {
        return HapticEvent(
          delay: event.delay,
          duration: event.duration,
          intensity: (event.intensity * multiplier).clamp(0.0, 1.0),
          waveType: event.waveType,
        );
      }).toList(),
      loop: pattern.loop,
      totalDuration: pattern.totalDuration,
    );
  }

  /// Stop all active patterns
  void stopAll() {
    _patternTimer?.cancel();
    _activePattern?.close();
    _patternTimer = null;
    _activePattern = null;
  }

  /// Log haptic for testing
  void _logHaptic(String type, double value) {
    if (testMode) {
      debugPrint('Haptic: $type with value $value');
    }
  }

  /// Get analytics data
  Map<String, dynamic> getAnalytics() {
    return {
      'patternCounts': Map.from(_patternPlayCounts),
      'totalPatterns': _patterns.length,
      'lastHapticTime': _lastHapticTime?.toIso8601String(),
    };
  }

  /// Create custom pattern
  void addCustomPattern(HapticPattern pattern) {
    _patterns[pattern.name] = pattern;
  }

  /// Test pattern (for development)
  Future<void> testPattern(String name) async {
    final pattern = _patterns[name];
    if (pattern != null) {
      debugPrint('Testing pattern: $name');
      await _playPattern(pattern);
    }
  }

  /// Dispose resources
  void dispose() {
    stopAll();
  }
}

