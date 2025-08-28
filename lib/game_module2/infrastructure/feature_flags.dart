import 'dart:convert';

/// Feature flag service for controlling feature rollout.
/// 
/// Provides a way to enable/disable features at runtime and
/// perform gradual rollouts.
class FeatureFlagService {
  final Map<String, FeatureFlag> _flags = {};
  final List<FeatureFlagListener> _listeners = [];
  
  FeatureFlagService({Map<String, bool>? initialFlags}) {
    // Initialize default flags
    _initializeDefaultFlags();
    
    // Override with provided flags
    if (initialFlags != null) {
      for (final entry in initialFlags.entries) {
        _flags[entry.key] = FeatureFlag(
          name: entry.key,
          enabled: entry.value,
        );
      }
    }
  }
  
  /// Initialize default feature flags
  void _initializeDefaultFlags() {
    _flags.addAll({
      // Rendering features
      'hybrid_rendering': FeatureFlag(
        name: 'hybrid_rendering',
        enabled: true,
        description: 'Enable hybrid rendering pipeline',
      ),
      'particle_effects': FeatureFlag(
        name: 'particle_effects',
        enabled: true,
        description: 'Enable particle effects',
      ),
      'magnetic_field_visualization': FeatureFlag(
        name: 'magnetic_field_visualization',
        enabled: false,
        description: 'Show magnetic field lines',
      ),
      
      // Interaction features
      'magnetic_gestures': FeatureFlag(
        name: 'magnetic_gestures',
        enabled: true,
        description: 'Enable magnetic gesture assistance',
      ),
      'haptic_feedback': FeatureFlag(
        name: 'haptic_feedback',
        enabled: true,
        description: 'Enable haptic feedback',
      ),
      'audio_feedback': FeatureFlag(
        name: 'audio_feedback',
        enabled: true,
        description: 'Enable audio feedback',
      ),
      'visual_feedback': FeatureFlag(
        name: 'visual_feedback',
        enabled: true,
        description: 'Enable visual feedback effects',
      ),
      
      // Performance features
      'performance_monitoring': FeatureFlag(
        name: 'performance_monitoring',
        enabled: true,
        description: 'Enable performance monitoring',
      ),
      'adaptive_quality': FeatureFlag(
        name: 'adaptive_quality',
        enabled: true,
        description: 'Enable adaptive quality based on performance',
      ),
      'picture_caching': FeatureFlag(
        name: 'picture_caching',
        enabled: true,
        description: 'Enable picture caching for performance',
      ),
      
      // Debug features
      'debug_mode': FeatureFlag(
        name: 'debug_mode',
        enabled: false,
        description: 'Enable debug mode',
      ),
      'debug_overlay': FeatureFlag(
        name: 'debug_overlay',
        enabled: false,
        description: 'Show debug overlay',
      ),
      'state_visualization': FeatureFlag(
        name: 'state_visualization',
        enabled: false,
        description: 'Show state machine visualization',
      ),
      
      // Accessibility features
      'accessibility_mode': FeatureFlag(
        name: 'accessibility_mode',
        enabled: false,
        description: 'Enable accessibility features',
      ),
      'screen_reader_support': FeatureFlag(
        name: 'screen_reader_support',
        enabled: true,
        description: 'Enable screen reader support',
      ),
      'reduced_motion': FeatureFlag(
        name: 'reduced_motion',
        enabled: false,
        description: 'Reduce motion for accessibility',
      ),
      
      // Experimental features
      'experimental_animations': FeatureFlag(
        name: 'experimental_animations',
        enabled: false,
        description: 'Enable experimental animations',
        experimental: true,
      ),
      'ai_hints': FeatureFlag(
        name: 'ai_hints',
        enabled: false,
        description: 'Enable AI-powered hints',
        experimental: true,
      ),
    });
  }
  
  /// Check if a feature is enabled
  bool isEnabled(String flagName) {
    final flag = _flags[flagName];
    if (flag == null) {
      print('FeatureFlagService: Unknown flag "$flagName", defaulting to false');
      return false;
    }
    
    // Check if flag has rollout percentage
    if (flag.rolloutPercentage != null) {
      return flag.enabled && _isInRollout(flag);
    }
    
    return flag.enabled;
  }
  
  /// Check if user is in rollout percentage
  bool _isInRollout(FeatureFlag flag) {
    if (flag.rolloutPercentage == null) return true;
    
    // Simple hash-based rollout (in production, use user ID)
    final hash = flag.name.hashCode.abs();
    final percentage = hash % 100;
    
    return percentage < flag.rolloutPercentage!;
  }
  
  /// Enable a feature
  void enable(String flagName) {
    final flag = _flags[flagName];
    if (flag != null && !flag.enabled) {
      flag.enabled = true;
      _notifyListeners(flagName, true);
    }
  }
  
