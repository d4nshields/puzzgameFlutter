/// Render Coordinator for Puzzle Nook
/// 
/// This implementation provides centralized management of all rendering layers
/// with advanced performance monitoring, quality adaptation, and frame scheduling.
/// 
/// Features:
/// - Layer synchronization across static, dynamic, and effects layers
/// - Frame scheduling with priority queue for optimal performance
/// - Automatic quality adaptation based on frame timing
/// - Comprehensive performance metrics collection
/// - Layer communication bus for inter-layer messaging
/// - Developer tools integration with visual overlays
/// - Profiling mode for performance analysis

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Main render coordinator that manages all rendering layers
class RenderCoordinator extends ChangeNotifier {
  // Layer references
  final Map<RenderLayerType, RenderLayer> _layers = {};
  
  // Core systems
  late final FrameScheduler _frameScheduler;
  late final QualityAdapter _qualityAdapter;
  late final RenderMetrics _renderMetrics;
  late final LayerCommunicationBus _communicationBus;
  late final DeveloperTools _developerTools;
  
  // Configuration
  final RenderCoordinatorConfig config;
  
  // State
  bool _isInitialized = false;
  bool _isRendering = false;
  ProfilingMode _profilingMode = ProfilingMode.off;
  
  // Getters for testing
  @visibleForTesting
  QualityAdapter get qualityAdapter => _qualityAdapter;
  
  @visibleForTesting
  ProfilingMode get profilingMode => _profilingMode;
  
  @visibleForTesting
  DeveloperTools get developerTools => _developerTools;
  
  // Performance tracking
  final Queue<FrameTiming> _frameTimings = Queue();
  int _frameCount = 0;
  int _droppedFrames = 0;
  Duration _totalRenderTime = Duration.zero;
  bool _frameCallbackScheduled = false;
  
  RenderCoordinator({
    this.config = const RenderCoordinatorConfig(),
  }) {
    _initialize();
  }
  
  void _initialize() {
    // Initialize frame scheduler
    _frameScheduler = FrameScheduler(
      targetFrameRate: config.targetFrameRate,
      onScheduledFrame: _handleScheduledFrame,
    );
    
    // Initialize quality adapter
    _qualityAdapter = QualityAdapter(
      initialQuality: config.initialQuality,
      autoAdapt: config.autoAdaptQuality,
      onQualityChanged: _handleQualityChanged,
    );
    
    // Initialize render metrics
    _renderMetrics = RenderMetrics();
    
    // Initialize communication bus
    _communicationBus = LayerCommunicationBus();
    
    // Initialize developer tools
    _developerTools = DeveloperTools(
      coordinator: this,
      enabled: config.enableDeveloperTools,
    );
    
    // Start frame callback
    _scheduleFrameCallback();
    
    _isInitialized = true;
  }
  
  /// Register a render layer with the coordinator
  void registerLayer(RenderLayerType type, RenderLayer layer) {
    if (_layers.containsKey(type)) {
      throw StateError('Layer $type is already registered');
    }
    
    _layers[type] = layer;
    layer._attachToCoordinator(this);
    
    // Subscribe layer to communication bus
    _communicationBus.registerLayer(type, layer);
    
    debugPrint('RenderCoordinator: Registered layer $type');
  }
  
  /// Unregister a render layer
  void unregisterLayer(RenderLayerType type) {
    final layer = _layers.remove(type);
    if (layer != null) {
      layer._detachFromCoordinator();
      _communicationBus.unregisterLayer(type);
    }
  }
  
  /// Schedule a frame update for specific layers
  void scheduleFrame({
    required Set<RenderLayerType> layers,
    RenderPriority priority = RenderPriority.normal,
    Map<String, dynamic>? metadata,
  }) {
    if (!_isInitialized) return;
    
    _frameScheduler.scheduleFrame(
      FrameRequest(
        layers: layers,
        priority: priority,
        metadata: metadata ?? {},
        timestamp: DateTime.now(),
      ),
    );
  }
  
  void _scheduleFrameCallback() {
    if (!_frameCallbackScheduled && _isInitialized) {
      _frameCallbackScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback(_onFrameComplete);
    }
  }
  
