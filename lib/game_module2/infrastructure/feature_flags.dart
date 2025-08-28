import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Database-driven feature flag service with caching and YAML fallback
class FeatureFlagService {
  static final FeatureFlagService instance = FeatureFlagService._();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, bool> _flags = {};
  final String _cacheKey = 'feature_flags_cache';
  final Duration _cacheExpiration = const Duration(hours: 1);
  
  String _currentEnvironment = 'production';
  String? _userId;
  DateTime? _lastCacheTime;
  String _lastSource = 'not_initialized';
  
  FeatureFlagService._();
  
  /// Get the current environment
  String get currentEnvironment => _currentEnvironment;
  
  /// Get the last source used for flags (database/cache/yaml)
  String get lastSource => _lastSource;
  
  /// Get when the cache was last updated
  DateTime? get lastCacheTime => _lastCacheTime;
  
  /// Initialize the service
  Future<void> initialize({
    String? environment,
    String? userId,
  }) async {
    print('[FeatureFlagService] Initializing...');
    _currentEnvironment = environment ?? 
        const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
    _userId = userId ?? _supabase.auth.currentUser?.id;
    
    print('[FeatureFlagService] Environment: $_currentEnvironment');
    print('[FeatureFlagService] User ID: $_userId');
    
    // Try loading in order: Database -> Cache -> YAML
    bool loaded = await _loadFromDatabase();
    
    if (!loaded) {
      print('[FeatureFlagService] Database load failed, trying cache...');
      loaded = await _loadFromCache();
    }
    
    if (!loaded) {
      print('[FeatureFlagService] Cache load failed, loading from YAML...');
      await _loadFromYaml();
    }
    
    print('[FeatureFlagService] Initialization complete. Source: $_lastSource');
    print('[FeatureFlagService] Loaded flags: $_flags');
  }
  
  /// Force refresh flags from database
  Future<void> refresh() async {
    print('[FeatureFlagService] Force refreshing from database...');
    final loaded = await _loadFromDatabase();
    if (!loaded) {
      print('[FeatureFlagService] Database refresh failed, keeping current flags');
    } else {
      print('[FeatureFlagService] Flags refreshed successfully');
    }
  }
  
  /// Check if a feature is enabled
  Future<bool> isEnabled(String flagName) async {
    // Initialize if not already done
    if (_flags.isEmpty && _lastSource == 'not_initialized') {
      await initialize();
    }
    
    final enabled = _flags[flagName] ?? false;
    print('[FeatureFlagService] Flag check: $flagName = $enabled (source: $_lastSource)');
    return enabled;
  }
  
  /// Get all flags (for debugging)
  Map<String, bool> getAllFlags() => Map.from(_flags);
  
  /// Load flags from Supabase database
  Future<bool> _loadFromDatabase() async {
    try {
      print('[FeatureFlagService] Attempting to load from database...');
      
      // Call the RPC function to get feature flags
      final response = await _supabase.rpc('get_feature_flags', params: {
        'p_product_name': 'puzzle_nook',
        'p_environment_name': _currentEnvironment,
        'p_user_id': _userId,
      });
      
      if (response == null) {
        print('[FeatureFlagService] Database error: No response');
        return false;
      }
      
      final data = response as List<dynamic>;
      print('[FeatureFlagService] Database response: $data');
      
      _flags.clear();
      for (final row in data) {
        final flagName = row['flag_name'] as String;
        final enabled = row['enabled'] as bool;
        _flags[flagName] = enabled;
      }
      
      _lastSource = 'database';
      _lastCacheTime = DateTime.now();
      
      // Save to cache for offline use
      await _saveToCache();
      
      print('[FeatureFlagService] Loaded ${_flags.length} flags from database');
      return true;
    } catch (e) {
      print('[FeatureFlagService] Database load error: $e');
      return false;
    }
  }
  
  /// Load flags from local cache
  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      final cacheTime = prefs.getInt('${_cacheKey}_time');
      
      if (cacheData == null || cacheTime == null) {
        print('[FeatureFlagService] No cache data found');
        return false;
      }
      
      final cacheDateTime = DateTime.fromMillisecondsSinceEpoch(cacheTime);
      final age = DateTime.now().difference(cacheDateTime);
      
      if (age > _cacheExpiration) {
        print('[FeatureFlagService] Cache expired (age: ${age.inMinutes} minutes)');
        return false;
      }
      
      final Map<String, dynamic> cached = json.decode(cacheData);
      _flags.clear();
      cached.forEach((key, value) {
        _flags[key] = value as bool;
      });
      
      _lastSource = 'cache';
      _lastCacheTime = cacheDateTime;
      
      print('[FeatureFlagService] Loaded ${_flags.length} flags from cache');
      return true;
    } catch (e) {
      print('[FeatureFlagService] Cache load error: $e');
      return false;
    }
  }
  
  /// Load flags from YAML configuration
  Future<bool> _loadFromYaml() async {
    try {
      print('[FeatureFlagService] Loading from YAML fallback...');
      final yamlContent = await rootBundle.loadString(
        'assets/config/feature_flags_puzzle_nook.yaml'
      );
      
      // Simple YAML parsing for feature flags
      final lines = yamlContent.split('\n');
      _flags.clear();
      
      String? currentFlag;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        
        if (!trimmed.startsWith(' ') && trimmed.endsWith(':')) {
          // This is a flag name
          currentFlag = trimmed.substring(0, trimmed.length - 1);
        } else if (currentFlag != null && trimmed.startsWith('enabled:')) {
          // This is the enabled value
          final value = trimmed.substring('enabled:'.length).trim();
          _flags[currentFlag] = value.toLowerCase() == 'true';
          currentFlag = null;
        }
      }
      
      _lastSource = 'yaml';
      
      print('[FeatureFlagService] Loaded ${_flags.length} flags from YAML');
      return true;
    } catch (e) {
      print('[FeatureFlagService] YAML load error: $e');
      
      // Final fallback - hardcoded defaults
      _flags.clear();
      _flags['sample_puzzle'] = false;  // Default to false as requested
      _flags['magnetic_gestures'] = false;
      _flags['enhanced_feedback'] = false;
      _flags['smooth_animations'] = false;
      
      _lastSource = 'defaults';
      print('[FeatureFlagService] Using hardcoded defaults');
      return true;
    }
  }
  
  /// Save current flags to cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = json.encode(_flags);
      await prefs.setString(_cacheKey, cacheData);
      await prefs.setInt('${_cacheKey}_time', DateTime.now().millisecondsSinceEpoch);
      print('[FeatureFlagService] Saved ${_flags.length} flags to cache');
    } catch (e) {
      print('[FeatureFlagService] Cache save error: $e');
    }
  }
  
  /// Clear the cache (for testing)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove('${_cacheKey}_time');
      print('[FeatureFlagService] Cache cleared');
    } catch (e) {
      print('[FeatureFlagService] Cache clear error: $e');
    }
  }
}