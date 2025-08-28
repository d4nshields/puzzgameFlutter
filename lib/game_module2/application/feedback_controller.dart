import 'dart:async';
import '../domain/services/piece_state_machine.dart';
import '../infrastructure/haptic_patterns.dart';

/// Represents a feedback channel type
enum FeedbackChannel {
  haptic,
  audio,
  visual,
  accessibility,
}

/// Feedback intensity levels
enum FeedbackIntensity {
  subtle(0.3),
  light(0.5),
  medium(0.7),
  strong(0.9),
  maximum(1.0);

  final double value;
  const FeedbackIntensity(this.value);
}

/// Context for feedback decisions
class FeedbackContext {
  final PieceStateType? pieceState;
  final double? proximity;
  final bool isCorrectPosition;
  final int? comboCount;
  final Duration? timeInState;
  final Map<String, dynamic> metadata;

  FeedbackContext({
    this.pieceState,
    this.proximity,
    this.isCorrectPosition = false,
    this.comboCount,
    this.timeInState,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};
}

/// Feedback event that can be recorded and played back
class FeedbackEvent {
  final DateTime timestamp;
  final FeedbackChannel channel;
  final String pattern;
  final FeedbackIntensity intensity;
  final FeedbackContext context;
  final Duration? duration;

  FeedbackEvent({
    DateTime? timestamp,
    required this.channel,
    required this.pattern,
    required this.intensity,
    required this.context,
    this.duration,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'channel': channel.toString(),
    'pattern': pattern,
    'intensity': intensity.value,
    'context': {
      'pieceState': context.pieceState?.toString(),
      'proximity': context.proximity,
      'isCorrectPosition': context.isCorrectPosition,
      'comboCount': context.comboCount,
      'timeInState': context.timeInState?.inMilliseconds,
      'metadata': context.metadata,
    },
    'duration': duration?.inMilliseconds,
  };
}

/// User preferences for feedback
class FeedbackPreferences {
  final Map<FeedbackChannel, bool> channelEnabled;
  final Map<FeedbackChannel, double> channelIntensity;
  final bool reducedMotion;
  final bool highContrast;
  final bool screenReaderEnabled;

  FeedbackPreferences({
    Map<FeedbackChannel, bool>? channelEnabled,
    Map<FeedbackChannel, double>? channelIntensity,
    this.reducedMotion = false,
    this.highContrast = false,
    this.screenReaderEnabled = false,
  })  : channelEnabled = channelEnabled ?? {
          FeedbackChannel.haptic: true,
          FeedbackChannel.audio: true,
          FeedbackChannel.visual: true,
          FeedbackChannel.accessibility: true,
        },
        channelIntensity = channelIntensity ?? {
          FeedbackChannel.haptic: 1.0,
          FeedbackChannel.audio: 0.7,
          FeedbackChannel.visual: 1.0,
          FeedbackChannel.accessibility: 1.0,
        };

  FeedbackPreferences copyWith({
    Map<FeedbackChannel, bool>? channelEnabled,
    Map<FeedbackChannel, double>? channelIntensity,
    bool? reducedMotion,
    bool? highContrast,
    bool? screenReaderEnabled,
  }) {
    return FeedbackPreferences(
      channelEnabled: channelEnabled ?? this.channelEnabled,
      channelIntensity: channelIntensity ?? this.channelIntensity,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      highContrast: highContrast ?? this.highContrast,
      screenReaderEnabled: screenReaderEnabled ?? this.screenReaderEnabled,
    );
  }
}

/// Main feedback controller that orchestrates multi-channel feedback
class FeedbackController {
  final HapticPatternLibrary _hapticLibrary;
  final List<FeedbackEvent> _eventHistory = [];
  final StreamController<FeedbackEvent> _feedbackStream = 
      StreamController<FeedbackEvent>.broadcast();
  
  FeedbackPreferences _preferences = FeedbackPreferences();
  bool _recordingEnabled = false;
  final int _maxHistorySize = 1000;
  
  // Callbacks for different channels
  Function(String pattern, double intensity)? onAudioFeedback;
  Function(String effect, FeedbackIntensity intensity)? onVisualFeedback;
  Function(String announcement)? onAccessibilityFeedback;
  
  // Analytics
  final Map<String, int> _patternCounts = {};
  final Map<FeedbackChannel, int> _channelCounts = {};
  
  FeedbackController({
    HapticPatternLibrary? hapticLibrary,
    FeedbackPreferences? preferences,
  })  : _hapticLibrary = hapticLibrary ?? HapticPatternLibrary(),
        _preferences = preferences ?? FeedbackPreferences();

  /// Stream of feedback events
  Stream<FeedbackEvent> get feedbackStream => _feedbackStream.stream;

