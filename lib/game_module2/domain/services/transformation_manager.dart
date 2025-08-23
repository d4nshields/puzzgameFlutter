import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';
import 'coordinate_system.dart';

/// Result of a transformation operation with timing information.
@immutable
class TransformResult<T> {
  final T result;
  final Duration executionTime;
  final bool wasFromCache;
  final String? cacheKey;

  const TransformResult({
    required this.result,
    required this.executionTime,
    this.wasFromCache = false,
    this.cacheKey,
  });
}

/// Batch transformation request for multiple points.
@immutable
class BatchTransformRequest<TFrom, TTo> {
  final List<TFrom> points;
  final String transformationType;
  final Map<String, dynamic>? metadata;

  const BatchTransformRequest({
    required this.points,
    required this.transformationType,
    this.metadata,
  });
}

/// Result of a batch transformation operation.
@immutable
class BatchTransformResult<T> {
  final List<T?> results;
  final Duration totalExecutionTime;
  final int cacheHits;
  final int cacheMisses;
  final double cacheHitRate;

  const BatchTransformResult({
    required this.results,
    required this.totalExecutionTime,
    required this.cacheHits,
    required this.cacheMisses,
  }) : cacheHitRate = cacheHits / (cacheHits + cacheMisses);
}

/// Interpolation mode for animated transformations.
enum InterpolationMode {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  cubic,
  bounce,
  elastic,
}

/// Configuration for the transformation cache.
@immutable
class TransformCacheConfig {
  final int maxEntries;
  final Duration ttl;
  final bool enableMetrics;
  final double targetHitRate;

  const TransformCacheConfig({
    this.maxEntries = 1000,
    this.ttl = const Duration(minutes: 5),
    this.enableMetrics = true,
    this.targetHitRate = 0.9,
  });
}

/// LRU cache for transformation results with TTL support.
class TransformCache {
  final TransformCacheConfig _config;
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();
  final Map<String, int> _hitCount = {};
  final Map<String, int> _missCount = {};
  final Stopwatch _metricsStopwatch = Stopwatch();
  
  int _totalHits = 0;
  int _totalMisses = 0;
  int _evictions = 0;
  Timer? _cleanupTimer;