  /// Force immediate frame render
  void forceFrame() {
    if (_isRendering) return;
    
    _isRendering = true;
    final stopwatch = Stopwatch()..start();
    
    try {
      // Render all layers
      for (final entry in _layers.entries) {
        if (entry.value.needsUpdate) {
          _renderLayer(entry.key, entry.value);
        }
      }
      
      // Record timing
      stopwatch.stop();
      _recordFrameTiming(stopwatch.elapsed);
      
    } finally {
      _isRendering = false;
    }
  }
  
  void _handleScheduledFrame(FrameRequest request) {
    if (_isRendering) return;
    
    _isRendering = true;
    final stopwatch = Stopwatch()..start();
    
    try {
      // Process frame request
      for (final layerType in request.layers) {
        final layer = _layers[layerType];
        if (layer != null) {
          _renderLayer(layerType, layer);
        }
      }
      
      // Record timing
      stopwatch.stop();
      _recordFrameTiming(stopwatch.elapsed);
      
      // Update metrics
      _renderMetrics.recordFrame(
        duration: stopwatch.elapsed,
        layersRendered: request.layers,
        priority: request.priority,
      );
      
    } finally {
      _isRendering = false;
    }
  }
  
  void _renderLayer(RenderLayerType type, RenderLayer layer) {
    final stopwatch = Stopwatch()..start();
    
    try {
      layer.render();
      
      stopwatch.stop();
      _renderMetrics.recordLayerRender(
        layer: type,
        duration: stopwatch.elapsed,
      );
      
      if (_profilingMode != ProfilingMode.off) {
        _developerTools.recordLayerProfile(
          layer: type,
          duration: stopwatch.elapsed,
        );
      }
      
    } catch (e, stack) {
      debugPrint('RenderCoordinator: Error rendering layer $type: $e');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stack);
      }
    }
  }
  
  void _onFrameComplete(Duration timestamp) {
    _frameCallbackScheduled = false;
    
    if (!_isInitialized) return;  // Skip if disposed
    
    _frameCount++;
    
    // Check for dropped frames
    if (_frameTimings.isNotEmpty) {
      final lastTiming = _frameTimings.last;
      final frameDuration = timestamp - lastTiming.timestamp;
      
      if (frameDuration > config.targetFrameDuration) {
        _droppedFrames++;
        _handleDroppedFrame(frameDuration);
      }
    }
    
    // Record timing
    _frameTimings.add(FrameTiming(
      timestamp: timestamp,
      duration: timestamp,
      frameNumber: _frameCount,
    ));
    
    // Limit queue size
    while (_frameTimings.length > 100) {
      _frameTimings.removeFirst();
    }
    
    // Update quality adapter
    _qualityAdapter.updateMetrics(
      fps: _calculateFps(),
      droppedFrames: _droppedFrames,
      averageFrameTime: _calculateAverageFrameTime(),
    );
    
    // Schedule next frame callback if still initialized
    if (_isInitialized) {
      _scheduleFrameCallback();
    }
  }
  
  void _handleDroppedFrame(Duration frameDuration) {
    debugPrint('RenderCoordinator: Dropped frame (${frameDuration.inMilliseconds}ms)');
    
    // Notify quality adapter
    _qualityAdapter.handleDroppedFrame();
    
    // Send event through communication bus
    _communicationBus.broadcast(
      LayerMessage(
        type: MessageType.performanceWarning,
        sender: RenderLayerType.coordinator,
        data: {
          'event': 'dropped_frame',
          'duration': frameDuration.inMilliseconds,
        },
      ),
    );
  }
  
  void _handleQualityChanged(QualityLevel newQuality) {
    debugPrint('RenderCoordinator: Quality changed to $newQuality');
    
    // Notify all layers of quality change
    _communicationBus.broadcast(
      LayerMessage(
        type: MessageType.qualityChanged,
        sender: RenderLayerType.coordinator,
        data: {'quality': newQuality},
      ),
    );
    
    // Update configuration in layers
    for (final layer in _layers.values) {
      layer.updateQuality(newQuality);
    }
    
    notifyListeners();
  }
  
  // For testing purposes
  @visibleForTesting
  void handleQualityChanged(QualityLevel newQuality) => _handleQualityChanged(newQuality);
  
  void _recordFrameTiming(Duration duration) {
    _totalRenderTime += duration;
    
    if (_profilingMode == ProfilingMode.detailed) {
      _developerTools.recordFrameProfile(
        frameNumber: _frameCount,
        duration: duration,
        layers: _layers.keys.toSet(),
      );
    }
  }
  
  double _calculateFps() {
    if (_frameTimings.length < 2) return 60.0;
    
    final firstTiming = _frameTimings.first;
    final lastTiming = _frameTimings.last;
    final duration = lastTiming.timestamp - firstTiming.timestamp;
    
    if (duration.inMilliseconds == 0) return 60.0;
    
    return (_frameTimings.length - 1) * 1000.0 / duration.inMilliseconds;
  }
  
  Duration _calculateAverageFrameTime() {
    if (_frameCount == 0) return Duration.zero;
    return _totalRenderTime ~/ _frameCount;
  }
  
  /// Set profiling mode
  void setProfilingMode(ProfilingMode mode) {
    _profilingMode = mode;
    _developerTools.setProfilingMode(mode);
    notifyListeners();
  }
  
  /// Get current performance metrics
  PerformanceSnapshot getPerformanceSnapshot() {
    return PerformanceSnapshot(
      fps: _calculateFps(),
      droppedFrames: _droppedFrames,
      averageFrameTime: _calculateAverageFrameTime(),
      totalFrames: _frameCount,
      currentQuality: _qualityAdapter.currentQuality,
      layerCount: _layers.length,
      memoryUsage: _getMemoryUsage(),
    );
  }
  
  double _getMemoryUsage() {
    // This would integrate with actual memory profiling
    // For now, return a placeholder
    return 0.0;
  }
  
  /// Send message through communication bus
  void sendMessage(LayerMessage message) {
    _communicationBus.send(message);
  }
  
  /// Get developer tools widget
  Widget? getDeveloperOverlay() {
    if (!config.enableDeveloperTools) return null;
    return _developerTools.buildOverlay();
  }
  
  @override
  void dispose() {
    _isInitialized = false;  // Stop frame callbacks
    _frameCallbackScheduled = false;
    
    // Then dispose of components
    _frameScheduler.dispose();
    _qualityAdapter.dispose();
    _renderMetrics.dispose();
    _communicationBus.dispose();
    _developerTools.dispose();
    
    for (final layer in _layers.values) {
      layer._detachFromCoordinator();
    }
    _layers.clear();
    
    super.dispose();
  }
}

