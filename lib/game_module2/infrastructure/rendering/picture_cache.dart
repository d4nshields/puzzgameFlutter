/// Advanced Picture Caching System for Puzzle Nook
/// 
/// This implementation provides a high-performance multi-level cache for
/// ui.Picture objects with automatic warming, priority-based retention,
/// and comprehensive metrics tracking.
/// 
/// Features:
/// - Two-tier cache: Memory (L1) and Disk (L2)
/// - LRU eviction with priority weighting
/// - Automatic cache warming based on usage patterns
/// - Comprehensive metrics and monitoring
/// - Async loading with cancellation support
/// - Memory pressure handling

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// Import types first
import 'picture_cache_types.dart';

/// Main picture cache with multi-level storage
class PictureCache {
  // Cache configuration
  final PictureCacheConfig config;
  
  // Cache levels
  late final MemoryCache _memoryCache;
  late final DiskCache _diskCache;
  
  // Cache management
  late final CacheMetrics _metrics;
  late final CacheWarmer _warmer;
  late final CacheKeyGenerator _keyGenerator;
  
  // State
  bool _isInitialized = false;
  final _initCompleter = Completer<void>();
  Timer? _evictionTimer;
  Timer? _metricsTimer;
  
  // Listeners
  final _listeners = <VoidCallback>[];
  
  PictureCache({
    PictureCacheConfig? config,
  }) : config = config ?? const PictureCacheConfig() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize components
      _memoryCache = MemoryCache(
        maxSizeBytes: config.maxMemorySizeBytes,
        maxEntries: config.maxMemoryEntries,
      );
      
      _diskCache = await DiskCache.create(
        maxSizeBytes: config.maxDiskSizeBytes,
        cacheDirectory: config.cacheDirectory,
      );
      
      _metrics = CacheMetrics();
      _keyGenerator = CacheKeyGenerator();
      
      _warmer = CacheWarmer(
        cache: this,
        config: config.warmerConfig,
      );
      
      // Start background tasks
      _startEvictionTimer();
      _startMetricsTimer();
      
      // Warm cache if enabled
      if (config.enableAutoWarming) {
        _warmer.startWarming();
      }
      
      _isInitialized = true;
      _initCompleter.complete();
      
