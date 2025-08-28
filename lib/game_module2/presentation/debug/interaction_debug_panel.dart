import 'package:flutter/material.dart';
import '../../application/workspace_controller.dart';
import '../../infrastructure/configuration_manager.dart';
// Removed unused import - feature_flags.dart

/// Debug panel for testing and monitoring the interaction integration.
/// 
/// This panel provides real-time monitoring and control of all integrated
/// systems including state machines, gestures, feedback, and performance.
class InteractionDebugPanel extends StatefulWidget {
  final WorkspaceController controller;
  
  const InteractionDebugPanel({
    Key? key,
    required this.controller,
  }) : super(key: key);
  
  @override
  State<InteractionDebugPanel> createState() => _InteractionDebugPanelState();
}

class _InteractionDebugPanelState extends State<InteractionDebugPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _expanded = false;
  
  // Performance metrics
  final Map<String, dynamic> _performanceMetrics = {};
  
  // Event log
  final List<String> _eventLog = [];
  static const int _maxLogSize = 50;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    
    // Listen to controller changes
    widget.controller.addListener(_onControllerChanged);
    
    // Subscribe to debug events
    _subscribeToDebugEvents();
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _tabController.dispose();
    super.dispose();
  }
  
  void _onControllerChanged() {
    setState(() {
      _performanceMetrics.addAll(widget.controller.performanceMetrics);
    });
  }
  
  void _subscribeToDebugEvents() {
    // Subscribe to various events for logging
    widget.controller.eventBus.on<dynamic>().listen((event) {
      _logEvent(event.runtimeType.toString());
    });
  }
  
  void _logEvent(String event) {
    setState(() {
      _eventLog.insert(0, '${DateTime.now().toString().substring(11, 19)} - $event');
      while (_eventLog.length > _maxLogSize) {
        _eventLog.removeLast();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.controller.debugMode) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      right: 0,
      top: 100,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _expanded ? 400 : 48,
        height: _expanded ? 600 : 48,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(-2, 2),
            ),
          ],
        ),
        child: _expanded ? _buildExpandedPanel() : _buildCollapsedPanel(),
      ),
    );
  }
  
  Widget _buildCollapsedPanel() {
    return IconButton(
      icon: const Icon(Icons.bug_report, color: Colors.green),
      onPressed: () => setState(() => _expanded = true),
      tooltip: 'Open Debug Panel',
    );
  }
  
  Widget _buildExpandedPanel() {
    return Column(
      children: [
        _buildHeader(),
        _buildTabs(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStateTab(),
              _buildGestureTab(),
              _buildFeedbackTab(),
              _buildPerformanceTab(),
              _buildConfigTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Interaction Debug Panel',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
            onPressed: _refreshMetrics,
            tooltip: 'Refresh Metrics',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () => setState(() => _expanded = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.green,
      unselectedLabelColor: Colors.white60,
      indicatorColor: Colors.green,
      tabs: const [
        Tab(text: 'State'),
        Tab(text: 'Gesture'),
        Tab(text: 'Feedback'),
        Tab(text: 'Perf'),
        Tab(text: 'Config'),
      ],
    );
  }
  
  Widget _buildStateTab() {
    final integration = widget.controller.interactionIntegration;
    if (integration == null) {
      return const Center(
        child: Text(
          'Interaction Integration not initialized',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }
    
    final debugInfo = integration.exportDebugInfo();
    final stateMachines = debugInfo['stateMachines'] as Map<String, dynamic>? ?? {};
    
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionHeader('Piece States'),
        ...stateMachines.entries.map((entry) {
          final pieceId = entry.key;
          final stateInfo = entry.value as Map<String, dynamic>;
          final currentState = stateInfo['currentState'] ?? 'unknown';
          final history = (stateInfo['history'] as List? ?? []).take(3).toList();
          
          return Card(
            color: Colors.grey[900],
            child: ExpansionTile(
              title: Text(
                'Piece $pieceId',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              subtitle: Text(
                'State: $currentState',
                style: TextStyle(
                  color: _getStateColor(currentState),
                  fontSize: 11,
                ),
              ),
              children: [
                if (history.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'History:',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  ...history.map((state) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                    child: Text(
                      '• $state',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  )),
                ],
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        _buildSectionHeader('Event Log'),
        Container(
          height: 150,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            itemCount: _eventLog.length,
            itemBuilder: (context, index) {
              return Text(
                _eventLog[index],
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildGestureTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionHeader('Magnetic Field'),
        _buildSlider(
          'Field Strength',
          'magnetic_field.strength',
          0.1,
          1.0,
        ),
        _buildSlider(
          'Snap Radius',
          'magnetic_field.snap_radius',
          10.0,
          100.0,
        ),
        _buildSlider(
          'Min Influence',
          'magnetic_field.minimum_influence',
          0.0,
          0.5,
        ),
        _buildSlider(
          'Max Influence',
          'magnetic_field.max_influence',
          1.0,
          20.0,
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Gesture Settings'),
        _buildSwitch('Multi-touch', 'gestures.multi_touch'),
        _buildSwitch('Hints Enabled', 'gestures.hints_enabled'),
        _buildSwitch('Accessibility Mode', 'gestures.accessibility_mode'),
        _buildSlider(
          'Drag Threshold',
          'gestures.drag_threshold',
          5.0,
          30.0,
        ),
      ],
    );
  }
  
  Widget _buildFeedbackTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionHeader('Feedback Channels'),
        _buildSwitch('Haptic', 'feedback.haptic_enabled'),
        _buildSwitch('Audio', 'feedback.audio_enabled'),
        _buildSwitch('Visual', 'feedback.visual_enabled'),
        _buildSwitch('Adaptive Intensity', 'feedback.adaptive_intensity'),
        _buildSlider(
          'Base Intensity',
          'feedback.base_intensity',
          0.0,
          1.0,
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Test Feedback'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeedbackTestButton('Pickup', 'piece_pickup'),
            _buildFeedbackTestButton('Drag', 'piece_drag'),
            _buildFeedbackTestButton('Near Snap', 'near_snap'),
            _buildFeedbackTestButton('Snap', 'successful_placement'),
            _buildFeedbackTestButton('Hint', 'hint'),
            _buildFeedbackTestButton('Complete', 'puzzle_complete'),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPerformanceTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionHeader('Performance Metrics'),
        ..._performanceMetrics.entries.map((entry) {
          final metrics = entry.value as Map<String, dynamic>? ?? {};
          return Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow('Avg Frame Time',
                      '${metrics['averageFrameTime']?.toStringAsFixed(2) ?? 'N/A'} ms'),
                  _buildMetricRow('Max Frame Time',
                      '${metrics['maxFrameTime']?.toStringAsFixed(2) ?? 'N/A'} ms'),
                  _buildMetricRow('Dropped Frames',
                      '${metrics['droppedFrames'] ?? 0}'),
                  _buildMetricRow('Memory',
                      '${metrics['memoryUsage']?.toStringAsFixed(1) ?? 'N/A'} MB'),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        _buildSectionHeader('Quality Settings'),
        _buildSwitch('Adaptive Quality', 'performance.adaptive_quality'),
        _buildSwitch('Battery Saver', 'performance.battery_saver_mode'),
        _buildSlider(
          'Target FPS',
          'rendering.target_fps',
          30,
          120,
          divisions: 3,
        ),
      ],
    );
  }
  
  Widget _buildConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionHeader('Configuration Profiles'),
        _buildProfileButton('Performance', ProfileType.performance),
        _buildProfileButton('Quality', ProfileType.quality),
        _buildProfileButton('Battery Saver', ProfileType.battery),
        _buildProfileButton('Accessibility', ProfileType.accessibility),
        _buildProfileButton('Debug', ProfileType.debug),
        const SizedBox(height: 16),
        _buildSectionHeader('Feature Flags'),
        _buildFeatureFlag('Hybrid Rendering', 'hybrid_rendering'),
        _buildFeatureFlag('Particle Effects', 'particle_effects'),
        _buildFeatureFlag('Magnetic Gestures', 'magnetic_gestures'),
        _buildFeatureFlag('Field Visualization', 'magnetic_field_visualization'),
        _buildFeatureFlag('State Visualization', 'state_visualization'),
        _buildFeatureFlag('Debug Overlay', 'debug_overlay'),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.file_download),
            label: const Text('Export Debug Info'),
            onPressed: _exportDebugInfo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.green,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
  
  Widget _buildSlider(
    String label,
    String configKey,
    double min,
    double max, {
    int? divisions,
  }) {
    // This would be connected to actual configuration
    double value = 0.5;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? 20,
          activeColor: Colors.green,
          inactiveColor: Colors.grey[700],
          onChanged: (newValue) {
            // Update configuration
          },
        ),
      ],
    );
  }
  
  Widget _buildSwitch(String label, String configKey) {
    // This would be connected to actual configuration
    bool value = true;
    
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      value: value,
      activeColor: Colors.green,
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: (newValue) {
        // Update configuration
      },
    );
  }
  
  Widget _buildFeatureFlag(String label, String flagName) {
    // TODO: Check actual feature flag when FeatureFlagService is available
    // final isEnabled = widget.controller.featureFlags.isEnabled(flagName);
    final isEnabled = false; // Default to false for now
    
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      value: isEnabled,
      activeColor: Colors.green,
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: (newValue) {
        // Toggle feature flag
      },
    );
  }
  
  Widget _buildProfileButton(String label, ProfileType profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton(
        onPressed: () async {
          await widget.controller.applyConfigurationProfile(profile);
          _logEvent('Applied profile: $label');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green,
          side: const BorderSide(color: Colors.green),
        ),
        child: Text(label),
      ),
    );
  }
  
  Widget _buildFeedbackTestButton(String label, String pattern) {
    return ElevatedButton(
      onPressed: () {
        // Trigger feedback
        _logEvent('Test feedback: $pattern');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
  
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStateColor(String state) {
    switch (state.toLowerCase()) {
      case 'idle':
        return Colors.grey;
      case 'hovering':
        return Colors.blue;
      case 'selected':
        return Colors.cyan;
      case 'dragging':
        return Colors.orange;
      case 'snapping':
        return Colors.yellow;
      case 'magnetized':
        return Colors.purple;
      case 'placed':
        return Colors.green;
      case 'locked':
        return Colors.green[700]!;
      case 'celebrating':
        return Colors.pink;
      case 'invalid':
        return Colors.red;
      case 'returning':
        return Colors.amber;
      default:
        return Colors.white;
    }
  }
  
  void _refreshMetrics() {
    setState(() {
      // Trigger metrics collection
      _logEvent('Metrics refreshed');
    });
  }
  
  void _exportDebugInfo() {
    final debugInfo = widget.controller.exportDebugInfo();
    // In a real app, this would save to file or share
    print('Debug Info: ${debugInfo.toString()}');
    _logEvent('Debug info exported');
  }
}
