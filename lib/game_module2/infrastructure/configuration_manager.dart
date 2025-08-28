import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration manager for runtime settings.
/// 
/// Provides centralized configuration management with persistence
/// and runtime updates.
class ConfigurationManager {
  final Map<String, dynamic> _config = {};
  final List<ConfigurationListener> _listeners = [];
  SharedPreferences? _prefs;
  
  static const String _storagePrefix = 'puzzle_config_';
  
  ConfigurationManager() {
    _loadDefaultConfiguration();
  }
  
  /// Initialize with SharedPreferences for persistence
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPersistedConfiguration();
  }
  
  /// Load default configuration
  void _loadDefaultConfiguration() {
    _config.addAll({
      // Magnetic field configuration
      'magnetic_field': {
        'strength': 0.4,
        'minimum_influence': 0.1,
        'max_influence': 8.0,
        'falloff_type': 1, // Quadratic
        'snap_radius': 50.0,
        'enable_visualization': false,
      },
      
      // Feedback configuration
      'feedback': {
        'haptic_enabled': true,
        'audio_enabled': true,
        'visual_enabled': true,
        'adaptive_intensity': true,
        'base_intensity': 0.7,
        'celebration_duration': 3000, // milliseconds
      },
      
      // Gesture configuration
      'gestures': {
        'multi_touch': true,
        'hints_enabled': true,
        'accessibility_mode': false,
        'drag_threshold': 10.0,
        'long_press_duration': 500, // milliseconds
        'double_tap_timeout': 300, // milliseconds
      },
      
      // Rendering configuration
      'rendering': {
        'target_fps': 60,
        'enable_shadows': true,
        'enable_glow': true,
        'particle_density': 1.0,
        'texture_quality': 'high', // low, medium, high
        'antialiasing': true,
      },
      
      // Performance configuration
      'performance': {
        'max_memory_mb': 500,
        'cache_size_mb': 100,
        'enable_profiling': false,
        'adaptive_quality': true,
        'battery_saver_mode': false,
      },
      
      // Animation configuration
      'animations': {
        'piece_snap_duration': 200, // milliseconds
        'piece_return_duration': 300, // milliseconds
        'celebration_duration': 2000, // milliseconds
        'hint_pulse_duration': 1000, // milliseconds
        'spring_stiffness': 300.0,
        'spring_damping': 20.0,
      },
      
      // Game configuration
      'game': {
        'auto_save': true,
        'auto_save_interval': 30, // seconds
        'show_timer': true,
        'show_score': true,
        'enable_hints': true,
        'max_hints': 3,
        'difficulty_multiplier': 1.0,
      },
      
      // Debug configuration
      'debug': {
        'show_fps': false,
        'show_memory': false,
        'show_touches': false,
        'show_state_machine': false,
        'show_field_lines': false,
        'enable_logging': false,
        'log_level': 'info', // debug, info, warning, error
      },
      
      // Accessibility configuration
      'accessibility': {
        'high_contrast': false,
        'large_touch_targets': false,
        'reduce_motion': false,
        'screen_reader_hints': true,
        'color_blind_mode': 'none', // none, protanopia, deuteranopia, tritanopia
        'minimum_touch_size': 44.0,
      },
    });
  }
  
  /// Load persisted configuration from SharedPreferences
  Future<void> _loadPersistedConfiguration() async {
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys().where((key) => key.startsWith(_storagePrefix));
    
    for (final key in keys) {
      final configKey = key.substring(_storagePrefix.length);
      final value = _prefs!.get(key);
      
      if (value != null) {
        _setNestedValue(configKey, value);
      }
    }
  }
  
  /// Get a configuration value
  T getValue<T>(String key, T defaultValue) {
    final parts = key.split('.');
    dynamic current = _config;
    
    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return defaultValue;
      }
    }
    
    return current as T? ?? defaultValue;
  }
  
  /// Get a configuration section
  Map<String, dynamic> getSection(String section) {
    final value = _config[section];
    if (value is Map<String, dynamic>) {
      return Map.from(value);
    }
    return {};
  }
  
  /// Set a configuration value
  Future<void> setValue(String key, dynamic value) async {
    _setNestedValue(key, value);
    
    // Persist if possible
    if (_prefs != null) {
      final storageKey = '$_storagePrefix$key';
      
      if (value is bool) {
        await _prefs!.setBool(storageKey, value);
      } else if (value is int) {
        await _prefs!.setInt(storageKey, value);
      } else if (value is double) {
        await _prefs!.setDouble(storageKey, value);
      } else if (value is String) {
        await _prefs!.setString(storageKey, value);
      } else if (value is List<String>) {
        await _prefs!.setStringList(storageKey, value);
      }
    }
    
    // Notify listeners
    _notifyListeners(key, value);
  }
  
  /// Set a nested configuration value
  void _setNestedValue(String key, dynamic value) {
    final parts = key.split('.');
    Map<String, dynamic> current = _config;
    
    for (int i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      if (!current.containsKey(part) || current[part] is! Map) {
        current[part] = {};
      }
      current = current[part] as Map<String, dynamic>;
    }
    
    current[parts.last] = value;
  }
  
  /// Update a configuration section
  Future<void> updateSection(String section, Map<String, dynamic> values) async {
    if (!_config.containsKey(section) || _config[section] is! Map) {
      _config[section] = {};
    }
    
    final sectionMap = _config[section] as Map<String, dynamic>;
    
    for (final entry in values.entries) {
      sectionMap[entry.key] = entry.value;
      await setValue('$section.${entry.key}', entry.value);
    }
  }
  
  /// Register a configuration listener
  void addListener(ConfigurationListener listener) {
    _listeners.add(listener);
  }
  
  /// Remove a configuration listener
  void removeListener(ConfigurationListener listener) {
    _listeners.remove(listener);
  }
  
  /// Notify listeners of configuration change
  void _notifyListeners(String key, dynamic value) {
    for (final listener in _listeners) {
      listener(key, value);
    }
  }
  
  /// Reset a section to defaults
  Future<void> resetSection(String section) async {
    _loadDefaultConfiguration();
    final defaultSection = _config[section];
    
    if (defaultSection != null && defaultSection is Map<String, dynamic>) {
      await updateSection(section, defaultSection);
    }
  }
  
  /// Reset all configuration to defaults
  Future<void> resetAll() async {
    // Clear persisted values
    if (_prefs != null) {
      final keys = _prefs!.getKeys().where((key) => key.startsWith(_storagePrefix));
      for (final key in keys) {
        await _prefs!.remove(key);
      }
    }
    
    // Reset to defaults
    _config.clear();
    _loadDefaultConfiguration();
    
    // Notify listeners
    for (final listener in _listeners) {
      listener('*', null);
    }
  }
  
  /// Export configuration as JSON
  String exportConfiguration() {
    return const JsonEncoder.withIndent('  ').convert(_config);
  }
  
  /// Import configuration from JSON
  Future<void> importConfiguration(String json) async {
    try {
      final Map<String, dynamic> imported = jsonDecode(json);
      
      for (final entry in imported.entries) {
        if (entry.value is Map<String, dynamic>) {
          await updateSection(entry.key, entry.value);
        } else {
          await setValue(entry.key, entry.value);
        }
      }
    } catch (e) {
      print('ConfigurationManager: Failed to import configuration: $e');
    }
  }
  
  /// Get configuration profile for different scenarios
  ConfigurationProfile getProfile(ProfileType type) {
    switch (type) {
      case ProfileType.performance:
        return ConfigurationProfile(
          name: 'Performance',
          settings: {
            'rendering.enable_shadows': false,
            'rendering.enable_glow': false,
            'rendering.particle_density': 0.5,
            'rendering.texture_quality': 'low',
            'performance.adaptive_quality': true,
            'feedback.visual_enabled': false,
          },
        );
      
      case ProfileType.quality:
        return ConfigurationProfile(
          name: 'Quality',
          settings: {
            'rendering.enable_shadows': true,
            'rendering.enable_glow': true,
            'rendering.particle_density': 1.0,
            'rendering.texture_quality': 'high',
            'rendering.antialiasing': true,
            'performance.adaptive_quality': false,
          },
        );
      
      case ProfileType.battery:
        return ConfigurationProfile(
          name: 'Battery Saver',
          settings: {
            'rendering.target_fps': 30,
            'rendering.enable_shadows': false,
            'rendering.enable_glow': false,
            'rendering.particle_density': 0.3,
            'performance.battery_saver_mode': true,
            'feedback.haptic_enabled': false,
            'animations.piece_snap_duration': 100,
          },
        );
      
      case ProfileType.accessibility:
        return ConfigurationProfile(
          name: 'Accessibility',
          settings: {
            'accessibility.high_contrast': true,
            'accessibility.large_touch_targets': true,
            'accessibility.reduce_motion': true,
            'accessibility.minimum_touch_size': 48.0,
            'gestures.accessibility_mode': true,
            'animations.piece_snap_duration': 100,
          },
        );
      
      case ProfileType.debug:
        return ConfigurationProfile(
          name: 'Debug',
          settings: {
            'debug.show_fps': true,
            'debug.show_memory': true,
            'debug.show_touches': true,
            'debug.show_state_machine': true,
            'debug.enable_logging': true,
            'debug.log_level': 'debug',
          },
        );
    }
  }
  
  /// Apply a configuration profile
  Future<void> applyProfile(ConfigurationProfile profile) async {
    for (final entry in profile.settings.entries) {
      await setValue(entry.key, entry.value);
    }
  }
  
  /// Convert to JSON for debugging
  Map<String, dynamic> toJson() => Map.from(_config);
}

/// Configuration listener type
typedef ConfigurationListener = void Function(String key, dynamic value);

/// Configuration profile types
enum ProfileType {
  performance,
  quality,
  battery,
  accessibility,
  debug,
}

/// Configuration profile
class ConfigurationProfile {
  final String name;
  final Map<String, dynamic> settings;
  
  ConfigurationProfile({
    required this.name,
    required this.settings,
  });
}