  /// Disable a feature
  void disable(String flagName) {
    final flag = _flags[flagName];
    if (flag != null && flag.enabled) {
      flag.enabled = false;
      _notifyListeners(flagName, false);
    }
  }
  
  /// Toggle a feature
  void toggle(String flagName) {
    final flag = _flags[flagName];
    if (flag != null) {
      flag.enabled = !flag.enabled;
      _notifyListeners(flagName, flag.enabled);
    }
  }
  
  /// Set rollout percentage for a feature
  void setRolloutPercentage(String flagName, int percentage) {
    final flag = _flags[flagName];
    if (flag != null) {
      flag.rolloutPercentage = percentage.clamp(0, 100);
      _notifyListeners(flagName, isEnabled(flagName));
    }
  }
  
  /// Register a listener for flag changes
  void addListener(FeatureFlagListener listener) {
    _listeners.add(listener);
  }
  
  /// Remove a listener
  void removeListener(FeatureFlagListener listener) {
    _listeners.remove(listener);
  }
  
  /// Notify listeners of flag change
  void _notifyListeners(String flagName, bool enabled) {
    for (final listener in _listeners) {
      listener(flagName, enabled);
    }
  }
  
  /// Get all flags
  Map<String, bool> getAllFlags() {
    return Map.fromEntries(
      _flags.entries.map((e) => MapEntry(e.key, isEnabled(e.key))),
    );
  }
  
  /// Get all experimental flags
  Map<String, bool> getExperimentalFlags() {
    return Map.fromEntries(
      _flags.entries
        .where((e) => e.value.experimental)
        .map((e) => MapEntry(e.key, isEnabled(e.key))),
    );
  }
  
  /// Export flags configuration as JSON
  String exportConfiguration() {
    final config = _flags.map((key, flag) => MapEntry(key, flag.toJson()));
    return jsonEncode(config);
  }
  
  /// Import flags configuration from JSON
  void importConfiguration(String json) {
    try {
      final Map<String, dynamic> config = jsonDecode(json);
      
      for (final entry in config.entries) {
        final flagData = entry.value as Map<String, dynamic>;
        _flags[entry.key] = FeatureFlag.fromJson(entry.key, flagData);
      }
      
      // Notify listeners of all changes
      for (final flag in _flags.keys) {
        _notifyListeners(flag, isEnabled(flag));
      }
    } catch (e) {
      print('FeatureFlagService: Failed to import configuration: $e');
    }
  }
  
  /// Create A/B test for a feature
  ABTest createABTest(String flagName, {
    required int variantAPercentage,
    Duration? duration,
  }) {
    final flag = _flags[flagName];
    if (flag == null) {
      throw ArgumentError('Unknown flag: $flagName');
    }
    
    return ABTest(
      flagName: flagName,
      variantAPercentage: variantAPercentage,
      startTime: DateTime.now(),
      duration: duration,
      service: this,
    );
  }
}

/// Feature flag model
class FeatureFlag {
  final String name;
  bool enabled;
  final String? description;
  final bool experimental;
  int? rolloutPercentage;
  Map<String, dynamic>? metadata;
  
  FeatureFlag({
    required this.name,
    required this.enabled,
    this.description,
    this.experimental = false,
    this.rolloutPercentage,
    this.metadata,
  });
  
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'description': description,
    'experimental': experimental,
    'rolloutPercentage': rolloutPercentage,
    'metadata': metadata,
  };
  
  factory FeatureFlag.fromJson(String name, Map<String, dynamic> json) {
    return FeatureFlag(
      name: name,
      enabled: json['enabled'] ?? false,
      description: json['description'],
      experimental: json['experimental'] ?? false,
      rolloutPercentage: json['rolloutPercentage'],
      metadata: json['metadata'],
    );
  }
}

/// A/B test for feature flags
class ABTest {
  final String flagName;
  final int variantAPercentage;
  final DateTime startTime;
  final Duration? duration;
  final FeatureFlagService service;
  
  ABTest({
    required this.flagName,
    required this.variantAPercentage,
    required this.startTime,
    this.duration,
    required this.service,
  });
  
  /// Check if test is still active
  bool get isActive {
    if (duration == null) return true;
    return DateTime.now().difference(startTime) < duration!;
  }
  
  /// Get variant for current user
  String getVariant() {
    if (!isActive) return 'control';
    
    // Simple hash-based assignment (in production, use user ID)
    final hash = flagName.hashCode.abs();
    final percentage = hash % 100;
    
    return percentage < variantAPercentage ? 'A' : 'B';
  }
  
  /// Check if feature should be enabled for current user
  bool isEnabled() {
    if (!isActive) {
      return service.isEnabled(flagName);
    }
    
    return getVariant() == 'A';
  }
}

/// Listener type for feature flag changes
typedef FeatureFlagListener = void Function(String flagName, bool enabled);