/// Frame scheduler with priority queue
class FrameScheduler {
  final int targetFrameRate;
  final void Function(FrameRequest) onScheduledFrame;
  
  final PriorityQueue<FrameRequest> _frameQueue = PriorityQueue();
  Timer? _frameTimer;
  bool _isProcessing = false;
  
  FrameScheduler({
    required this.targetFrameRate,
    required this.onScheduledFrame,
  }) {
    _startFrameTimer();
  }
  
  void _startFrameTimer() {
    final frameDuration = Duration(microseconds: 1000000 ~/ targetFrameRate);
    _frameTimer = Timer.periodic(frameDuration, (_) => _processFrameQueue());
  }
  
  void scheduleFrame(FrameRequest request) {
    _frameQueue.add(request);
  }
  
  void _processFrameQueue() {
    if (_isProcessing || _frameQueue.isEmpty) return;
    
    _isProcessing = true;
    
    try {
      // Process highest priority frame
      final request = _frameQueue.removeFirst();
      
      // Merge similar requests if needed
      final mergedLayers = {request.layers};
      
      while (_frameQueue.isNotEmpty && 
             _frameQueue.first.priority == request.priority) {
        final next = _frameQueue.removeFirst();
        mergedLayers.add(next.layers);
      }
      
      // Execute frame render
      onScheduledFrame(FrameRequest(
        layers: mergedLayers.expand((s) => s).toSet(),
        priority: request.priority,
        metadata: request.metadata,
        timestamp: DateTime.now(),
      ));
      
    } finally {
      _isProcessing = false;
    }
  }
  
  void dispose() {
    _frameTimer?.cancel();
    _frameQueue.clear();
  }
}

/// Quality adapter for automatic performance optimization
class QualityAdapter {
  QualityLevel currentQuality;
  final bool autoAdapt;
  final void Function(QualityLevel) onQualityChanged;
  
  // Performance thresholds
  static const double _minAcceptableFps = 55.0;
  static const double _upgradeThresholdFps = 58.0;
  static const int _maxDroppedFrames = 5;
  
  // Tracking
  int _consecutiveGoodFrames = 0;
  int _consecutiveBadFrames = 0;
  int _droppedFrameCount = 0;
  DateTime _lastQualityChange = DateTime.now();
  
  QualityAdapter({
    required QualityLevel initialQuality,
    required this.autoAdapt,
    required this.onQualityChanged,
  }) : currentQuality = initialQuality;
  