      debugPrint('PictureCache: Initialized with config: $config');
      
    } catch (e, stack) {
      debugPrint('PictureCache: Initialization failed: $e');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stack);
      }
      _initCompleter.completeError(e, stack);
    }
  }
  
  /// Ensure cache is initialized before use
  Future<void> get ready => _initCompleter.future;
  
  /// Get a picture from cache or load it
  Future<ui.Picture?> get(
    String id, {
    PictureLoader? loader,
    CachePriority priority = CachePriority.normal,
    CancellationToken? cancellationToken,
  }) async {
    await ready;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Generate cache key
      final key = _keyGenerator.generate(id);
      
      // Check L1 (memory) cache
      var entry = _memoryCache.get(key);
      if (entry != null) {
        _metrics.recordHit(CacheLevel.memory, stopwatch.elapsed);
        _updateAccessInfo(entry, priority);
        return entry.picture;
      }
      
      // Check cancellation
      if (cancellationToken?.isCancelled ?? false) {
        throw CancellationException();
      }
      
      // Check L2 (disk) cache
      final diskData = await _diskCache.get(key);
      if (diskData != null) {
        _metrics.recordHit(CacheLevel.disk, stopwatch.elapsed);
        
        // Deserialize and promote to memory cache
        final picture = await _deserializePicture(diskData);
        if (picture != null) {
          entry = CacheEntry(
            key: key,
            picture: picture,
            sizeBytes: diskData.length,
            priority: priority,
          );
          
          _memoryCache.put(key, entry);
          _updateAccessInfo(entry, priority);
          return picture;
        }
      }
      
      // Check cancellation
      if (cancellationToken?.isCancelled ?? false) {
        throw CancellationException();
      }
      
      // Cache miss - load if loader provided
      _metrics.recordMiss(stopwatch.elapsed);
      
      if (loader != null) {
        final picture = await loader.load(id, cancellationToken);
        if (picture != null) {
          await _cachePicture(key, picture, priority);
          return picture;
        }
      }
      
      return null;
      
    } catch (e) {
      _metrics.recordError(e);
      
      if (e is CancellationException) {
        debugPrint('PictureCache: Request cancelled for $id');
      } else {
        debugPrint('PictureCache: Error getting $id: $e');
      }
      
      rethrow;
    }
  }
  
  /// Prefetch pictures into cache
  Future<void> prefetch(
    List<String> ids, {
    PictureLoader? loader,
    CachePriority priority = CachePriority.normal,
  }) async {
    await ready;
    
    final futures = <Future>[];
    
    for (final id in ids) {
      futures.add(
        get(id, loader: loader, priority: priority).catchError((e) {
          debugPrint('PictureCache: Prefetch failed for $id: $e');
          return null;
        }),
      );
    }
    
    await Future.wait(futures);
  }
  
  /// Put a picture directly into cache
  Future<void> put(
    String id,
    ui.Picture picture, {
    CachePriority priority = CachePriority.normal,
  }) async {
    await ready;
    
    final key = _keyGenerator.generate(id);
    await _cachePicture(key, picture, priority);
  }
  
  /// Remove a picture from cache
  Future<void> remove(String id) async {
    await ready;
    
    final key = _keyGenerator.generate(id);
    _memoryCache.remove(key);
    await _diskCache.remove(key);
    
    debugPrint('PictureCache: Removed $id');
  }
  
  /// Clear entire cache
  Future<void> clear() async {
    await ready;
    
    _memoryCache.clear();
    await _diskCache.clear();
    _metrics.reset();
    
    debugPrint('PictureCache: Cleared all entries');
    _notifyListeners();
  }
  
  /// Evict entries based on size constraints and priority
  Future<void> evict() async {
    await ready;
    
    final stopwatch = Stopwatch()..start();
    
    // Evict from memory cache
    final memoryEvicted = _memoryCache.evict();
    
    // Evict from disk cache if needed
    final diskEvicted = await _diskCache.evict();
    
    if (memoryEvicted > 0 || diskEvicted > 0) {
      debugPrint('PictureCache: Evicted $memoryEvicted from memory, '
          '$diskEvicted from disk in ${stopwatch.elapsedMilliseconds}ms');
      _notifyListeners();
    }
    
    _metrics.recordEviction(memoryEvicted + diskEvicted, stopwatch.elapsed);
  }
  
  /// Get current cache metrics
  CacheMetricsSnapshot getMetrics() {
    return _metrics.getSnapshot();
  }
  
  /// Set cache warming patterns
  void setWarmingPatterns(List<WarmingPattern> patterns) {
    _warmer.setPatterns(patterns);
  }
  
  /// Handle memory pressure
  void handleMemoryPressure(MemoryPressureLevel level) {
    debugPrint('PictureCache: Handling memory pressure: $level');
    
    switch (level) {
      case MemoryPressureLevel.low:
        // No action needed
        break;
      case MemoryPressureLevel.medium:
        // Evict low priority items
        _memoryCache.evictLowPriority();
        _notifyListeners();
        break;
      case MemoryPressureLevel.high:
        // Aggressive eviction
        _memoryCache.evictAggressively();
        _notifyListeners();
        break;
      case MemoryPressureLevel.critical:
        // Clear memory cache
        _memoryCache.clear();
        _notifyListeners();
        break;
    }
  }
  
  // Internal methods
  
  Future<void> _cachePicture(
    CacheKey key,
    ui.Picture picture,
    CachePriority priority,
  ) async {
    // Serialize picture
    final data = await _serializePicture(picture);
    if (data == null) return;
    
    // Create cache entry
    final entry = CacheEntry(
      key: key,
      picture: picture,
      sizeBytes: data.length,
      priority: priority,
    );
    
    // Store in memory cache
    _memoryCache.put(key, entry);
    
    // Store in disk cache
    await _diskCache.put(key, data);
    
    // Update metrics
    _metrics.recordPut(data.length);
  }
  
  Future<Uint8List?> _serializePicture(ui.Picture picture) async {
    try {
      // Record picture to get bounds
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawPicture(picture);
      final recordedPicture = recorder.endRecording();
      
      // Convert to image for serialization
      final image = await recordedPicture.toImage(1000, 1000);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
      
    } catch (e) {
      debugPrint('PictureCache: Failed to serialize picture: $e');
      return null;
    }
  }
  
  Future<ui.Picture?> _deserializePicture(Uint8List data) async {
    try {
      // Decode image
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Convert to picture
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(image, Offset.zero, Paint());
      
      return recorder.endRecording();
      
    } catch (e) {
      debugPrint('PictureCache: Failed to deserialize picture: $e');
      return null;
    }
  }
  
  void _updateAccessInfo(CacheEntry entry, CachePriority priority) {
    entry.lastAccessed = DateTime.now();
    entry.accessCount++;
    
    // Update priority if higher
    if (priority.index > entry.priority.index) {
      entry.priority = priority;
    }
    
    // Track for warming patterns
    _warmer.recordAccess(entry.key.value, entry.lastAccessed);
  }
  
  void _startEvictionTimer() {
    _evictionTimer = Timer.periodic(
      Duration(seconds: config.evictionIntervalSeconds),
      (_) => evict(),
    );
  }
  
  void _startMetricsTimer() {
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _logMetrics(),
    );
  }
  
  void _logMetrics() {
    final snapshot = _metrics.getSnapshot();
    debugPrint('PictureCache Metrics: ${snapshot.toJson()}');
  }
  
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
  
  /// Resume cache operations
  void resume() {
    if (config.enableAutoWarming) {
      _warmer.startWarming();
    }
  }
  
  /// Pause cache operations
  void pause() {
    _warmer.stopWarming();
  }
  
  void dispose() {
    _evictionTimer?.cancel();
    _metricsTimer?.cancel();
    _warmer.dispose();
    _memoryCache.dispose();
    _diskCache.dispose();
    _listeners.clear();
  }
}

