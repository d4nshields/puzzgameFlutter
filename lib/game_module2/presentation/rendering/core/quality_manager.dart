part of '../hybrid_renderer.dart';

/// Manages rendering quality settings and automatic adjustments
class QualityManager {
  QualityLevel _currentQuality;
  final bool autoAdjust;
  
  // Performance thresholds for quality adjustment
  static const double upgradeThreshold = 58.0; // FPS
  static const double downgradeThreshold = 45.0; // FPS
  static const int stabilityFrames = 60; // Frames to wait before adjusting
  
  int _stableFrameCount = 0;
  double _recentAverageFps = 60.0;
  DateTime _lastAdjustment = DateTime.now();
  static const Duration adjustmentCooldown = Duration(seconds: 5);

  QualityManager({
    required QualityLevel initialQuality,
    this.autoAdjust = true,
  }) : _currentQuality = initialQuality;

  QualityLevel get currentQuality => _currentQuality;

  /// Update quality based on performance metrics
  void updateFromMetrics(PerformanceMetrics metrics) {
    if (!autoAdjust) return;
    
    // Update rolling average
    _recentAverageFps = _recentAverageFps * 0.9 + metrics.fps * 0.1;
    
    // Check if we're in cooldown period
    if (DateTime.now().difference(_lastAdjustment) < adjustmentCooldown) {
      return;
    }
    
    // Determine if performance is stable
    if (_isPerformanceStable(metrics.fps)) {
      _stableFrameCount++;
    } else {
      _stableFrameCount = 0;
      return;
    }
    
    // Only adjust after stable performance
    if (_stableFrameCount < stabilityFrames) {
      return;
    }
    
    // Check if quality adjustment is needed
    if (_recentAverageFps < downgradeThreshold && canDecreaseQuality()) {
      decreaseQuality();
    } else if (_recentAverageFps > upgradeThreshold && canIncreaseQuality()) {
      increaseQuality();
    }
  }

  /// Check if performance is stable
  bool _isPerformanceStable(int fps) {
    return (fps - _recentAverageFps).abs() < 5.0;
  }

  /// Increase quality level
  void increaseQuality() {
    if (!canIncreaseQuality()) return;
    
    final oldQuality = _currentQuality;
    _currentQuality = _getNextHigherQuality();
    _onQualityChanged(oldQuality, _currentQuality);
  }

  /// Decrease quality level
  void decreaseQuality() {
    if (!canDecreaseQuality()) return;
    
    final oldQuality = _currentQuality;
    _currentQuality = _getNextLowerQuality();
    _onQualityChanged(oldQuality, _currentQuality);
  }

  /// Check if quality can be increased
  bool canIncreaseQuality() {
    return _currentQuality != QualityLevel.ultra;
  }

  /// Check if quality can be decreased
  bool canDecreaseQuality() {
    return _currentQuality != QualityLevel.low;
  }

  /// Get next higher quality level
  QualityLevel _getNextHigherQuality() {
    switch (_currentQuality) {
      case QualityLevel.low:
        return QualityLevel.medium;
      case QualityLevel.medium:
        return QualityLevel.high;
      case QualityLevel.high:
        return QualityLevel.ultra;
      case QualityLevel.ultra:
        return QualityLevel.ultra;
    }
  }

  /// Get next lower quality level
  QualityLevel _getNextLowerQuality() {
    switch (_currentQuality) {
      case QualityLevel.low:
        return QualityLevel.low;
      case QualityLevel.medium:
        return QualityLevel.low;
      case QualityLevel.high:
        return QualityLevel.medium;
      case QualityLevel.ultra:
        return QualityLevel.high;
    }
  }

  /// Handle quality change
  void _onQualityChanged(QualityLevel oldQuality, QualityLevel newQuality) {
    _lastAdjustment = DateTime.now();
    _stableFrameCount = 0;
    
    debugPrint('Quality changed: ${oldQuality.name} → ${newQuality.name}');
    
    // Log quality change reason
    if (newQuality.index < oldQuality.index) {
      debugPrint('Reason: Low FPS (${_recentAverageFps.toStringAsFixed(1)})');
    } else {
      debugPrint('Reason: Performance headroom available');
    }
  }