  void updateMetrics({
    required double fps,
    required int droppedFrames,
    required Duration averageFrameTime,
  }) {
    if (!autoAdapt) return;
    
    _droppedFrameCount = droppedFrames;
    
    // Check if we should adjust quality
    if (fps < _minAcceptableFps) {
      _consecutiveBadFrames++;
      _consecutiveGoodFrames = 0;
      
      if (_consecutiveBadFrames > 10) {
        _tryDecreaseQuality();
      }
    } else if (fps > _upgradeThresholdFps) {
      _consecutiveGoodFrames++;
      _consecutiveBadFrames = 0;
      
      if (_consecutiveGoodFrames > 60) {
        _tryIncreaseQuality();
      }
    } else {
      // Reset counters if performance is acceptable
      if (_consecutiveGoodFrames > 0) _consecutiveGoodFrames--;
      if (_consecutiveBadFrames > 0) _consecutiveBadFrames--;
    }
  }
  
  void handleDroppedFrame() {
    if (!autoAdapt) return;
    
    _consecutiveBadFrames += 2; // Weight dropped frames more heavily
    
    if (_droppedFrameCount > _maxDroppedFrames) {
      _tryDecreaseQuality();
    }
  }
  
  void _tryDecreaseQuality() {
    // Don't change quality too frequently
    if (DateTime.now().difference(_lastQualityChange).inSeconds < 2) return;
    
    final newQuality = _getNextLowerQuality(currentQuality);
    if (newQuality != currentQuality) {
      currentQuality = newQuality;
      _lastQualityChange = DateTime.now();
      _consecutiveBadFrames = 0;
      _droppedFrameCount = 0;
      onQualityChanged(currentQuality);
    }
  }
  
  void _tryIncreaseQuality() {
    // Don't change quality too frequently
    if (DateTime.now().difference(_lastQualityChange).inSeconds < 5) return;
    
    final newQuality = _getNextHigherQuality(currentQuality);
    if (newQuality != currentQuality) {
      currentQuality = newQuality;
      _lastQualityChange = DateTime.now();
      _consecutiveGoodFrames = 0;
      onQualityChanged(currentQuality);
    }
  }
  
  QualityLevel _getNextLowerQuality(QualityLevel current) {
    switch (current) {
      case QualityLevel.ultra:
        return QualityLevel.high;
      case QualityLevel.high:
        return QualityLevel.medium;
      case QualityLevel.medium:
        return QualityLevel.low;
      case QualityLevel.low:
        return QualityLevel.low; // Can't go lower
    }
  }
  
  QualityLevel _getNextHigherQuality(QualityLevel current) {
    switch (current) {
      case QualityLevel.low:
        return QualityLevel.medium;
      case QualityLevel.medium:
        return QualityLevel.high;
      case QualityLevel.high:
        return QualityLevel.ultra;
      case QualityLevel.ultra:
        return QualityLevel.ultra; // Can't go higher
    }
  }
  
  void dispose() {
    // Cleanup if needed
  }
}

/// Render metrics collection
class RenderMetrics {
  final Map<RenderLayerType, LayerMetrics> _layerMetrics = {};
  final Queue<FrameMetrics> _frameHistory = Queue();
  
  void recordFrame({
    required Duration duration,
    required Set<RenderLayerType> layersRendered,
    required RenderPriority priority,
  }) {
    final metrics = FrameMetrics(
      timestamp: DateTime.now(),
      duration: duration,
      layersRendered: layersRendered,
      priority: priority,
    );
    
    _frameHistory.add(metrics);
    
    // Keep only recent history
    while (_frameHistory.length > 1000) {
      _frameHistory.removeFirst();
    }
  }
  
  void recordLayerRender({
    required RenderLayerType layer,
    required Duration duration,
  }) {
    final metrics = _layerMetrics.putIfAbsent(
      layer,
      () => LayerMetrics(layer: layer),
    );
    
    metrics.recordRender(duration);
  }
  
  Map<String, dynamic> getMetricsSummary() {
    final summary = <String, dynamic>{};
    
    // Frame metrics
    if (_frameHistory.isNotEmpty) {
      final totalDuration = _frameHistory
          .map((m) => m.duration)
          .reduce((a, b) => a + b);
      
      summary['averageFrameTime'] = 
          (totalDuration.inMicroseconds / _frameHistory.length).round();
      summary['totalFrames'] = _frameHistory.length;
    }
    
    // Layer metrics
    final layerSummaries = <String, dynamic>{};
    for (final entry in _layerMetrics.entries) {
      layerSummaries[entry.key.toString()] = entry.value.getSummary();
    }
    summary['layers'] = layerSummaries;
    
    return summary;
  }
  