/// Memory cache implementation (L1)
class MemoryCache {
  final int maxSizeBytes;
  final int maxEntries;
  
  final Map<CacheKey, CacheEntry> _entries = {};
  final LinkedList<_LRUNode> _lruList = LinkedList();
  final Map<CacheKey, _LRUNode> _lruMap = {};
  
  int _currentSizeBytes = 0;
  
  MemoryCache({
    required this.maxSizeBytes,
    required this.maxEntries,
  });
  
  CacheEntry? get(CacheKey key) {
    final entry = _entries[key];
    if (entry != null) {
      // Move to front of LRU
      _updateLRU(key);
    }
    return entry;
  }
  
  void put(CacheKey key, CacheEntry entry) {
    // Remove existing entry if present
    remove(key);
    
    // Check if eviction needed
    while (_shouldEvict(entry.sizeBytes)) {
      _evictOne();
    }
    
    // Add new entry
    _entries[key] = entry;
    _currentSizeBytes += entry.sizeBytes;
    
    // Update LRU
    final node = _LRUNode(key);
    _lruList.addFirst(node);
    _lruMap[key] = node;
  }
  
  void remove(CacheKey key) {
    final entry = _entries.remove(key);
    if (entry != null) {
      _currentSizeBytes -= entry.sizeBytes;
      
      // Remove from LRU
      final node = _lruMap.remove(key);
      node?.unlink();
    }
  }
  
  void clear() {
    _entries.clear();
    _lruList.clear();
    _lruMap.clear();
    _currentSizeBytes = 0;
  }
  
  int evict() {
    int evicted = 0;
    
    while (_currentSizeBytes > (maxSizeBytes * 0.9).toInt() || 
    _entries.length > (maxEntries * 0.9).toInt()) {
      if (_evictOne()) {
        evicted++;
      } else {
        break;
      }
    }
    
    return evicted;
  }
  