  TransformCache(this._config) {
    if (_config.enableMetrics) {
      _metricsStopwatch.start();
    }
    // Schedule periodic cleanup
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _cleanupExpired(),
    );
  }

  /// Generates a cache key for a transformation.
  String generateKey(String type, dynamic from, [Map<String, dynamic>? params]) {
    final buffer = StringBuffer(type);
    buffer.write(':');
    // Use toString() instead of hashCode for consistent keys
    buffer.write(from.toString());
    
    if (params != null) {
      final sortedParams = params.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sortedParams) {
        buffer.write(':${entry.key}=${entry.value}');
      }
    }
    
    return buffer.toString();
  }

  /// Gets a value from the cache if it exists and is not expired.
  T? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null) {
      _recordMiss(key);
      return null;
    }
    
    if (_isExpired(entry)) {
      _cache.remove(key);
      _recordMiss(key);
      return null;
    }
    
    // Move to end (most recently used)
    _cache.remove(key);
    _cache[key] = entry;
    
    _recordHit(key);
    entry.accessCount++;
    entry.lastAccess = DateTime.now();
    
    return entry.value as T;
  }

  /// Puts a value in the cache.
  void put<T>(String key, T value, [Duration? customTtl]) {
    // Evict if necessary
    while (_cache.length >= _config.maxEntries) {
      _evictLRU();
    }
    
    _cache[key] = _CacheEntry(
      value: value,
      timestamp: DateTime.now(),
      ttl: customTtl ?? _config.ttl,
    );
  }

  /// Gets a value from the cache or computes it if not present.
  Future<TransformResult<T>> getOrCompute<T>(
    String key,
    Future<T> Function() compute,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    // Check cache first
    final cached = get<T>(key);
    if (cached != null) {
      stopwatch.stop();
      return TransformResult(
        result: cached,
        executionTime: stopwatch.elapsed,
        wasFromCache: true,
        cacheKey: key,
      );
    }
    
    // Compute value
    final value = await compute();
    put(key, value);
    
    stopwatch.stop();
    return TransformResult(
      result: value,
      executionTime: stopwatch.elapsed,
      wasFromCache: false,
      cacheKey: key,
    );
  }

  /// Invalidates entries matching a pattern.
  void invalidatePattern(String pattern) {
    final regex = RegExp(pattern);
    final keysToRemove = _cache.keys.where((key) => regex.hasMatch(key)).toList();
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Clears the entire cache.
  void clear() {
    _cache.clear();
    _hitCount.clear();
    _missCount.clear();
    _totalHits = 0;
    _totalMisses = 0;
  }

  /// Gets cache metrics.
  Map<String, dynamic> getMetrics() {
    if (!_config.enableMetrics) {
      return {};
    }
    
    final hitRate = _totalHits + _totalMisses > 0
        ? _totalHits / (_totalHits + _totalMisses)
        : 0.0;
    
    return {
      'totalHits': _totalHits,
      'totalMisses': _totalMisses,
      'hitRate': hitRate,
      'evictions': _evictions,
      'currentSize': _cache.length,
      'maxSize': _config.maxEntries,
      'uptimeMs': _metricsStopwatch.elapsedMilliseconds,
      'meetsTarget': hitRate >= _config.targetHitRate,
    };
  }

  /// Disposes of the cache and cleanup timer.
  void dispose() {
    _cleanupTimer?.cancel();
    clear();
  }

  void _recordHit(String key) {
    if (!_config.enableMetrics) return;
    _totalHits++;
    _hitCount[key] = (_hitCount[key] ?? 0) + 1;
  }

  void _recordMiss(String key) {
    if (!_config.enableMetrics) return;
    _totalMisses++;
    _missCount[key] = (_missCount[key] ?? 0) + 1;
  }

  void _evictLRU() {
    if (_cache.isEmpty) return;
    
    // Remove the least recently used (first) entry
    final firstKey = _cache.keys.first;
    _cache.remove(firstKey);
    _evictions++;
  }

  bool _isExpired(_CacheEntry entry) {
    return DateTime.now().difference(entry.timestamp) > entry.ttl;
  }

  void _cleanupExpired() {
    final keysToRemove = <String>[];
    
    for (final entry in _cache.entries) {
      if (_isExpired(entry.value)) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }
}

/// Internal cache entry with metadata.
class _CacheEntry {
  final dynamic value;
  final DateTime timestamp;
  final Duration ttl;
  DateTime lastAccess;
  int accessCount;

  _CacheEntry({
    required this.value,
    required this.timestamp,
    required this.ttl,
  })  : lastAccess = timestamp,
        accessCount = 0;
}

/// Manages batch transformations for multiple points.
class BatchTransformation {
  final TransformCache _cache;
  final CoordinateSystem _coordSystem;
  static const int _batchSize = 100; // Process in chunks for better memory usage

  BatchTransformation({
    required TransformCache cache,
    required CoordinateSystem coordSystem,
  })  : _cache = cache,
        _coordSystem = coordSystem;

  /// Transforms multiple screen points to canvas points.
  Future<BatchTransformResult<CanvasPoint>> batchScreenToCanvas(
    List<ScreenPoint> points,
  ) async {
    return _batchTransform(
      points,
      'screen_to_canvas',
      (point) => _coordSystem.screenToCanvas(point),
    );
  }

  /// Transforms multiple canvas points to grid points.
  Future<BatchTransformResult<GridPoint?>> batchCanvasToGrid(
    List<CanvasPoint> points,
  ) async {
    return _batchTransform(
      points,
      'canvas_to_grid',
      (point) => _coordSystem.canvasToGrid(point),
    );
  }

  /// Transforms multiple grid points to canvas points.
  Future<BatchTransformResult<CanvasPoint>> batchGridToCanvas(
    List<GridPoint> points,
  ) async {
    return _batchTransform(
      points,
      'grid_to_canvas',
      (point) => _coordSystem.gridToCanvas(point),
    );
  }

  /// Generic batch transformation with caching.
  Future<BatchTransformResult<TTo>> _batchTransform<TFrom, TTo>(
    List<TFrom> points,
    String transformType,
    TTo Function(TFrom) transform,
  ) async {
    final stopwatch = Stopwatch()..start();
    final results = <TTo?>[];
    int cacheHits = 0;
    int cacheMisses = 0;

    // Process in batches to avoid blocking
    for (int i = 0; i < points.length; i += _batchSize) {
      final end = math.min(i + _batchSize, points.length);
      final batch = points.sublist(i, end);
      
      // Process batch asynchronously
      await Future.microtask(() {
        for (final point in batch) {
          final cacheKey = _cache.generateKey(transformType, point);
          final cached = _cache.get<TTo>(cacheKey);
          
          if (cached != null) {
            results.add(cached);
            cacheHits++;
          } else {
            final result = transform(point);
            results.add(result);
            _cache.put(cacheKey, result);
            cacheMisses++;
          }
        }
      });
    }

    stopwatch.stop();
    return BatchTransformResult(
      results: results,
      totalExecutionTime: stopwatch.elapsed,
      cacheHits: cacheHits,
      cacheMisses: cacheMisses,
    );
  }

  /// Optimized batch transformation for grid bounds.
  Future<List<ui.Rect>> batchGridCellBounds(List<GridPoint> points) async {
    final stopwatch = Stopwatch()..start();
    final results = <ui.Rect>[];

    for (int i = 0; i < points.length; i += _batchSize) {
      final end = math.min(i + _batchSize, points.length);
      final batch = points.sublist(i, end);
      
      await Future.microtask(() {
        for (final point in batch) {
          results.add(_coordSystem.gridCellToCanvasBounds(point));
        }
      });
    }

    stopwatch.stop();
    return results;
  }
}

/// Handles interpolated transformations for smooth animations.
class InterpolatedTransform {
  final Duration duration;
  final InterpolationMode mode;
  final int fps;
  
  InterpolatedTransform({
    required this.duration,
    this.mode = InterpolationMode.easeInOut,
    this.fps = 60,
  });

  /// Interpolates between two canvas points.
  Stream<CanvasPoint> interpolateCanvas(
    CanvasPoint from,
    CanvasPoint to,
  ) async* {
    final frames = (duration.inMilliseconds * fps / 1000).round();
    final frameDuration = Duration(microseconds: (1000000 / fps).round());
    
    for (int i = 0; i <= frames; i++) {
      final t = i / frames;
      final easedT = _applyEasing(t, mode);
      
      yield CanvasPoint(
        from.x + (to.x - from.x) * easedT,
        from.y + (to.y - from.y) * easedT,
      );
      
      if (i < frames) {
        await Future.delayed(frameDuration);
      }
    }
  }

  /// Interpolates between two workspace points.
  Stream<WorkspacePoint> interpolateWorkspace(
    WorkspacePoint from,
    WorkspacePoint to,
  ) async* {
    final frames = (duration.inMilliseconds * fps / 1000).round();
    final frameDuration = Duration(microseconds: (1000000 / fps).round());
    
    for (int i = 0; i <= frames; i++) {
      final t = i / frames;
      final easedT = _applyEasing(t, mode);
      
      yield WorkspacePoint(
        from.x + (to.x - from.x) * easedT,
        from.y + (to.y - from.y) * easedT,
      );
      
      if (i < frames) {
        await Future.delayed(frameDuration);
      }
    }
  }

  /// Interpolates zoom level.
  Stream<double> interpolateZoom(
    double fromZoom,
    double toZoom,
  ) async* {
    final frames = (duration.inMilliseconds * fps / 1000).round();
    final frameDuration = Duration(microseconds: (1000000 / fps).round());
    
    for (int i = 0; i <= frames; i++) {
      final t = i / frames;
      final easedT = _applyEasing(t, mode);
      
      yield fromZoom + (toZoom - fromZoom) * easedT;
      
      if (i < frames) {
        await Future.delayed(frameDuration);
      }
    }
  }

  /// Interpolates a complete transformation matrix.
  Stream<Matrix4> interpolateMatrix(
    Matrix4 from,
    Matrix4 to,
  ) async* {
    final frames = (duration.inMilliseconds * fps / 1000).round();
    final frameDuration = Duration(microseconds: (1000000 / fps).round());
    
    // Decompose matrices
    final fromTranslation = from.getTranslation();
    final toTranslation = to.getTranslation();
    final fromScale = _getScale(from);
    final toScale = _getScale(to);
    
    for (int i = 0; i <= frames; i++) {
      final t = i / frames;
      final easedT = _applyEasing(t, mode);
      
      final matrix = Matrix4.identity();
      
      // Interpolate translation
      final translation = fromTranslation + (toTranslation - fromTranslation) * easedT;
      matrix.translate(translation.x, translation.y, translation.z);
      
      // Interpolate scale
      final scale = fromScale + (toScale - fromScale) * easedT;
      matrix.scale(scale.x, scale.y, scale.z);
      
      yield matrix;
      
      if (i < frames) {
        await Future.delayed(frameDuration);
      }
    }
  }

  Vector3 _getScale(Matrix4 matrix) {
    return Vector3(
      matrix.getRow(0).length,
      matrix.getRow(1).length,
      matrix.getRow(2).length,
    );
  }

  double _applyEasing(double t, InterpolationMode mode) {
    switch (mode) {
      case InterpolationMode.linear:
        return t;
      
      case InterpolationMode.easeIn:
        return t * t;
      
      case InterpolationMode.easeOut:
        return t * (2 - t);
      
      case InterpolationMode.easeInOut:
        return t < 0.5
            ? 2 * t * t
            : -1 + (4 - 2 * t) * t;
      
      case InterpolationMode.cubic:
        return t * t * (3 - 2 * t);
      
      case InterpolationMode.bounce:
        if (t < 0.5) {
          return 0.5 * (1 - _bounceOut(1 - 2 * t));
        } else {
          return 0.5 * _bounceOut(2 * t - 1) + 0.5;
        }
      
      case InterpolationMode.elastic:
        if (t == 0 || t == 1) return t;
        final p = 0.3;
        final s = p / 4;
        return math.pow(2, -10 * t) * 
               math.sin((t - s) * (2 * math.pi) / p) + 1;
    }
  }

  double _bounceOut(double t) {
    if (t < 1 / 2.75) {
      return 7.5625 * t * t;
    } else if (t < 2 / 2.75) {
      t -= 1.5 / 2.75;
      return 7.5625 * t * t + 0.75;
    } else if (t < 2.5 / 2.75) {
      t -= 2.25 / 2.75;
      return 7.5625 * t * t + 0.9375;
    } else {
      t -= 2.625 / 2.75;
      return 7.5625 * t * t + 0.984375;
    }
  }
}

/// Records transformation operations for debugging and analysis.
class TransformationRecorder {
  final List<_TransformRecord> _records = [];
  final int maxRecords;
  final bool enabled;
  bool _isRecording = false;
  DateTime? _sessionStart;

  TransformationRecorder({
    this.maxRecords = 10000,
    this.enabled = true,
  });

  /// Starts a recording session.
  void startRecording() {
    if (!enabled) return;
    _isRecording = true;
    _sessionStart = DateTime.now();
    _records.clear();
  }

  /// Stops the recording session.
  void stopRecording() {
    _isRecording = false;
  }

  /// Records a transformation operation.
  void recordTransform({
    required String type,
    required dynamic from,
    required dynamic to,
    required Duration executionTime,
    required bool wasFromCache,
    Map<String, dynamic>? metadata,
  }) {
    if (!enabled || !_isRecording) return;
    
    if (_records.length >= maxRecords) {
      _records.removeAt(0); // Remove oldest
    }
    
    _records.add(_TransformRecord(
      timestamp: DateTime.now(),
      type: type,
      from: from.toString(),
      to: to.toString(),
      executionTime: executionTime,
      wasFromCache: wasFromCache,
      metadata: metadata,
    ));
  }

  /// Gets a summary of recorded transformations.
  Map<String, dynamic> getSummary() {
    if (_records.isEmpty) {
      return {'message': 'No records available'};
    }
    
    final typeGroups = <String, List<_TransformRecord>>{};
    for (final record in _records) {
      typeGroups.putIfAbsent(record.type, () => []).add(record);
    }
    
    final summary = <String, dynamic>{
      'sessionDuration': _sessionStart != null
          ? DateTime.now().difference(_sessionStart!).inMilliseconds
          : 0,
      'totalRecords': _records.length,
      'types': <String, dynamic>{},
    };
    
    for (final entry in typeGroups.entries) {
      final records = entry.value;
      final executionTimes = records.map((r) => r.executionTime.inMicroseconds).toList();
      executionTimes.sort();
      
      summary['types'][entry.key] = {
        'count': records.length,
        'cacheHits': records.where((r) => r.wasFromCache).length,
        'avgExecutionTimeUs': executionTimes.isEmpty
            ? 0
            : executionTimes.reduce((a, b) => a + b) / executionTimes.length,
        'minExecutionTimeUs': executionTimes.isEmpty ? 0 : executionTimes.first,
        'maxExecutionTimeUs': executionTimes.isEmpty ? 0 : executionTimes.last,
        'p50ExecutionTimeUs': _percentile(executionTimes, 50),
        'p95ExecutionTimeUs': _percentile(executionTimes, 95),
        'p99ExecutionTimeUs': _percentile(executionTimes, 99),
      };
    }
    
    return summary;
  }

  /// Exports records in a format suitable for analysis.
  List<Map<String, dynamic>> exportRecords() {
    return _records.map((record) => {
      'timestamp': record.timestamp.toIso8601String(),
      'type': record.type,
      'from': record.from,
      'to': record.to,
      'executionTimeUs': record.executionTime.inMicroseconds,
      'wasFromCache': record.wasFromCache,
      'metadata': record.metadata,
    }).toList();
  }

  /// Clears all recorded data.
  void clear() {
    _records.clear();
    _sessionStart = null;
  }

  double _percentile(List<int> sortedValues, int percentile) {
    if (sortedValues.isEmpty) return 0;
    final index = (percentile / 100 * sortedValues.length).ceil() - 1;
    return sortedValues[math.max(0, math.min(index, sortedValues.length - 1))].toDouble();
  }
}

/// Internal record of a transformation operation.
class _TransformRecord {
  final DateTime timestamp;
  final String type;
  final String from;
  final String to;
  final Duration executionTime;
  final bool wasFromCache;
  final Map<String, dynamic>? metadata;

  _TransformRecord({
    required this.timestamp,
    required this.type,
    required this.from,
    required this.to,
    required this.executionTime,
    required this.wasFromCache,
    this.metadata,
  });
}

/// Main transformation manager that coordinates all transformation operations.
class TransformationManager {
  final CoordinateSystem _coordSystem;
  final TransformCache _cache;
  final BatchTransformation _batchTransform;
  final TransformationRecorder _recorder;
  final _performanceMonitor = _PerformanceMonitor();
  
  // Thread safety via isolate-safe operations
  final _transformLock = <String, Completer>{};

  TransformationManager({
    required CoordinateSystem coordSystem,
    TransformCacheConfig? cacheConfig,
    bool enableRecording = true,
  })  : _coordSystem = coordSystem,
        _cache = TransformCache(cacheConfig ?? const TransformCacheConfig()),
        _batchTransform = BatchTransformation(
          cache: TransformCache(cacheConfig ?? const TransformCacheConfig()),
          coordSystem: coordSystem,
        ),
        _recorder = TransformationRecorder(enabled: enableRecording);

  /// Transforms a single point with caching and recording.
  Future<TransformResult<TTo>> transform<TFrom, TTo>({
    required TFrom from,
    required String transformType,
    required TTo Function(TFrom) transformer,
  }) async {
    final cacheKey = _cache.generateKey(transformType, from);
    
    // Ensure thread-safe access
    final lock = _transformLock[cacheKey];
    if (lock != null) {
      await lock.future;
    }
    
    final completer = Completer<void>();
    _transformLock[cacheKey] = completer;
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Check cache
      final cached = _cache.get<TTo>(cacheKey);
      if (cached != null) {
        stopwatch.stop();
        
        _recorder.recordTransform(
          type: transformType,
          from: from,
          to: cached,
          executionTime: stopwatch.elapsed,
          wasFromCache: true,
        );
        
        return TransformResult(
          result: cached,
          executionTime: stopwatch.elapsed,
          wasFromCache: true,
          cacheKey: cacheKey,
        );
      }
      
      // Perform transformation
      final result = transformer(from);
      _cache.put(cacheKey, result);
      
      stopwatch.stop();
      
      _recorder.recordTransform(
        type: transformType,
        from: from,
        to: result,
        executionTime: stopwatch.elapsed,
        wasFromCache: false,
      );
      
      _performanceMonitor.recordOperation(stopwatch.elapsed);
      
      return TransformResult(
        result: result,
        executionTime: stopwatch.elapsed,
        wasFromCache: false,
        cacheKey: cacheKey,
      );
    } finally {
      _transformLock.remove(cacheKey);
      completer.complete();
    }
  }

  /// Performs batch transformation of multiple points.
  Future<BatchTransformResult<TTo>> batchTransform<TFrom, TTo>({
    required List<TFrom> points,
    required String transformType,
    required TTo Function(TFrom) transformer,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = <TTo?>[];
    int cacheHits = 0;
    int cacheMisses = 0;
    
    // Process in parallel chunks for better performance
    const chunkSize = 100;
    final futures = <Future<List<TransformResult<TTo>>>>[];
    
    for (int i = 0; i < points.length; i += chunkSize) {
      final end = math.min(i + chunkSize, points.length);
      final chunk = points.sublist(i, end);
      
      futures.add(Future.wait(
        chunk.map((point) => transform(
          from: point,
          transformType: transformType,
          transformer: transformer,
        )),
      ));
    }
    
    final chunkResults = await Future.wait(futures);
    
    for (final chunk in chunkResults) {
      for (final result in chunk) {
        results.add(result.result);
        if (result.wasFromCache) {
          cacheHits++;
        } else {
          cacheMisses++;
        }
      }
    }
    
    stopwatch.stop();
    
    _performanceMonitor.recordBatchOperation(
      points.length,
      stopwatch.elapsed,
    );
    
    return BatchTransformResult(
      results: results,
      totalExecutionTime: stopwatch.elapsed,
      cacheHits: cacheHits,
      cacheMisses: cacheMisses,
    );
  }

  /// Creates an interpolated transformation stream.
  InterpolatedTransform createInterpolation({
    required Duration duration,
    InterpolationMode mode = InterpolationMode.easeInOut,
    int fps = 60,
  }) {
    return InterpolatedTransform(
      duration: duration,
      mode: mode,
      fps: fps,
    );
  }

  /// Updates the coordinate system and invalidates affected cache entries.
  void updateCoordinateSystem(CoordinateSystemConfig config) {
    _coordSystem.updateConfig(config);
    // Invalidate all transformation cache entries
    _cache.invalidatePattern('.*');
  }

  /// Gets comprehensive performance metrics.
  Map<String, dynamic> getMetrics() {
    final cacheMetrics = _cache.getMetrics();
    final recorderSummary = _recorder.getSummary();
    final performanceMetrics = _performanceMonitor.getMetrics();
    
    return {
      'cache': cacheMetrics,
      'recorder': recorderSummary,
      'performance': performanceMetrics,
      'coordinateSystem': _coordSystem.getPerformanceStats(),
    };
  }

  /// Starts recording transformation operations.
  void startRecording() {
    _recorder.startRecording();
  }

  /// Stops recording transformation operations.
  void stopRecording() {
    _recorder.stopRecording();
  }

  /// Exports recorded transformation data.
  List<Map<String, dynamic>> exportRecords() {
    return _recorder.exportRecords();
  }

  /// Clears all caches and recorded data.
  void reset() {
    _cache.clear();
    _recorder.clear();
    _performanceMonitor.reset();
  }

  /// Disposes of resources.
  void dispose() {
    _cache.dispose();
  }
}

/// Internal performance monitoring.
class _PerformanceMonitor {
  final List<Duration> _operationTimes = [];
  final List<_BatchOperation> _batchOperations = [];
  static const int _maxSamples = 1000;

  void recordOperation(Duration duration) {
    _operationTimes.add(duration);
    if (_operationTimes.length > _maxSamples) {
      _operationTimes.removeAt(0);
    }
  }

  void recordBatchOperation(int size, Duration duration) {
    _batchOperations.add(_BatchOperation(size, duration));
    if (_batchOperations.length > _maxSamples) {
      _batchOperations.removeAt(0);
    }
  }

  Map<String, dynamic> getMetrics() {
    if (_operationTimes.isEmpty && _batchOperations.isEmpty) {
      return {'message': 'No performance data available'};
    }
    
    final metrics = <String, dynamic>{};
    
    if (_operationTimes.isNotEmpty) {
      final times = _operationTimes.map((d) => d.inMicroseconds).toList()..sort();
      metrics['singleOperations'] = {
        'count': times.length,
        'avgUs': times.reduce((a, b) => a + b) / times.length,
        'minUs': times.first,
        'maxUs': times.last,
        'p50Us': _percentile(times, 50),
        'p95Us': _percentile(times, 95),
        'p99Us': _percentile(times, 99),
      };
    }
    
    if (_batchOperations.isNotEmpty) {
      final totalSize = _batchOperations.map((b) => b.size).reduce((a, b) => a + b);
      final totalTime = _batchOperations.map((b) => b.duration.inMicroseconds).reduce((a, b) => a + b);
      
      metrics['batchOperations'] = {
        'count': _batchOperations.length,
        'totalPoints': totalSize,
        'avgPointsPerBatch': totalSize / _batchOperations.length,
        'avgTimePerPointUs': totalTime / totalSize,
        'throughput': totalSize / (totalTime / 1000000.0), // points per second
      };
    }
    
    return metrics;
  }

  void reset() {
    _operationTimes.clear();
    _batchOperations.clear();
  }

  double _percentile(List<int> sortedValues, int percentile) {
    if (sortedValues.isEmpty) return 0;
    final index = (percentile / 100 * sortedValues.length).ceil() - 1;
    return sortedValues[math.max(0, math.min(index, sortedValues.length - 1))].toDouble();
  }
}

class _BatchOperation {
  final int size;
  final Duration duration;

  _BatchOperation(this.size, this.duration);
}