  void dispose() {
    _layerMetrics.clear();
    _frameHistory.clear();
  }
}

/// Layer communication bus for inter-layer messaging
class LayerCommunicationBus {
  final Map<RenderLayerType, RenderLayer> _subscribers = {};
  final StreamController<LayerMessage> _messageController = 
      StreamController.broadcast();
  
  void registerLayer(RenderLayerType type, RenderLayer layer) {
    _subscribers[type] = layer;
    
    // Subscribe layer to message stream
    layer._messageSubscription = _messageController.stream
        .where((msg) => msg.recipient == null || msg.recipient == type)
        .listen((msg) => layer.handleMessage(msg));
  }
  
  void unregisterLayer(RenderLayerType type) {
    _subscribers.remove(type);
  }
  
  void send(LayerMessage message) {
    if (message.recipient != null) {
      // Direct message
      final recipient = _subscribers[message.recipient!];
      recipient?.handleMessage(message);
    } else {
      // Broadcast
      broadcast(message);
    }
  }
  
  void broadcast(LayerMessage message) {
    if (!_messageController.isClosed) {
      _messageController.add(message);
    }
  }
  
  void dispose() {
    _messageController.close();
  }
}

/// Developer tools for debugging and profiling
class DeveloperTools {
  final RenderCoordinator coordinator;
  final bool enabled;
  
  ProfilingMode _profilingMode = ProfilingMode.off;
  final Map<RenderLayerType, List<Duration>> _layerProfiles = {};
  final List<FrameProfile> _frameProfiles = [];
  
  DeveloperTools({
    required this.coordinator,
    required this.enabled,
  });
  
  void setProfilingMode(ProfilingMode mode) {
    _profilingMode = mode;
    
    if (mode == ProfilingMode.off) {
      _clearProfiles();
    }
  }
  
  void recordLayerProfile({
    required RenderLayerType layer,
    required Duration duration,
  }) {
    if (_profilingMode == ProfilingMode.off) return;
    
    _layerProfiles.putIfAbsent(layer, () => []).add(duration);
    
    // Limit profile history
    final profiles = _layerProfiles[layer]!;
    while (profiles.length > 100) {
      profiles.removeAt(0);
    }
  }
  
  void recordFrameProfile({
    required int frameNumber,
    required Duration duration,
    required Set<RenderLayerType> layers,
  }) {
    if (_profilingMode != ProfilingMode.detailed) return;
    
    _frameProfiles.add(FrameProfile(
      frameNumber: frameNumber,
      duration: duration,
      layers: layers,
      timestamp: DateTime.now(),
    ));
    
    // Limit profile history
    while (_frameProfiles.length > 500) {
      _frameProfiles.removeAt(0);
    }
  }
  
  void _clearProfiles() {
    _layerProfiles.clear();
    _frameProfiles.clear();
  }
  
  Widget buildOverlay() {
    if (!enabled) return const SizedBox.shrink();
    
    return DeveloperOverlay(
      coordinator: coordinator,
      tools: this,
    );
  }
  
  Map<String, dynamic> exportProfile() {
    return {
      'mode': _profilingMode.toString(),
      'layerProfiles': _layerProfiles.map((key, value) => MapEntry(
        key.toString(),
        value.map((d) => d.inMicroseconds).toList(),
      )),
      'frameProfiles': _frameProfiles.map((p) => p.toJson()).toList(),
    };
  }
  
  void dispose() {
    _clearProfiles();
  }
}

/// Visual performance overlay widget
class DeveloperOverlay extends StatefulWidget {
  final RenderCoordinator coordinator;
  final DeveloperTools tools;
  
  const DeveloperOverlay({
    super.key,
    required this.coordinator,
    required this.tools,
  });
  
  @override
  State<DeveloperOverlay> createState() => _DeveloperOverlayState();
}

class _DeveloperOverlayState extends State<DeveloperOverlay> {
  Timer? _updateTimer;
  PerformanceSnapshot? _snapshot;
  bool _expanded = false;
  