  /// Set quality manually
  void setQuality(QualityLevel quality) {
    if (_currentQuality != quality) {
      final oldQuality = _currentQuality;
      _currentQuality = quality;
      _onQualityChanged(oldQuality, quality);
    }
  }

  /// Get quality preset for specific scenarios
  QualityLevel getPresetForScenario(RenderingScenario scenario) {
    switch (scenario) {
      case RenderingScenario.menuScreen:
        return QualityLevel.high; // Menus can afford higher quality
      case RenderingScenario.gameplay:
        return _currentQuality; // Use adaptive quality
      case RenderingScenario.celebration:
        return QualityLevel.ultra; // Max quality for special moments
      case RenderingScenario.backgrounded:
        return QualityLevel.low; // Save resources when backgrounded
    }
  }

  /// Get render settings for current quality
  RenderSettings getRenderSettings() {
    return RenderSettings(
      quality: _currentQuality,
      resolutionScale: _currentQuality.resolutionScale,
      enableShadows: _currentQuality.enableShadows,
      enableParticles: _currentQuality.enableParticles,
      targetFps: _currentQuality.targetFps,
      antialiasing: _getAntialiasingSetting(),
      textureQuality: _getTextureQuality(),
      effectComplexity: _getEffectComplexity(),
    );
  }

  /// Get antialiasing setting for current quality
  AntialiasingSetting _getAntialiasingSetting() {
    switch (_currentQuality) {
      case QualityLevel.low:
        return AntialiasingSetting.none;
      case QualityLevel.medium:
        return AntialiasingSetting.fxaa;
      case QualityLevel.high:
      case QualityLevel.ultra:
        return AntialiasingSetting.msaa4x;
    }
  }

  /// Get texture quality for current quality
  TextureQuality _getTextureQuality() {
    switch (_currentQuality) {
      case QualityLevel.low:
        return TextureQuality.low;
      case QualityLevel.medium:
        return TextureQuality.medium;
      case QualityLevel.high:
        return TextureQuality.high;
      case QualityLevel.ultra:
        return TextureQuality.ultra;
    }
  }

  /// Get effect complexity for current quality
  EffectComplexity _getEffectComplexity() {
    switch (_currentQuality) {
      case QualityLevel.low:
        return EffectComplexity.simple;
      case QualityLevel.medium:
        return EffectComplexity.moderate;
      case QualityLevel.high:
        return EffectComplexity.complex;
      case QualityLevel.ultra:
        return EffectComplexity.maximum;
    }
  }
}

/// Rendering scenarios
enum RenderingScenario {
  menuScreen,
  gameplay,
  celebration,
  backgrounded,
}

/// Render settings based on quality level
class RenderSettings {
  final QualityLevel quality;
  final double resolutionScale;
  final bool enableShadows;
  final bool enableParticles;
  final int targetFps;
  final AntialiasingSetting antialiasing;
  final TextureQuality textureQuality;
  final EffectComplexity effectComplexity;

  const RenderSettings({
    required this.quality,
    required this.resolutionScale,
    required this.enableShadows,
    required this.enableParticles,
    required this.targetFps,
    required this.antialiasing,
    required this.textureQuality,
    required this.effectComplexity,
  });
}

/// Antialiasing settings
enum AntialiasingSetting {
  none,
  fxaa,
  msaa2x,
  msaa4x,
}

/// Texture quality settings
enum TextureQuality {
  low(0.5),
  medium(0.75),
  high(1.0),
  ultra(1.0);

  final double scale;
  const TextureQuality(this.scale);
}

/// Effect complexity settings
enum EffectComplexity {
  simple(5, 10),
  moderate(10, 20),
  complex(20, 50),
  maximum(50, 100);

  final int maxParticles;
  final int maxEffects;
  
  const EffectComplexity(this.maxParticles, this.maxEffects);
}