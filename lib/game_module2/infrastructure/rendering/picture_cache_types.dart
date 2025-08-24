/// Picture Cache Supporting Classes and Types
/// 
/// This file contains data classes, patterns, exceptions, and utilities
/// for the picture caching system.

import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'picture_cache.dart';

// Data classes

/// Cache configuration
class PictureCacheConfig {
  final int maxMemorySizeBytes;
  final int maxMemoryEntries;
  final int maxDiskSizeBytes;
  final String? cacheDirectory;
  final bool enableAutoWarming;
  final int evictionIntervalSeconds;
  final CacheWarmerConfig warmerConfig;
  
  const PictureCacheConfig({
    this.maxMemorySizeBytes = 100 * 1024 * 1024, // 100MB
    this.maxMemoryEntries = 1000,
    this.maxDiskSizeBytes = 500 * 1024 * 1024, // 500MB
    this.cacheDirectory,
    this.enableAutoWarming = true,
    this.evictionIntervalSeconds = 30,
    this.warmerConfig = const CacheWarmerConfig(),
  });
  
  @override
  String toString() => 'PictureCacheConfig('
      'memory: ${maxMemorySizeBytes ~/ 1024 ~/ 1024}MB, '
      'disk: ${maxDiskSizeBytes ~/ 1024 ~/ 1024}MB, '
      'warming: $enableAutoWarming)';
}

/// Cache warmer configuration
class CacheWarmerConfig {
  final int warmingIntervalSeconds;
  final int maxWarmingItems;
  final int maxHistorySize;
  final int frequencyThreshold;
  
  const CacheWarmerConfig({
    this.warmingIntervalSeconds = 60,
    this.maxWarmingItems = 20,
    this.maxHistorySize = 100,
    this.frequencyThreshold = 3,
  });
}

/// Cache entry
class CacheEntry {
  final CacheKey key;
  final ui.Picture picture;
  final int sizeBytes;
  CachePriority priority;
  DateTime lastAccessed;
  int accessCount;
  
  CacheEntry({
    required this.key,
    required this.picture,
    required this.sizeBytes,
    required this.priority,
    DateTime? lastAccessed,
    this.accessCount = 0,
  }) : lastAccessed = lastAccessed ?? DateTime.now();
}

/// Disk cache entry
class DiskCacheEntry {
  final String filename;
  final int sizeBytes;
  final DateTime created;
  DateTime lastAccessed;
  int accessCount;
  
  DiskCacheEntry({
    required this.filename,
    required this.sizeBytes,
    required this.created,
    required this.lastAccessed,
    this.accessCount = 0,
  });
  
  factory DiskCacheEntry.fromJson(Map<String, dynamic> json) {
    return DiskCacheEntry(
      filename: json['filename'] as String,
      sizeBytes: json['sizeBytes'] as int,
      created: DateTime.parse(json['created'] as String),
      lastAccessed: DateTime.parse(json['lastAccessed'] as String),
      accessCount: json['accessCount'] as int? ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'filename': filename,
    'sizeBytes': sizeBytes,
    'created': created.toIso8601String(),
    'lastAccessed': lastAccessed.toIso8601String(),
    'accessCount': accessCount,
  };
}

/// Cache key wrapper
class CacheKey {
  final String value;
  
  const CacheKey(this.value);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheKey && value == other.value;
  
  @override
  int get hashCode => value.hashCode;
  
  @override
  String toString() => 'CacheKey($value)';
}

/// Cache metrics snapshot
class CacheMetricsSnapshot {
  final int hits;
  final int misses;
  final int puts;
  final int evictions;
  final int errors;
  final double hitRate;
  final Duration averageLookupTime;
  final int totalBytes;
  final Duration uptime;
  final Map<CacheLevel, int> levelHits;
  final Map<CacheLevel, Duration> levelLatency;
  
  const CacheMetricsSnapshot({
    required this.hits,
    required this.misses,
    required this.puts,
    required this.evictions,
    required this.errors,
    required this.hitRate,
    required this.averageLookupTime,
    required this.totalBytes,
    required this.uptime,
    required this.levelHits,
    required this.levelLatency,
  });
  