  @override
  void initState() {
    super.initState();
    _startUpdateTimer();
  }
  
  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          _snapshot = widget.coordinator.getPerformanceSnapshot();
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_snapshot == null) return const SizedBox.shrink();
    
    return Positioned(
      top: 50,
      right: 10,
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _expanded ? 300 : 160,  // Increased from 150
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getPerformanceColor(_snapshot!.fps),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              if (_expanded) ..._buildExpandedContent(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'FPS: ${_snapshot!.fps.toStringAsFixed(1)}',
            style: TextStyle(
              color: _getPerformanceColor(_snapshot!.fps),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.white,
          size: 20,
        ),
      ],
    );
  }
  
  List<Widget> _buildExpandedContent() {
    return [
      const SizedBox(height: 8),
      _buildMetricRow('Frame Time', 
          '${_snapshot!.averageFrameTime.inMilliseconds}ms'),
      _buildMetricRow('Dropped', '${_snapshot!.droppedFrames}'),
      _buildMetricRow('Quality', _snapshot!.currentQuality.name),
      _buildMetricRow('Layers', '${_snapshot!.layerCount}'),
      _buildMetricRow('Memory', 
          '${(_snapshot!.memoryUsage / 1024 / 1024).toStringAsFixed(1)}MB'),
      const Divider(color: Colors.white24),
      _buildProfilingControls(),
    ];
  }
  
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfilingControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profiling Mode',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
              child: _buildProfilingButton('Off', ProfilingMode.off),
            ),
            Flexible(
              child: _buildProfilingButton('Basic', ProfilingMode.basic),
            ),
            Flexible(
              child: _buildProfilingButton('Full', ProfilingMode.detailed),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _exportProfile,
            child: const Text(
              'Export Profile',
              style: TextStyle(color: Colors.blueAccent, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildProfilingButton(String label, ProfilingMode mode) {
    final isActive = widget.coordinator.profilingMode == mode;
    
    return TextButton(
      onPressed: () => widget.coordinator.setProfilingMode(mode),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        backgroundColor: isActive ? Colors.blueAccent : Colors.transparent,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white70,
          fontSize: 10,
        ),
      ),
    );
  }
  
  void _exportProfile() {
    final profile = widget.tools.exportProfile();
    debugPrint('Profile exported: ${profile.toString()}');
    
    // In production, this would save to file or send to server
    Clipboard.setData(ClipboardData(
      text: profile.toString(),
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  Color _getPerformanceColor(double fps) {
    if (fps >= 58) return Colors.green;
    if (fps >= 50) return Colors.yellow;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Priority queue implementation
class PriorityQueue<T extends Comparable> {
  final List<T> _items = [];
  
  void add(T item) {
    _items.add(item);
    _items.sort();
  }
  
  T removeFirst() {
    if (_items.isEmpty) {
      throw StateError('Priority queue is empty');
    }
    return _items.removeAt(0);
  }
  
  T get first => _items.first;
  
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  
  void clear() => _items.clear();
}

// Data classes and enums

/// Render layer types
enum RenderLayerType {
  coordinator,
  static,
  dynamic,
  effects,
  ui,
}

/// Render priority levels
enum RenderPriority implements Comparable<RenderPriority> {
  low(0),
  normal(1),
  high(2),
  critical(3);
  
  final int value;
  const RenderPriority(this.value);
  
  @override
  int compareTo(RenderPriority other) => other.value.compareTo(value);
}

/// Quality levels with comparison operators
enum QualityLevel {
  low(0),
  medium(1),
  high(2),
  ultra(3);
  
  final int value;
  const QualityLevel(this.value);
  
  bool operator >(QualityLevel other) => value > other.value;
  bool operator <(QualityLevel other) => value < other.value;
  bool operator >=(QualityLevel other) => value >= other.value;
  bool operator <=(QualityLevel other) => value <= other.value;
}

/// Profiling modes
enum ProfilingMode {
  off,
  basic,
  detailed,
}

/// Message types for layer communication
enum MessageType {
  update,
  stateChange,
  qualityChanged,
  performanceWarning,
  custom,
}

/// Configuration for render coordinator
class RenderCoordinatorConfig {
  final int targetFrameRate;
  final Duration targetFrameDuration;
  final QualityLevel initialQuality;
  final bool autoAdaptQuality;
  final bool enableDeveloperTools;
  
  const RenderCoordinatorConfig({
    this.targetFrameRate = 60,
    this.targetFrameDuration = const Duration(milliseconds: 16),
    this.initialQuality = QualityLevel.high,
    this.autoAdaptQuality = true,
    this.enableDeveloperTools = true,
  });
}

/// Frame request for scheduling
class FrameRequest implements Comparable<FrameRequest> {
  final Set<RenderLayerType> layers;
  final RenderPriority priority;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  
  const FrameRequest({
    required this.layers,
    required this.priority,
    required this.metadata,
    required this.timestamp,
  });
  
  @override
  int compareTo(FrameRequest other) {
    final priorityCompare = priority.compareTo(other.priority);
    if (priorityCompare != 0) return priorityCompare;
    return timestamp.compareTo(other.timestamp);
  }
}

/// Frame timing information
class FrameTiming {
  final Duration timestamp;
  final Duration duration;
  final int frameNumber;
  
  const FrameTiming({
    required this.timestamp,
    required this.duration,
    required this.frameNumber,
  });
}

/// Frame metrics
class FrameMetrics {
  final DateTime timestamp;
  final Duration duration;
  final Set<RenderLayerType> layersRendered;
  final RenderPriority priority;
  
  const FrameMetrics({
    required this.timestamp,
    required this.duration,
    required this.layersRendered,
    required this.priority,
  });
}

/// Layer metrics
class LayerMetrics {
  final RenderLayerType layer;
  final List<Duration> _renderTimes = [];
  int _renderCount = 0;
  
  LayerMetrics({required this.layer});
  
  void recordRender(Duration duration) {
    _renderTimes.add(duration);
    _renderCount++;
    
    // Keep only recent times
    while (_renderTimes.length > 100) {
      _renderTimes.removeAt(0);
    }
  }
  
  Map<String, dynamic> getSummary() {
    if (_renderTimes.isEmpty) {
      return {'renderCount': 0};
    }
    
    final totalTime = _renderTimes.reduce((a, b) => a + b);
    final averageTime = totalTime ~/ _renderTimes.length;
    
    return {
      'renderCount': _renderCount,
      'averageTime': averageTime.inMicroseconds,
      'lastTime': _renderTimes.last.inMicroseconds,
    };
  }
}

/// Performance snapshot
class PerformanceSnapshot {
  final double fps;
  final int droppedFrames;
  final Duration averageFrameTime;
  final int totalFrames;
  final QualityLevel currentQuality;
  final int layerCount;
  final double memoryUsage;
  
  const PerformanceSnapshot({
    required this.fps,
    required this.droppedFrames,
    required this.averageFrameTime,
    required this.totalFrames,
    required this.currentQuality,
    required this.layerCount,
    required this.memoryUsage,
  });
}

/// Frame profile for detailed analysis
class FrameProfile {
  final int frameNumber;
  final Duration duration;
  final Set<RenderLayerType> layers;
  final DateTime timestamp;
  
  const FrameProfile({
    required this.frameNumber,
    required this.duration,
    required this.layers,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'frameNumber': frameNumber,
    'duration': duration.inMicroseconds,
    'layers': layers.map((l) => l.toString()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Layer message for communication bus
class LayerMessage {
  final MessageType type;
  final RenderLayerType sender;
  final RenderLayerType? recipient;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  LayerMessage({
    required this.type,
    required this.sender,
    this.recipient,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Base class for render layers
abstract class RenderLayer {
  RenderCoordinator? _coordinator;
  StreamSubscription<LayerMessage>? _messageSubscription;
  bool _needsUpdate = false;
  
  bool get needsUpdate => _needsUpdate;
  
  void _attachToCoordinator(RenderCoordinator coordinator) {
    _coordinator = coordinator;
  }
  
  void _detachFromCoordinator() {
    _messageSubscription?.cancel();
    _coordinator = null;
  }
  
  /// Mark this layer as needing update
  void markNeedsUpdate() {
    _needsUpdate = true;
    _coordinator?.scheduleFrame(
      layers: {layerType},
    );
  }
  
  /// Render this layer
  void render() {
    _needsUpdate = false;
    performRender();
  }
  
  /// Perform actual rendering (override in subclasses)
  void performRender();
  
  /// Handle incoming message
  void handleMessage(LayerMessage message) {
    // Override in subclasses to handle messages
  }
  
  /// Update quality settings
  void updateQuality(QualityLevel quality) {
    // Override in subclasses to handle quality changes
  }
  
  /// Get layer type (override in subclasses)
  RenderLayerType get layerType;
}
