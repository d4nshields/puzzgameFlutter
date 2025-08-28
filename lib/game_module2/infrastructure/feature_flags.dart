import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';  // Add Flutter material imports
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaml/yaml.dart';

/// Multi-tenant feature flag service for Tinkerplex products
/// 
/// This service provides database-driven feature flags with:
/// - Multi-product support for all Tinkerplex apps
/// - Environment-specific configurations
/// - Offline support with caching
/// - Gradual rollout capabilities
/// - User-specific overrides
class FeatureFlagService extends ChangeNotifier {
  static FeatureFlagService? _instance;
  
  final String productKey; // e.g., 'puzzle_nook'
  final String environment; // 'development', 'qa', 'alpha', 'production'
  final String? userId;
  final SupabaseClient? supabase;
  
  // Three layers of flag sources (priority: database > cache > yaml)
  Map<String, dynamic> _yamlDefaults = {};
  Map<String, dynamic> _cachedFlags = {};
  Map<String, dynamic> _databaseFlags = {};
  
  // Track what we're currently using
  Map<String, dynamic> _activeFlags = {};
  FlagSource _currentSource = FlagSource.yamlDefaults;
  
  bool _databaseFetchInProgress = false;
  DateTime? _lastDatabaseFetch;
  Timer? _refreshTimer;
  bool _disposed = false;
  
  // Cache management
  static const Duration _cacheMaxAge = Duration(hours: 24);
  static const Duration _cacheStaleAge = Duration(hours: 1);
  static const Duration _refreshInterval = Duration(minutes: 5);
  
  /// Singleton getter for default Puzzle Nook instance
  static FeatureFlagService get instance {
    _instance ??= FeatureFlagService(
      productKey: 'puzzle_nook',
      environment: const String.fromEnvironment('ENVIRONMENT', 
        defaultValue: 'development'),
      supabase: Supabase.instance.client,
    );
    return _instance!;
  }
  
  /// Constructor for creating product-specific instances
  FeatureFlagService({
    required this.productKey,
    required this.environment,
    this.userId,
    this.supabase,
  });
  
  /// Initialize the service
  Future<void> initialize() async {
    // Step 1: Load YAML defaults immediately
    await _loadYamlDefaults();
    _activeFlags = Map.from(_yamlDefaults);
    _currentSource = FlagSource.yamlDefaults;
    notifyListeners();
    
    // Step 2: Load cache (fast, local)
    await _loadCache();
    if (_cachedFlags.isNotEmpty) {
      _activeFlags = Map.from(_cachedFlags);
      _currentSource = FlagSource.cache;
      notifyListeners();
    }
    
    // Step 3: Fetch from database (async, don't block)
    _fetchFromDatabase();
    
    // Step 4: Set up periodic refresh
    _startPeriodicRefresh();
  }
  
  /// Load YAML defaults
  Future<void> _loadYamlDefaults() async {
    try {
      // Try to load product-specific YAML first
      final yamlString = await rootBundle.loadString(
        'assets/config/feature_flags_${productKey}.yaml'
      ).catchError((e) async {
        // Fall back to generic defaults
        return await rootBundle.loadString(
          'assets/config/feature_flags_defaults.yaml'
        );
      });
      
      final yamlMap = loadYaml(yamlString) as Map;
      
      // Start with base flags
      final baseFlags = Map<String, dynamic>.from(yamlMap['base_flags'] ?? {});
      
      // Apply environment-specific overrides
      final envOverrides = yamlMap['environments']?[environment];
      if (envOverrides != null) {
        for (final entry in (envOverrides as Map).entries) {
          // Convert YAML values to simple types
          if (entry.value is Map) {
            baseFlags[entry.key] = entry.value;
          } else {
            baseFlags[entry.key] = entry.value;
          }
        }
      }
      
      _yamlDefaults = baseFlags;
    } catch (e) {
      print('Failed to load YAML defaults: $e');
      // Provide absolute minimum defaults
      _yamlDefaults = {
        'debug_mode': false,
        'performance_monitoring': false,
        'magnetic_gestures': false,
        'enhanced_feedback': false,
        'smooth_animations': true,
      };
    }
  }
  
  /// Load cached flags
  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'feature_flags_${productKey}_$environment';
      final timestampKey = 'feature_flags_timestamp_${productKey}_$environment';
      
      final jsonString = prefs.getString(cacheKey);
      final timestamp = prefs.getInt(timestampKey);
      