  Map<String, dynamic> toJson() => {
    'hits': hits,
    'misses': misses,
    'puts': puts,
    'evictions': evictions,
    'errors': errors,
    'hitRate': '${(hitRate * 100).toStringAsFixed(2)}%',
    'averageLookupTime': '${averageLookupTime.inMilliseconds}ms',
    'totalBytes': totalBytes,
    'uptime': uptime.toString(),
    'levelHits': levelHits.map((k, v) => MapEntry(k.toString(), v)),
    'levelLatency': levelLatency.map((k, v) => 
        MapEntry(k.toString(), '${v.inMilliseconds}ms')),
  };
  
  bool get meetsPerformanceRequirements {
    return hitRate >= 0.95 && // 95%+ hit rate
           averageLookupTime.inMilliseconds < 10 && // < 10ms lookup
           totalBytes < 100 * 1024 * 1024; // < 100MB memory
  }
}

/// Picture loader interface
abstract class PictureLoader {
  Future<ui.Picture?> load(String id, CancellationToken? token);
}

/// Default picture loader implementation
class DefaultPictureLoader implements PictureLoader {
  @override
  Future<ui.Picture?> load(String id, CancellationToken? token) async {
    // Check cancellation
    if (token?.isCancelled ?? false) {
      throw CancellationException();
    }
    
    try {
      // Load from assets or network
      final data = await rootBundle.load(id);
      
      // Check cancellation
      if (token?.isCancelled ?? false) {
        throw CancellationException();
      }
      
      // Decode image
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      
      // Check cancellation
      if (token?.isCancelled ?? false) {
        throw CancellationException();
      }
      
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Create picture from image
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(image, Offset.zero, Paint());
      
      return recorder.endRecording();
      
    } catch (e) {
      if (e is CancellationException) rethrow;
      debugPrint('DefaultPictureLoader: Failed to load $id: $e');
      return null;
    }
  }
}

/// Cancellation token for async operations
class CancellationToken {
  bool _isCancelled = false;
  final _listeners = <VoidCallback>[];
  
  bool get isCancelled => _isCancelled;
  
  void cancel() {
    if (_isCancelled) return;
    
    _isCancelled = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }
  
  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
  
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

/// Warming pattern for predictive loading
abstract class WarmingPattern {
  List<String> getPredictions();
}

/// Sequential warming pattern
class SequentialWarmingPattern implements WarmingPattern {
  final List<String> sequence;
  int _currentIndex = 0;
  
  SequentialWarmingPattern(this.sequence);
  
  @override
  List<String> getPredictions() {
    final predictions = <String>[];
    
    // Get next few items in sequence
    for (int i = 0; i < 5 && _currentIndex + i < sequence.length; i++) {
      predictions.add(sequence[_currentIndex + i]);
    }
    
    return predictions;
  }
  
  void advance() {
    _currentIndex++;
    if (_currentIndex >= sequence.length) {
      _currentIndex = 0;
    }
  }
}

/// Time-based warming pattern
class TimeBasedWarmingPattern implements WarmingPattern {
  final Map<TimeOfDay, List<String>> schedule;
  
  TimeBasedWarmingPattern(this.schedule);
  
  @override
  List<String> getPredictions() {
    final now = TimeOfDay.now();
    final predictions = <String>[];
    
    // Find matching time slots
    for (final entry in schedule.entries) {
      final timeDiff = (now.hour * 60 + now.minute) - 
                       (entry.key.hour * 60 + entry.key.minute);
      
      // Within 30 minutes
      if (timeDiff.abs() <= 30) {
        predictions.addAll(entry.value);
      }
    }
    
    return predictions;
  }
}

/// Usage-based warming pattern
class UsageBasedWarmingPattern implements WarmingPattern {
  final Map<String, double> usageScores;
  final double threshold;
  
  UsageBasedWarmingPattern({
    required this.usageScores,
    this.threshold = 0.5,
  });
  
  @override
  List<String> getPredictions() {
    return usageScores.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toList();
  }
  
  void updateScore(String id, double score) {
    usageScores[id] = score;
  }
}

// Enums

/// Cache levels
enum CacheLevel {
  memory,
  disk,
}

/// Cache priority
enum CachePriority {
  low,
  normal,
  high,
}

/// Memory pressure levels
enum MemoryPressureLevel {
  low,
  medium,
  high,
  critical,
}

// Exceptions

/// Cancellation exception
class CancellationException implements Exception {
  final String message;
  