  /// Current user preferences
  FeedbackPreferences get preferences => _preferences;

  /// Update user preferences
  void updatePreferences(FeedbackPreferences preferences) {
    _preferences = preferences;
  }

  /// Enable or disable recording
  void setRecording(bool enabled) {
    _recordingEnabled = enabled;
    if (!enabled) {
      _eventHistory.clear();
    }
  }

  /// Trigger feedback for piece pickup
  Future<void> piecePickup({
    required String pieceId,
    FeedbackIntensity intensity = FeedbackIntensity.medium,
  }) async {
    final context = FeedbackContext(
      pieceState: PieceStateType.selected,
      metadata: {'pieceId': pieceId},
    );

    await _triggerMultiChannel(
      pattern: 'piece_pickup',
      baseIntensity: intensity,
      context: context,
      hapticPattern: () => _hapticLibrary.playPickup(intensity),
      audioPattern: 'pickup_sound',
      visualPattern: 'pickup_glow',
      accessibilityAnnouncement: 'Piece picked up',
    );
  }

  /// Trigger feedback for dragging
  Future<void> pieceDrag({
    required String pieceId,
    required double velocity,
    double? proximityToCorrect,
  }) async {
    // Adaptive intensity based on velocity
    final intensity = _calculateDragIntensity(velocity);
    
    final context = FeedbackContext(
      pieceState: PieceStateType.dragging,
      proximity: proximityToCorrect,
      metadata: {
        'pieceId': pieceId,
        'velocity': velocity,
      },
    );

    // Continuous haptic feedback for drag
    if (_shouldTriggerChannel(FeedbackChannel.haptic)) {
      await _hapticLibrary.playContinuous(
        intensity: intensity,
        duration: const Duration(milliseconds: 50),
      );
    }

    _recordEvent(FeedbackEvent(
      channel: FeedbackChannel.haptic,
      pattern: 'drag_continuous',
      intensity: intensity,
      context: context,
    ));
  }

  /// Trigger feedback for near-snap indication
  Future<void> nearSnap({
    required String pieceId,
    required double proximity,
  }) async {
    // Intensity increases as piece gets closer
    final intensity = _calculateProximityIntensity(proximity);
    
    final context = FeedbackContext(
      pieceState: PieceStateType.magnetized,
      proximity: proximity,
      metadata: {'pieceId': pieceId},
    );

    await _triggerMultiChannel(
      pattern: 'near_snap',
      baseIntensity: intensity,
      context: context,
      hapticPattern: () => _hapticLibrary.playMagnetic(
        strength: proximity,
        intensity: intensity,
      ),
      audioPattern: 'magnetic_hum',
      visualPattern: 'magnetic_glow',
      accessibilityAnnouncement: proximity < 0.3 
          ? 'Very close to correct position'
          : 'Near correct position',
    );
  }

  /// Trigger feedback for successful placement
  Future<void> successfulPlacement({
    required String pieceId,
    int? comboCount,
    bool isPerfectPlacement = false,
  }) async {
    final intensity = isPerfectPlacement 
        ? FeedbackIntensity.maximum 
        : FeedbackIntensity.strong;
    
    final context = FeedbackContext(
      pieceState: PieceStateType.placed,
      isCorrectPosition: true,
      comboCount: comboCount,
      metadata: {
        'pieceId': pieceId,
        'isPerfect': isPerfectPlacement,
      },
    );

    await _triggerMultiChannel(
      pattern: 'successful_placement',
      baseIntensity: intensity,
      context: context,
      hapticPattern: () => isPerfectPlacement
          ? _hapticLibrary.playPerfectPlacement()
          : _hapticLibrary.playSuccess(intensity),
      audioPattern: isPerfectPlacement ? 'perfect_place' : 'success_place',
      visualPattern: 'placement_burst',
      accessibilityAnnouncement: isPerfectPlacement
          ? 'Perfect placement!'
          : 'Piece placed correctly',
    );

    // Combo feedback
    if (comboCount != null && comboCount > 1) {
      await _playComboFeedback(comboCount);
    }
  }

  /// Trigger feedback for invalid placement
  Future<void> invalidPlacement({
    required String pieceId,
    String reason = 'incorrect_position',
  }) async {
    final context = FeedbackContext(
      pieceState: PieceStateType.invalid,
      isCorrectPosition: false,
      metadata: {
        'pieceId': pieceId,
        'reason': reason,
      },
    );

    await _triggerMultiChannel(
      pattern: 'invalid_placement',
      baseIntensity: FeedbackIntensity.light,
      context: context,
      hapticPattern: () => _hapticLibrary.playError(),
      audioPattern: 'error_sound',
      visualPattern: 'error_shake',
      accessibilityAnnouncement: 'Incorrect position',
    );
  }

