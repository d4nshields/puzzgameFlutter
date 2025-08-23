part of '../hybrid_renderer.dart';

/// Schedules and coordinates rendering updates across layers
class RenderScheduler {
  final FrameBudgetManager frameBudgetManager;
  final Function(RenderLayer) onScheduledRender;
  
  final Map<RenderLayer, RenderLayerState> _layerStates = {};
  final Queue<RenderRequest> _renderQueue = Queue();
  Timer? _renderTimer;
  
  // Scheduling parameters
  static const Duration minRenderInterval = Duration(milliseconds: 16); // 60 FPS
  static const Duration maxRenderDelay = Duration(milliseconds: 100);
  
  RenderScheduler({
    required this.frameBudgetManager,
    required this.onScheduledRender,
  }) {
    _initializeLayerStates();
    _startScheduler();
  }

  void _initializeLayerStates() {
    for (final layer in RenderLayer.values) {
      _layerStates[layer] = RenderLayerState(
        layer: layer,
        priority: _getLayerPriority(layer),
      );
    }
  }

  int _getLayerPriority(RenderLayer layer) {
    switch (layer) {
      case RenderLayer.dynamic:
        return 3; // Highest priority for interactive elements
      case RenderLayer.effects:
        return 2; // Medium priority for visual feedback
      case RenderLayer.static:
        return 1; // Lowest priority for background
    }
  }

  void _startScheduler() {
    _renderTimer = Timer.periodic(
      minRenderInterval,
      (_) => _processRenderQueue(),
    );
  }

  /// Schedule a render update for a layer
  void scheduleUpdate(
    RenderLayer layer, {
    RenderPriority priority = RenderPriority.normal,
    Duration? delay,
  }) {
    final request = RenderRequest(
      layer: layer,
      priority: priority,
      requestTime: DateTime.now(),
      delay: delay,
    );
    
    // Handle immediate priority
    if (priority == RenderPriority.immediate) {
      _executeRender(request);
      return;
    }
    
    // Add to queue
    _renderQueue.add(request);
    
    // Sort queue by priority
    _sortRenderQueue();
  }

  /// Schedule multiple layer updates
  void scheduleBatch(List<RenderLayer> layers, {
    RenderPriority priority = RenderPriority.normal,
  }) {
    for (final layer in layers) {
      scheduleUpdate(layer, priority: priority);
    }
  }

  /// Cancel scheduled updates for a layer
  void cancelUpdate(RenderLayer layer) {
    _renderQueue.removeWhere((request) => request.layer == layer);
  }

  /// Process the render queue
  void _processRenderQueue() {
    if (_renderQueue.isEmpty) return;
    
    frameBudgetManager.startFrame();
    
    final processedLayers = <RenderLayer>{};
    final toRemove = <RenderRequest>[];
    
    for (final request in _renderQueue) {
      // Skip if layer already processed this frame
      if (processedLayers.contains(request.layer)) {
        continue;
      }
      
      // Check if delay has passed
      if (request.delay != null) {
        final elapsed = DateTime.now().difference(request.requestTime);
        if (elapsed < request.delay!) {
          continue;
        }
      }
      
      // Check if request is too old
      if (_isRequestStale(request)) {
        toRemove.add(request);
        continue;
      }
      
      // Check frame budget
      final estimatedTime = _estimateRenderTime(request.layer);
      if (!frameBudgetManager.hasBudget(estimatedTime)) {
        break; // No more budget this frame
      }
      
      // Execute render
      _executeRender(request);
      processedLayers.add(request.layer);
      toRemove.add(request);
      
      // Update layer state
      _updateLayerState(request.layer);
    }
    
    // Remove processed requests
    for (final request in toRemove) {
      _renderQueue.remove(request);
    }
    
    frameBudgetManager.endFrame();
  }

