part of '../hybrid_renderer.dart';

/// Manages frame budget to ensure smooth performance
class FrameBudgetManager {
  final Duration targetFrameTime;
  final Queue<FrameTask> _taskQueue = Queue();
  final Map<RenderLayer, Duration> _layerBudgets = {};
  final Stopwatch _frameStopwatch = Stopwatch();
  
  int _frameCount = 0;
  Duration _totalFrameTime = Duration.zero;

  FrameBudgetManager({
    this.targetFrameTime = const Duration(milliseconds: 16),
  }) {
    _initializeLayerBudgets();
  }

  void _initializeLayerBudgets() {
    // Allocate frame budget across layers
    const totalMicroseconds = 16000; // 16ms
    
    _layerBudgets[RenderLayer.static] = 
        const Duration(microseconds: totalMicroseconds ~/ 4); // 25%
    _layerBudgets[RenderLayer.dynamic] = 
        const Duration(microseconds: totalMicroseconds ~/ 2); // 50%
    _layerBudgets[RenderLayer.effects] = 
        const Duration(microseconds: totalMicroseconds ~/ 4); // 25%
  }

  /// Start a new frame
  void startFrame() {
    _frameStopwatch.reset();
    _frameStopwatch.start();
  }

  /// End the current frame
  void endFrame() {
    _frameStopwatch.stop();
    final frameTime = _frameStopwatch.elapsed;
    
    _frameCount++;
    _totalFrameTime += frameTime;
    
    // Log if frame exceeded budget
    if (frameTime > targetFrameTime) {
      final overrun = frameTime - targetFrameTime;
      debugPrint('Frame budget exceeded by ${overrun.inMilliseconds}ms');
    }
  }

  /// Check if there's budget remaining for a task
  bool hasBudget(Duration estimatedTime) {
    return _frameStopwatch.elapsed + estimatedTime <= targetFrameTime;
  }

  /// Get remaining budget for current frame
  Duration get remainingBudget {
    final elapsed = _frameStopwatch.elapsed;
    if (elapsed >= targetFrameTime) {
      return Duration.zero;
    }
    return targetFrameTime - elapsed;
  }

  /// Schedule a task for execution
  void scheduleTask(FrameTask task) {
    _taskQueue.add(task);
  }

  /// Execute tasks within budget
  Future<void> executeTasks() async {
    while (_taskQueue.isNotEmpty && hasBudget(_estimateTaskTime(_taskQueue.first))) {
      final task = _taskQueue.removeFirst();
      final startTime = _frameStopwatch.elapsed;
      
      await task.execute();
      
      final taskTime = _frameStopwatch.elapsed - startTime;
      _updateTaskEstimate(task, taskTime);
    }
  }

  /// Estimate time for a task
  Duration _estimateTaskTime(FrameTask task) {
    // Use historical data or default estimate
    return task.estimatedTime ?? const Duration(milliseconds: 2);
  }

  /// Update task time estimate based on actual execution
  void _updateTaskEstimate(FrameTask task, Duration actualTime) {
    // Update running average for task type
    task.updateEstimate(actualTime);
  }

  /// Get budget for a specific layer
  Duration getLayerBudget(RenderLayer layer) {
    return _layerBudgets[layer] ?? Duration.zero;
  }

  /// Check if a layer should be rendered this frame
  bool shouldRenderLayer(RenderLayer layer, Duration estimatedTime) {
    final budget = getLayerBudget(layer);
    return estimatedTime <= budget && hasBudget(estimatedTime);
  }

  /// Get frame statistics
  FrameStats getStats() {
    final averageFrameTime = _frameCount > 0
        ? _totalFrameTime ~/ _frameCount
        : Duration.zero;
    
    return FrameStats(
      frameCount: _frameCount,
      averageFrameTime: averageFrameTime,
      targetFrameTime: targetFrameTime,
      budgetUtilization: averageFrameTime.inMicroseconds / 
                        targetFrameTime.inMicroseconds,
    );
  }

  /// Reset statistics
  void resetStats() {
    _frameCount = 0;
    _totalFrameTime = Duration.zero;
  }
}

/// Represents a task to be executed within frame budget
abstract class FrameTask {
  Duration? estimatedTime;
  final Map<String, dynamic> metadata;

  FrameTask({
    this.estimatedTime,
    this.metadata = const {},
  });

  Future<void> execute();
  
  void updateEstimate(Duration actualTime) {
    // Update using exponential moving average
    if (estimatedTime == null) {
      estimatedTime = actualTime;
    } else {
      const alpha = 0.3; // Smoothing factor
      estimatedTime = Duration(
        microseconds: (estimatedTime!.inMicroseconds * (1 - alpha) + 
                      actualTime.inMicroseconds * alpha).round(),
      );
    }
  }
}

/// Render task for a specific layer
class RenderLayerTask extends FrameTask {
  final RenderLayer layer;
  final VoidCallback renderCallback;

  RenderLayerTask({
    required this.layer,
    required this.renderCallback,
    super.estimatedTime,
  });

  @override
  Future<void> execute() async {
    renderCallback();
  }
}

/// Frame statistics
class FrameStats {
  final int frameCount;
  final Duration averageFrameTime;
  final Duration targetFrameTime;
  final double budgetUtilization;

  const FrameStats({
    required this.frameCount,
    required this.averageFrameTime,
    required this.targetFrameTime,
    required this.budgetUtilization,
  });

  double get fps => 1000 / averageFrameTime.inMilliseconds;
  bool get isPerformant => budgetUtilization <= 1.0;
}