      if (jsonString != null && timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        
        if (age < _cacheMaxAge.inMilliseconds) {
          _cachedFlags = Map<String, dynamic>.from(jsonDecode(jsonString));
          
          // Check if cache is stale
          if (age > _cacheStaleAge.inMilliseconds) {
            // Cache is stale but usable - trigger background refresh
            _fetchFromDatabase();
          }
        }
      }
    } catch (e) {
      print('Failed to load feature flag cache: $e');
    }
  }
  
  /// Save flags to cache
  Future<void> _saveToCache(Map<String, dynamic> flags) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'feature_flags_${productKey}_$environment';
      final timestampKey = 'feature_flags_timestamp_${productKey}_$environment';
      
      await prefs.setString(cacheKey, jsonEncode(flags));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Failed to save feature flag cache: $e');
    }
  }
  
  /// Fetch flags from database
  Future<void> _fetchFromDatabase() async {
    if (supabase == null || _databaseFetchInProgress) return;
    
    _databaseFetchInProgress = true;
    
    try {
      final response = await supabase!
          .rpc('get_feature_flags', params: {
            'p_product_key': productKey,
            'p_environment': environment,
            'p_user_id': userId,
          })
          .timeout(const Duration(seconds: 5));
      
      if (response != null) {
        _databaseFlags = Map<String, dynamic>.from(response);
        _activeFlags = Map.from(_databaseFlags);
        _currentSource = FlagSource.database;
        _lastDatabaseFetch = DateTime.now();
        
        // Update cache with fresh data
        await _saveToCache(_databaseFlags);
        
        notifyListeners();
      }
    } catch (e) {
      print('Database fetch failed, keeping current flags: $e');
      // Don't change _activeFlags - keep using whatever we have
    } finally {
      _databaseFetchInProgress = false;
    }
  }
  
  /// Start periodic refresh
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_disposed) {
        _fetchFromDatabase();
      }
    });
  }
  
  /// Check if a feature is enabled
  bool isEnabled(String key) {
    final value = _activeFlags[key];
    
    if (value == null) {
      // Check legacy flags for backward compatibility
      return _checkLegacyFlag(key);
    }
    
    if (value is bool) return value;
    
    if (value is Map) {
      // Handle percentage rollout
      if (value['type'] == 'percentage') {
        final enabled = value['enabled'] ?? false;
        if (!enabled) return false;
        
        final percentage = value['rollout_percentage'] ?? 0;
        return _checkPercentageRollout(key, percentage);
      }
      
      // Handle other complex types
      return value['enabled'] ?? false;
    }
    
    return false;
  }
  
  /// Check percentage rollout
  bool _checkPercentageRollout(String flagKey, int percentage) {
    if (userId == null) {
      // No user ID, use random
      return Random().nextInt(100) < percentage;
    }
    
    // Consistent rollout based on user ID
    final hash = '$userId$flagKey'.hashCode;
    return (hash.abs() % 100) < percentage;
  }
  
  /// Check legacy flags for backward compatibility
  bool _checkLegacyFlag(String key) {
    // Import from old BuildConfig system during transition
    try {
      // This will be removed once migration is complete
      switch (key) {
        case 'sample_puzzle':
          // Check compile-time flag if available
          return const bool.fromEnvironment('SAMPLE_PUZZLE_ENABLED', 
            defaultValue: false);
        case 'debug_tools':
          return const bool.fromEnvironment('DEBUG_TOOLS_ENABLED',
            defaultValue: false);
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  /// Get a typed value for a flag
  T? getValue<T>(String key) {
    final value = _activeFlags[key];
    
    if (value is Map) {
      // Complex value - extract the actual value
      if (value['value'] != null) {
        return value['value'] as T?;
      }
      // For percentage type, return the percentage
      if (value['type'] == 'percentage' && T == int) {
        return value['rollout_percentage'] as T?;
      }
    }
    
    return value as T?;
  }
  
  /// Get variant for A/B testing
  String getVariant(String key, {String defaultVariant = 'control'}) {
    final value = _activeFlags[key];
    
    if (value is Map && value['type'] == 'variant') {
      final variants = value['variants'] as List<String>?;
      final selectedVariant = value['selected_variant'] as String?;
      
      if (selectedVariant != null) {
        return selectedVariant;
      }
      
      if (variants != null && variants.isNotEmpty) {
        // Select variant based on user ID hash
        if (userId != null) {
          final hash = '$userId$key'.hashCode;
          final index = hash.abs() % variants.length;
          return variants[index];
        }
        // Random selection if no user ID
        return variants[Random().nextInt(variants.length)];
      }
    }
    
    return defaultVariant;
  }
  
  /// Force refresh from database
  Future<void> forceRefresh() async {
    await _fetchFromDatabase();
  }
  
  /// Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'feature_flags_${productKey}_$environment';
    final timestampKey = 'feature_flags_timestamp_${productKey}_$environment';
    
    await prefs.remove(cacheKey);
    await prefs.remove(timestampKey);
    _cachedFlags.clear();
  }
  
  // Getters for monitoring
  FlagSource get currentSource => _currentSource;
  bool get isUsingLiveData => _currentSource == FlagSource.database;
  DateTime? get lastDatabaseUpdate => _lastDatabaseFetch;
  Map<String, dynamic> get activeFlags => Map.unmodifiable(_activeFlags);
  
  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'product': productKey,
      'environment': environment,
      'currentSource': _currentSource.toString(),
      'lastDatabaseFetch': _lastDatabaseFetch?.toIso8601String(),
      'flagCount': _activeFlags.length,
      'flags': _activeFlags,
    };
  }
  
  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Source of feature flags
enum FlagSource {
  yamlDefaults,  // Fallback YAML configuration
  cache,         // Cached from previous database fetch
  database,      // Live from database
}

/// Feature flag gate widget for conditional rendering
class FeatureGate extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? fallback;
  final FeatureFlagService? service;
  
  const FeatureGate({
    Key? key,
    required this.feature,
    required this.child,
    this.fallback,
    this.service,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final flagService = service ?? FeatureFlagService.instance;
    
    return ListenableBuilder(
      listenable: flagService,
      builder: (context, _) {
        if (flagService.isEnabled(feature)) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Extension for easy feature flag access
extension FeatureFlagExtension on BuildContext {
  bool isFeatureEnabled(String feature) {
    return FeatureFlagService.instance.isEnabled(feature);
  }
  
  T? getFeatureValue<T>(String feature) {
    return FeatureFlagService.instance.getValue<T>(feature);
  }
}