  /// Sort render queue by priority and age
  void _sortRenderQueue() {
    final sorted = _renderQueue.toList()
      ..sort((a, b) {
        // First compare by priority
        final priorityCompare = b.priority.index.compareTo(a.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        
        // Then by layer priority
        final layerPriorityA = _layerStates[a.layer]!.priority;
        final layerPriorityB = _layerStates[b.layer]!.priority;
        final layerCompare = layerPriorityB.compareTo(layerPriorityA);
        if (layerCompare != 0) return layerCompare;
        
        // Finally by request time (older first)
        return a.requestTime.compareTo(b.requestTime);
      });
    
    _renderQueue.clear();
    _renderQueue.addAll(sorted);
  }

  /// Check if a request is stale
  bool _isRequestStale(RenderRequest request) {
    final age = DateTime.now().difference(request.requestTime);
    return age > maxRenderDelay && request.priority != RenderPriority.high;
  }

  /// Estimate render time for a layer
  Duration _estimateRenderTime(RenderLayer layer) {
    final state = _layerStates[layer]!;
    return state.averageRenderTime ?? const Duration(milliseconds: 5);
  }

  /// Execute a render request
  void _executeRender(RenderRequest request) {
    final stopwatch = Stopwatch()..start();
    
    // Call the render callback
    onScheduledRender(request.layer);
    
    stopwatch.stop();
    
    // Update render time statistics
    final state = _layerStates[request.layer]!;
    state.updateRenderTime(stopwatch.elapsed);
  }

  /// Update layer state after rendering
  void _updateLayerState(RenderLayer layer) {
    final state = _layerStates[layer]!;
    state.lastRenderTime = DateTime.now();
    state.renderCount++;
  }

  /// Get scheduling statistics
  SchedulerStats getStats() {
    final layerStats = <RenderLayer, LayerStats>{};
    
    for (final entry in _layerStates.entries) {
      layerStats[entry.key] = LayerStats(
        renderCount: entry.value.renderCount,
        averageRenderTime: entry.value.averageRenderTime ?? Duration.zero,
        lastRenderTime: entry.value.lastRenderTime,
      );
    }
    
    return SchedulerStats(
      queueSize: _renderQueue.length,
      layerStats: layerStats,
    );
  }

  /// Force render all layers
  void forceRenderAll() {
    for (final layer in RenderLayer.values) {
      _executeRender(RenderRequest(
        layer: layer,
        priority: RenderPriority.immediate,
        requestTime: DateTime.now(),
      ));
    }
  }

  /// Pause scheduling
  void pause() {
    _renderTimer?.cancel();
    _renderTimer = null;
  }

  /// Resume scheduling
  void resume() {
    if (_renderTimer == null) {
      _startScheduler();
    }
  }

  /// Dispose of resources
  void dispose() {
    _renderTimer?.cancel();
    _renderQueue.clear();
  }
}

/// Render request
class RenderRequest {
  final RenderLayer layer;
  final RenderPriority priority;
  final DateTime requestTime;
  final Duration? delay;

  const RenderRequest({
    required this.layer,
    required this.priority,
    required this.requestTime,
    this.delay,
  });
}

/// Render priority levels
enum RenderPriority {
  low,
  normal,
  high,
  immediate,
}

/// State for each render layer
class RenderLayerState {
  final RenderLayer layer;
  final int priority;
  DateTime? lastRenderTime;
  int renderCount = 0;
  Duration? averageRenderTime;
  final List<Duration> _renderTimeHistory = [];
  static const int maxHistorySize = 10;

  RenderLayerState({
    required this.layer,
    required this.priority,
  });

  void updateRenderTime(Duration renderTime) {
    _renderTimeHistory.add(renderTime);
    
    // Maintain history size
    if (_renderTimeHistory.length > maxHistorySize) {
      _renderTimeHistory.removeAt(0);
    }
    
    // Calculate average
    if (_renderTimeHistory.isNotEmpty) {
      final totalMicroseconds = _renderTimeHistory
          .fold<int>(0, (sum, time) => sum + time.inMicroseconds);
      averageRenderTime = Duration(
        microseconds: totalMicroseconds ~/ _renderTimeHistory.length,
      );
    }
  }
}

/// Scheduler statistics
class SchedulerStats {
  final int queueSize;
  final Map<RenderLayer, LayerStats> layerStats;

  const SchedulerStats({
    required this.queueSize,
    required this.layerStats,
  });
}

/// Statistics for a single layer
class LayerStats {
  final int renderCount;
  final Duration averageRenderTime;
  final DateTime? lastRenderTime;

  const LayerStats({
    required this.renderCount,
    required this.averageRenderTime,
    this.lastRenderTime,
  });
}