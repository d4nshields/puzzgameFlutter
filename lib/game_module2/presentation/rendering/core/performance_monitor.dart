part of '../hybrid_renderer.dart';

/// Monitors rendering performance and provides metrics
class PerformanceMonitor {
  final ValueChanged<PerformanceMetrics> onMetricsUpdate;
  final Queue<PerformanceMetrics> _metricsHistory = Queue();
  static const int maxHistorySize = 60; // 1 minute at 60 FPS
  
  Timer? _monitoringTimer;
  final Stopwatch _uptimeStopwatch = Stopwatch()..start();
  
  // Performance thresholds
  static const int targetFps = 60;
  static const Duration targetFrameTime = Duration(milliseconds: 16);
  static const double memoryWarningThreshold = 100.0; // MB

  PerformanceMonitor({
    required this.onMetricsUpdate,
  }) {
    _startMonitoring();
  }

  void _startMonitoring() {
    // Monitor performance every second
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _analyzePerformance(),
    );
  }

  /// Record performance metrics
  void recordMetrics(PerformanceMetrics metrics) {
    _metricsHistory.add(metrics);
    
    // Maintain history size
    while (_metricsHistory.length > maxHistorySize) {
      _metricsHistory.removeFirst();
    }
    
    // Check for performance issues
    _checkPerformanceIssues(metrics);
    
    // Notify listeners
    onMetricsUpdate(metrics);
  }

  /// Analyze overall performance
  void _analyzePerformance() {
    if (_metricsHistory.isEmpty) return;
    
    final analysis = PerformanceAnalysis(
      averageFps: _calculateAverageFps(),
      frameTimeVariance: _calculateFrameTimeVariance(),
      memoryTrend: _analyzeMemoryTrend(),
      performanceScore: _calculatePerformanceScore(),
      recommendations: _generateRecommendations(),
    );
    
    _logPerformanceAnalysis(analysis);
  }

  /// Calculate average FPS from history
  double _calculateAverageFps() {
    if (_metricsHistory.isEmpty) return 0;
    
    final totalFps = _metricsHistory.fold<int>(
      0,
      (sum, metrics) => sum + metrics.fps,
    );
    
    return totalFps / _metricsHistory.length;
  }

  /// Calculate frame time variance
  double _calculateFrameTimeVariance() {
    if (_metricsHistory.length < 2) return 0;
    
    final frameTimes = _metricsHistory
        .map((m) => m.averageFrameTime.inMicroseconds.toDouble())
        .toList();
    
    final mean = frameTimes.reduce((a, b) => a + b) / frameTimes.length;
    final variance = frameTimes
        .map((time) => math.pow(time - mean, 2))
        .reduce((a, b) => a + b) / frameTimes.length;
    
    return math.sqrt(variance);
  }

  /// Analyze memory usage trend
  MemoryTrend _analyzeMemoryTrend() {
    if (_metricsHistory.length < 5) return MemoryTrend.stable;
    
    final recentMemory = _metricsHistory
        .toList()
        .sublist(_metricsHistory.length - 5)
        .map((m) => m.memoryUsage)
        .toList();
    
    // Check if memory is consistently increasing
    bool increasing = true;
    for (int i = 1; i < recentMemory.length; i++) {
      if (recentMemory[i] <= recentMemory[i - 1]) {
        increasing = false;
        break;
      }
    }
    
    if (increasing) return MemoryTrend.increasing;
    
    // Check if memory is stable
    final variance = _calculateVariance(recentMemory);
    if (variance < 5.0) return MemoryTrend.stable;
    
    return MemoryTrend.fluctuating;
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    return values
        .map((v) => math.pow(v - mean, 2))
        .reduce((a, b) => a + b) / values.length;
  }

  /// Calculate overall performance score (0-100)
  double _calculatePerformanceScore() {
    if (_metricsHistory.isEmpty) return 100;
    
    final avgFps = _calculateAverageFps();
    final fpsScore = (avgFps / targetFps * 100).clamp(0, 100);
    
    final avgDroppedFrames = _metricsHistory.fold<int>(
      0,
      (sum, m) => sum + m.droppedFrames,
    ) / _metricsHistory.length;
    final droppedScore = math.max(0, 100 - avgDroppedFrames * 10);
    
    final latestMemory = _metricsHistory.last.memoryUsage;
    final memoryScore = latestMemory < memoryWarningThreshold ? 100 : 
                       math.max(0, 100 - (latestMemory - memoryWarningThreshold));
    
    // Weighted average
    return fpsScore * 0.5 + droppedScore * 0.3 + memoryScore * 0.2;
  }

  /// Generate performance recommendations
  List<String> _generateRecommendations() {
    final recommendations = <String>[];
    
    if (_metricsHistory.isEmpty) return recommendations;
    
    final avgFps = _calculateAverageFps();
    if (avgFps < 30) {
      recommendations.add('Consider reducing quality settings');
    } else if (avgFps < 50) {
      recommendations.add('Performance could be improved');
    }
    
    final memoryTrend = _analyzeMemoryTrend();
    if (memoryTrend == MemoryTrend.increasing) {
      recommendations.add('Memory usage is increasing - check for leaks');
    }
    
    final latestMetrics = _metricsHistory.last;
    if (latestMetrics.droppedFrames > 5) {
      recommendations.add('High number of dropped frames detected');
    }
    
    if (latestMetrics.quality == QualityLevel.ultra && avgFps < 55) {
      recommendations.add('Consider switching to High quality for better performance');
    }
    
    return recommendations;
  }

  /// Check for performance issues
  void _checkPerformanceIssues(PerformanceMetrics metrics) {
    // Check for low FPS
    if (metrics.fps < 30) {
      debugPrint('⚠️ Low FPS warning: ${metrics.fps}');
    }
    
    // Check for high memory usage
    if (metrics.memoryUsage > memoryWarningThreshold) {
      debugPrint('⚠️ High memory usage: ${metrics.memoryUsage.toStringAsFixed(2)}MB');
    }
    
    // Check for excessive dropped frames
    if (metrics.droppedFrames > 10) {
      debugPrint('⚠️ Excessive dropped frames: ${metrics.droppedFrames}');
    }
  }

  /// Log performance analysis
  void _logPerformanceAnalysis(PerformanceAnalysis analysis) {
    if (!kDebugMode) return;
    
    debugPrint('=== Performance Analysis ===');
    debugPrint('Average FPS: ${analysis.averageFps.toStringAsFixed(1)}');
    debugPrint('Frame Time Variance: ${analysis.frameTimeVariance.toStringAsFixed(2)}ms');
    debugPrint('Memory Trend: ${analysis.memoryTrend.name}');
    debugPrint('Performance Score: ${analysis.performanceScore.toStringAsFixed(1)}/100');
    
    if (analysis.recommendations.isNotEmpty) {
      debugPrint('Recommendations:');
      for (final recommendation in analysis.recommendations) {
        debugPrint('  • $recommendation');
      }
    }
    debugPrint('===========================');
  }

  /// Get current performance summary
  PerformanceSummary getSummary() {
    return PerformanceSummary(
      uptime: _uptimeStopwatch.elapsed,
      totalFrames: _metricsHistory.fold(0, (sum, m) => sum + m.fps),
      averageFps: _calculateAverageFps(),
      performanceScore: _calculatePerformanceScore(),
      currentQuality: _metricsHistory.isNotEmpty 
          ? _metricsHistory.last.quality 
          : QualityLevel.high,
    );
  }

  void dispose() {
    _monitoringTimer?.cancel();
    _uptimeStopwatch.stop();
  }
}

/// Performance analysis results
class PerformanceAnalysis {
  final double averageFps;
  final double frameTimeVariance;
  final MemoryTrend memoryTrend;
  final double performanceScore;
  final List<String> recommendations;

  const PerformanceAnalysis({
    required this.averageFps,
    required this.frameTimeVariance,
    required this.memoryTrend,
    required this.performanceScore,
    required this.recommendations,
  });
}

/// Memory usage trend
enum MemoryTrend {
  stable,
  increasing,
  fluctuating,
}

/// Performance summary
class PerformanceSummary {
  final Duration uptime;
  final int totalFrames;
  final double averageFps;
  final double performanceScore;
  final QualityLevel currentQuality;

  const PerformanceSummary({
    required this.uptime,
    required this.totalFrames,
    required this.averageFps,
    required this.performanceScore,
    required this.currentQuality,
  });
}