  void evictLowPriority() {
    final toEvict = <CacheKey>[];
    
    for (final entry in _entries.entries) {
      if (entry.value.priority == CachePriority.low) {
        toEvict.add(entry.key);
      }
    }
    
    for (final key in toEvict) {
      remove(key);
    }
  }
  
  void evictAggressively() {
    // Keep only high priority items
    final toEvict = <CacheKey>[];
    
    for (final entry in _entries.entries) {
      if (entry.value.priority != CachePriority.high) {
        toEvict.add(entry.key);
      }
    }
    
    for (final key in toEvict) {
      remove(key);
    }
  }
  
  bool _shouldEvict(int additionalBytes) {
    return _currentSizeBytes + additionalBytes > maxSizeBytes ||
           _entries.length >= maxEntries;
  }
  
  bool _evictOne() {
    if (_lruList.isEmpty) return false;
    
    // Find least recently used item with lowest priority
    _LRUNode? candidate;
    var lowestPriority = CachePriority.high;
    
    for (final node in _lruList) {
      final entry = _entries[node.key];
      if (entry != null && entry.priority.index <= lowestPriority.index) {
        candidate = node;
        lowestPriority = entry.priority;
        
        // Early exit for low priority
        if (lowestPriority == CachePriority.low) break;
      }
    }
    
    if (candidate != null) {
      remove(candidate.key);
      return true;
    }
    
    return false;
  }
  
  void _updateLRU(CacheKey key) {
    final node = _lruMap[key];
    if (node != null) {
      node.unlink();
      _lruList.addFirst(node);
    }
  }
  
  void dispose() {
    clear();
  }
}

/// Disk cache implementation (L2)
class DiskCache {
  final int maxSizeBytes;
  final Directory cacheDir;
  
  final Map<CacheKey, DiskCacheEntry> _index = {};
  int _currentSizeBytes = 0;
  bool _isLoaded = false;
  
  DiskCache._({
    required this.maxSizeBytes,
    required this.cacheDir,
  });
  
  static Future<DiskCache> create({
    required int maxSizeBytes,
    String? cacheDirectory,
  }) async {
    final dir = await _getCacheDirectory(cacheDirectory);
    final cache = DiskCache._(
      maxSizeBytes: maxSizeBytes,
      cacheDir: dir,
    );
    
    await cache._loadIndex();
    return cache;
  }
  
  static Future<Directory> _getCacheDirectory(String? customPath) async {
    Directory dir;
    
    if (customPath != null) {
      dir = Directory(customPath);
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      dir = Directory(path.join(appDir.path, 'picture_cache'));
    }
    
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return dir;
  }
  
  Future<void> _loadIndex() async {
    if (_isLoaded) return;
    
    try {
      final indexFile = File(path.join(cacheDir.path, 'index.json'));
      if (await indexFile.exists()) {
        final content = await indexFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        
        for (final entry in json.entries) {
          final key = CacheKey(entry.key);
          final data = entry.value as Map<String, dynamic>;
          _index[key] = DiskCacheEntry.fromJson(data);
        }
        
        // Calculate current size
        _currentSizeBytes = _index.values
            .fold<int>(0, (sum, entry) => sum + entry.sizeBytes);
      }
      
      _isLoaded = true;
      
    } catch (e) {
      debugPrint('DiskCache: Failed to load index: $e');
      // Start with empty cache
      _index.clear();
      _isLoaded = true;
    }
  }
  
  Future<void> _saveIndex() async {
    try {
      final indexFile = File(path.join(cacheDir.path, 'index.json'));
      final json = <String, dynamic>{};
      
      for (final entry in _index.entries) {
        json[entry.key.value] = entry.value.toJson();
      }
      
      await indexFile.writeAsString(jsonEncode(json));
      
    } catch (e) {
      debugPrint('DiskCache: Failed to save index: $e');
    }
  }
  