  CancellationException([this.message = 'Operation cancelled']);
  
  @override
  String toString() => 'CancellationException: $message';
}

/// Cache exception
class CacheException implements Exception {
  final String message;
  final dynamic cause;
  
  CacheException(this.message, [this.cause]);
  
  @override
  String toString() => 'CacheException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

// Internal classes

/// LRU node for linked list (internal use)
base class LRUNode extends LinkedListEntry<LRUNode> {
  final CacheKey key;
  
  LRUNode(this.key);
}

/// Time of day for scheduling
class TimeOfDay {
  final int hour;
  final int minute;
  
  const TimeOfDay({required this.hour, required this.minute});
  
  factory TimeOfDay.now() {
    final now = DateTime.now();
    return TimeOfDay(hour: now.hour, minute: now.minute);
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDay && hour == other.hour && minute == other.minute;
  
  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
  
  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Cache statistics for monitoring
class CacheStatistics {
  final int totalRequests;
  final int cacheHits;
  final int cacheMisses;
  final double hitRate;
  final Duration averageResponseTime;
  final int memoryUsageBytes;
  final int diskUsageBytes;
  final Map<String, int> popularItems;
  final List<String> recentMisses;
  
  CacheStatistics({
    required this.totalRequests,
    required this.cacheHits,
    required this.cacheMisses,
    required this.hitRate,
    required this.averageResponseTime,
    required this.memoryUsageBytes,
    required this.diskUsageBytes,
    required this.popularItems,
    required this.recentMisses,
  });
  
  factory CacheStatistics.from(CacheMetricsSnapshot snapshot) {
    return CacheStatistics(
      totalRequests: snapshot.hits + snapshot.misses,
      cacheHits: snapshot.hits,
      cacheMisses: snapshot.misses,
      hitRate: snapshot.hitRate,
      averageResponseTime: snapshot.averageLookupTime,
      memoryUsageBytes: 0, // Would be calculated from memory cache
      diskUsageBytes: 0, // Would be calculated from disk cache
      popularItems: {}, // Would be tracked separately
      recentMisses: [], // Would be tracked separately
    );
  }
  
  bool get meetsPerformanceRequirements {
    return hitRate >= 0.95 && // 95%+ hit rate
           averageResponseTime.inMilliseconds < 10 && // < 10ms lookup
           memoryUsageBytes < 100 * 1024 * 1024; // < 100MB memory
  }
}

/// Helper class for cache management
class PictureCacheManager {
  static PictureCache? _instance;
  
  /// Get or create singleton cache instance
  static PictureCache get instance {
    _instance ??= PictureCache();
    return _instance!;
  }
  
  /// Initialize with custom configuration
  static Future<PictureCache> initialize({
    PictureCacheConfig? config,
  }) async {
    _instance = PictureCache(config: config);
    await _instance!.ready;
    return _instance!;
  }
  
  /// Dispose of the cache instance
  static void dispose() {
    _instance?.dispose();
    _instance = null;
  }
  
  /// Warm cache with common assets
  static Future<void> warmCommonAssets(List<String> assetIds) async {
    final cache = instance;
    await cache.prefetch(
      assetIds,
      loader: DefaultPictureLoader(),
      priority: CachePriority.high,
    );
  }
  
  /// Handle app lifecycle changes
  static void handleAppLifecycle(AppLifecycleState state) {
    final cache = instance;
    switch (state) {
      case AppLifecycleState.resumed:
        // Resume warming
        cache.resume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Pause operations to save battery
        cache.pause();
        break;
      case AppLifecycleState.detached:
        // Clear caches
        cache.clear().catchError((e) {
          debugPrint('Failed to clear cache: $e');
        });
        break;
      case AppLifecycleState.hidden:
        // Reduce memory usage
        cache.handleMemoryPressure(MemoryPressureLevel.high);
        break;
    }
  }
  
  /// Get cache statistics
  static CacheStatistics getStatistics() {
    return CacheStatistics.from(instance.getMetrics());
  }
  
  /// Check if cache meets performance requirements
  static bool checkPerformance() {
    return instance.getMetrics().meetsPerformanceRequirements;
  }
}