  /// Trigger celebration feedback
  Future<void> celebration({
    required String type,
    FeedbackIntensity intensity = FeedbackIntensity.maximum,
  }) async {
    final context = FeedbackContext(
      pieceState: PieceStateType.celebrating,
      metadata: {'celebrationType': type},
    );

    await _triggerMultiChannel(
      pattern: 'celebration_$type',
      baseIntensity: intensity,
      context: context,
      hapticPattern: () => _hapticLibrary.playCelebration(type, intensity),
      audioPattern: 'celebration_$type',
      visualPattern: 'celebration_$type',
      accessibilityAnnouncement: _getCelebrationAnnouncement(type),
    );
  }

  /// Trigger achievement unlock feedback
  Future<void> achievementUnlock({
    required String achievementId,
    required String title,
  }) async {
    final context = FeedbackContext(
      metadata: {
        'achievementId': achievementId,
        'title': title,
      },
    );

    await _triggerMultiChannel(
      pattern: 'achievement_unlock',
      baseIntensity: FeedbackIntensity.maximum,
      context: context,
      hapticPattern: () => _hapticLibrary.playAchievement(),
      audioPattern: 'achievement_sound',
      visualPattern: 'achievement_animation',
      accessibilityAnnouncement: 'Achievement unlocked: $title',
    );
  }

  /// Play combo feedback
  Future<void> _playComboFeedback(int comboCount) async {
    final intensity = _calculateComboIntensity(comboCount);
    
    if (_shouldTriggerChannel(FeedbackChannel.haptic)) {
      await _hapticLibrary.playCombo(comboCount, intensity);
    }

    if (_shouldTriggerChannel(FeedbackChannel.audio)) {
      onAudioFeedback?.call('combo_$comboCount', intensity.value);
    }
  }

  /// Trigger synchronized multi-channel feedback
  Future<void> _triggerMultiChannel({
    required String pattern,
    required FeedbackIntensity baseIntensity,
    required FeedbackContext context,
    required Future<void> Function() hapticPattern,
    required String audioPattern,
    required String visualPattern,
    required String accessibilityAnnouncement,
  }) async {
    final futures = <Future<void>>[];

    // Haptic feedback
    if (_shouldTriggerChannel(FeedbackChannel.haptic)) {
      futures.add(hapticPattern());
      _recordEvent(FeedbackEvent(
        channel: FeedbackChannel.haptic,
        pattern: pattern,
        intensity: baseIntensity,
        context: context,
      ));
    }

    // Audio feedback
    if (_shouldTriggerChannel(FeedbackChannel.audio)) {
      final audioIntensity = _adjustIntensity(baseIntensity, FeedbackChannel.audio);
      onAudioFeedback?.call(audioPattern, audioIntensity);
      _recordEvent(FeedbackEvent(
        channel: FeedbackChannel.audio,
        pattern: audioPattern,
        intensity: baseIntensity,
        context: context,
      ));
    }

    // Visual feedback (respecting reduced motion)
    if (_shouldTriggerChannel(FeedbackChannel.visual) && !_preferences.reducedMotion) {
      onVisualFeedback?.call(visualPattern, baseIntensity);
      _recordEvent(FeedbackEvent(
        channel: FeedbackChannel.visual,
        pattern: visualPattern,
        intensity: baseIntensity,
        context: context,
      ));
    }

    // Accessibility feedback
    if (_shouldTriggerChannel(FeedbackChannel.accessibility)) {
      onAccessibilityFeedback?.call(accessibilityAnnouncement);
      _recordEvent(FeedbackEvent(
        channel: FeedbackChannel.accessibility,
        pattern: 'announcement',
        intensity: FeedbackIntensity.medium,
        context: context,
      ));
    }

    // Update analytics
    _patternCounts[pattern] = (_patternCounts[pattern] ?? 0) + 1;

    await Future.wait(futures);
  }

  /// Check if a channel should be triggered
  bool _shouldTriggerChannel(FeedbackChannel channel) {
    return _preferences.channelEnabled[channel] ?? false;
  }

  /// Adjust intensity based on user preferences
  double _adjustIntensity(FeedbackIntensity base, FeedbackChannel channel) {
    final channelMultiplier = _preferences.channelIntensity[channel] ?? 1.0;
    return base.value * channelMultiplier;
  }

  /// Calculate intensity based on drag velocity
  FeedbackIntensity _calculateDragIntensity(double velocity) {
    if (velocity < 100) return FeedbackIntensity.subtle;
    if (velocity < 300) return FeedbackIntensity.light;
    if (velocity < 600) return FeedbackIntensity.medium;
    if (velocity < 1000) return FeedbackIntensity.strong;
    return FeedbackIntensity.maximum;
  }