  Future<Uint8List?> get(CacheKey key) async {
    final entry = _index[key];
    if (entry == null) return null;
    
    try {
      final file = File(path.join(cacheDir.path, entry.filename));
      if (await file.exists()) {
        entry.lastAccessed = DateTime.now();
        entry.accessCount++;
        return await file.readAsBytes();
      } else {
        // File missing, remove from index
        _index.remove(key);
        _currentSizeBytes -= entry.sizeBytes;
      }
    } catch (e) {
      debugPrint('DiskCache: Failed to read ${entry.filename}: $e');
    }
    
    return null;
  }
  
  Future<void> put(CacheKey key, Uint8List data) async {
    // Check if eviction needed
    while (_currentSizeBytes + data.length > maxSizeBytes) {
      await _evictOne();
    }
    
    final filename = '${key.value}.cache';
    final file = File(path.join(cacheDir.path, filename));
    
    try {
      await file.writeAsBytes(data);
      
      _index[key] = DiskCacheEntry(
        filename: filename,
        sizeBytes: data.length,
        created: DateTime.now(),
        lastAccessed: DateTime.now(),
      );
      
      _currentSizeBytes += data.length;
      await _saveIndex();
      
    } catch (e) {
      debugPrint('DiskCache: Failed to write $filename: $e');
    }
  }
  
  Future<void> remove(CacheKey key) async {
    final entry = _index.remove(key);
    if (entry == null) return;
    
    _currentSizeBytes -= entry.sizeBytes;
    
    try {
      final file = File(path.join(cacheDir.path, entry.filename));
      if (await file.exists()) {
        await file.delete();
      }
      await _saveIndex();
    } catch (e) {
      debugPrint('DiskCache: Failed to delete ${entry.filename}: $e');
    }
  }
  
  Future<void> clear() async {
    // Delete all cache files
    await for (final entity in cacheDir.list()) {
      if (entity is File && entity.path.endsWith('.cache')) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('DiskCache: Failed to delete ${entity.path}: $e');
        }
      }
    }
    
    _index.clear();
    _currentSizeBytes = 0;
    await _saveIndex();
  }
  
  Future<int> evict() async {
    int evicted = 0;
    
    while (_currentSizeBytes > (maxSizeBytes * 0.9).toInt()) {
      if (await _evictOne()) {
        evicted++;
      } else {
        break;
      }
    }
    
    return evicted;
  }
  
  Future<bool> _evictOne() async {
    if (_index.isEmpty) return false;
    
    // Find least recently accessed entry
    CacheKey? candidateKey;
    DateTime? oldestAccess;
    
    for (final entry in _index.entries) {
      if (oldestAccess == null || 
          entry.value.lastAccessed.isBefore(oldestAccess)) {
        candidateKey = entry.key;
        oldestAccess = entry.value.lastAccessed;
      }
    }
    
    if (candidateKey != null) {
      await remove(candidateKey);
      return true;
    }
    
    return false;
  }
  
  void dispose() {
    _saveIndex();
  }
}

/// Cache key generation
class CacheKeyGenerator {
  CacheKey generate(String id) {
    final bytes = utf8.encode(id);
    final digest = sha256.convert(bytes);
    return CacheKey(digest.toString());
  }
}

/// Cache warmer for predictive loading
class CacheWarmer {
  final PictureCache cache;
  final CacheWarmerConfig config;
  
  final Map<String, List<DateTime>> _accessHistory = {};
  final List<WarmingPattern> _patterns = [];
  Timer? _warmingTimer;
  bool _isWarming = false;
  
  CacheWarmer({
    required this.cache,
    required this.config,
  });
  
  void startWarming() {
    _warmingTimer = Timer.periodic(
      Duration(seconds: config.warmingIntervalSeconds),
      (_) => _performWarming(),
    );
  }
  
  void stopWarming() {
    _warmingTimer?.cancel();
    _warmingTimer = null;
  }
  
  void setPatterns(List<WarmingPattern> patterns) {
    _patterns.clear();
    _patterns.addAll(patterns);
  }
  
  void recordAccess(String id, DateTime time) {
    _accessHistory.putIfAbsent(id, () => []).add(time);
    
    // Limit history size
    final history = _accessHistory[id]!;
    while (history.length > config.maxHistorySize) {
      history.removeAt(0);
    }
  }
  