  /// Calculate intensity based on proximity
  FeedbackIntensity _calculateProximityIntensity(double proximity) {
    if (proximity > 0.7) return FeedbackIntensity.subtle;
    if (proximity > 0.5) return FeedbackIntensity.light;
    if (proximity > 0.3) return FeedbackIntensity.medium;
    if (proximity > 0.1) return FeedbackIntensity.strong;
    return FeedbackIntensity.maximum;
  }

  /// Calculate intensity based on combo count
  FeedbackIntensity _calculateComboIntensity(int count) {
    if (count < 3) return FeedbackIntensity.light;
    if (count < 5) return FeedbackIntensity.medium;
    if (count < 10) return FeedbackIntensity.strong;
    return FeedbackIntensity.maximum;
  }

  /// Get celebration announcement text
  String _getCelebrationAnnouncement(String type) {
    switch (type) {
      case 'section_complete':
        return 'Section completed!';
      case 'puzzle_complete':
        return 'Puzzle completed! Congratulations!';
      case 'speed_bonus':
        return 'Speed bonus achieved!';
      case 'perfect_score':
        return 'Perfect score!';
      default:
        return 'Celebration!';
    }
  }

  /// Record a feedback event
  void _recordEvent(FeedbackEvent event) {
    if (_recordingEnabled) {
      _eventHistory.add(event);
      if (_eventHistory.length > _maxHistorySize) {
        _eventHistory.removeAt(0);
      }
    }
    
    _feedbackStream.add(event);
    _channelCounts[event.channel] = (_channelCounts[event.channel] ?? 0) + 1;
  }

  /// Get feedback history
  List<FeedbackEvent> getHistory() => List.unmodifiable(_eventHistory);

  /// Get analytics data
  Map<String, dynamic> getAnalytics() {
    return {
      'patternCounts': Map.from(_patternCounts),
      'channelCounts': _channelCounts.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'totalEvents': _eventHistory.length,
      'recordingEnabled': _recordingEnabled,
    };
  }

  /// Replay recorded feedback sequence
  Future<void> replaySequence(List<FeedbackEvent> events) async {
    for (final event in events) {
      await _replayEvent(event);
      if (event.duration != null) {
        await Future.delayed(event.duration!);
      }
    }
  }

  /// Replay a single feedback event
  Future<void> _replayEvent(FeedbackEvent event) async {
    switch (event.channel) {
      case FeedbackChannel.haptic:
        if (_shouldTriggerChannel(FeedbackChannel.haptic)) {
          await _hapticLibrary.playPattern(event.pattern, event.intensity);
        }
        break;
      case FeedbackChannel.audio:
        if (_shouldTriggerChannel(FeedbackChannel.audio)) {
          onAudioFeedback?.call(event.pattern, event.intensity.value);
        }
        break;
      case FeedbackChannel.visual:
        if (_shouldTriggerChannel(FeedbackChannel.visual)) {
          onVisualFeedback?.call(event.pattern, event.intensity);
        }
        break;
      case FeedbackChannel.accessibility:
        if (_shouldTriggerChannel(FeedbackChannel.accessibility)) {
          onAccessibilityFeedback?.call(event.pattern);
        }
        break;
    }
  }

  /// Clear all recorded data
  void clearHistory() {
    _eventHistory.clear();
    _patternCounts.clear();
    _channelCounts.clear();
  }

  /// Dispose of resources
  void dispose() {
    _feedbackStream.close();
  }
}

/// Factory for creating feedback controllers with different configurations
class FeedbackControllerFactory {
  static FeedbackController createDefault() {
    return FeedbackController(
      hapticLibrary: HapticPatternLibrary(),
      preferences: FeedbackPreferences(),
    );
  }

  static FeedbackController createForTesting({
    bool hapticEnabled = false,
    bool audioEnabled = false,
    bool visualEnabled = false,
  }) {
    return FeedbackController(
      hapticLibrary: HapticPatternLibrary(testMode: true),
      preferences: FeedbackPreferences(
        channelEnabled: {
          FeedbackChannel.haptic: hapticEnabled,
          FeedbackChannel.audio: audioEnabled,
          FeedbackChannel.visual: visualEnabled,
          FeedbackChannel.accessibility: false,
        },
      ),
    );
  }

  static FeedbackController createAccessible() {
    return FeedbackController(
      preferences: FeedbackPreferences(
        screenReaderEnabled: true,
        reducedMotion: true,
        highContrast: true,
        channelIntensity: {
          FeedbackChannel.haptic: 1.0,
          FeedbackChannel.audio: 1.0,
          FeedbackChannel.visual: 0.5,
          FeedbackChannel.accessibility: 1.0,
        },
      ),
    );
  }
}