  Future<void> _performWarming() async {
    if (_isWarming) return;
    _isWarming = true;
    
    try {
      final predictions = _generatePredictions();
      
      if (predictions.isNotEmpty) {
        debugPrint('CacheWarmer: Warming ${predictions.length} items');
        await cache.prefetch(predictions, priority: CachePriority.low);
      }
      
    } catch (e) {
      debugPrint('CacheWarmer: Error during warming: $e');
    } finally {
      _isWarming = false;
    }
  }
  
  List<String> _generatePredictions() {
    final predictions = <String>{};
    
    // Pattern-based predictions
    for (final pattern in _patterns) {
      predictions.addAll(pattern.getPredictions());
    }
    
    // History-based predictions
    final now = DateTime.now();
    for (final entry in _accessHistory.entries) {
      final history = entry.value;
      if (history.isEmpty) continue;
      
      // Check if frequently accessed
      final recentAccesses = history.where(
        (time) => now.difference(time).inMinutes < 5,
      ).length;
      
      if (recentAccesses >= config.frequencyThreshold) {
        predictions.add(entry.key);
      }
    }
    
    return predictions.take(config.maxWarmingItems).toList();
  }
  
  void dispose() {
    stopWarming();
    _accessHistory.clear();
    _patterns.clear();
  }
}

/// Cache metrics tracking
class CacheMetrics {
  int _hits = 0;
  int _misses = 0;
  int _puts = 0;
  int _evictions = 0;
  int _errors = 0;
  
  final Map<CacheLevel, int> _levelHits = {};
  final Map<CacheLevel, Duration> _levelLatency = {};
  final Queue<Duration> _lookupTimes = Queue();
  
  int _totalBytes = 0;
  final DateTime _startTime = DateTime.now();
  
  void recordHit(CacheLevel level, Duration lookupTime) {
    _hits++;
    _levelHits[level] = (_levelHits[level] ?? 0) + 1;
    _levelLatency[level] = lookupTime;
    _recordLookupTime(lookupTime);
  }
  
  void recordMiss(Duration lookupTime) {
    _misses++;
    _recordLookupTime(lookupTime);
  }
  
  void recordPut(int bytes) {
    _puts++;
    _totalBytes += bytes;
  }
  
  void recordEviction(int count, Duration duration) {
    _evictions += count;
  }
  
  void recordError(dynamic error) {
    _errors++;
  }
  
  void _recordLookupTime(Duration time) {
    _lookupTimes.add(time);
    while (_lookupTimes.length > 1000) {
      _lookupTimes.removeFirst();
    }
  }
  
  CacheMetricsSnapshot getSnapshot() {
    final totalRequests = _hits + _misses;
    final hitRate = totalRequests > 0 ? _hits / totalRequests : 0.0;
    
    Duration avgLookupTime = Duration.zero;
    if (_lookupTimes.isNotEmpty) {
      final totalMicros = _lookupTimes
          .fold<int>(0, (sum, d) => sum + d.inMicroseconds);
      avgLookupTime = Duration(microseconds: totalMicros ~/ _lookupTimes.length);
    }
    
    return CacheMetricsSnapshot(
      hits: _hits,
      misses: _misses,
      puts: _puts,
      evictions: _evictions,
      errors: _errors,
      hitRate: hitRate,
      averageLookupTime: avgLookupTime,
      totalBytes: _totalBytes,
      uptime: DateTime.now().difference(_startTime),
      levelHits: Map.from(_levelHits),
      levelLatency: Map.from(_levelLatency),
    );
  }
  
  void reset() {
    _hits = 0;
    _misses = 0;
    _puts = 0;
    _evictions = 0;
    _errors = 0;
    _levelHits.clear();
    _levelLatency.clear();
    _lookupTimes.clear();
    _totalBytes = 0;
  }
}

// Continue with data classes...

/// Internal LRU node for linked list
base class _LRUNode extends LinkedListEntry<_LRUNode> {
  final CacheKey key;
  
  _LRUNode(this.key);
}
