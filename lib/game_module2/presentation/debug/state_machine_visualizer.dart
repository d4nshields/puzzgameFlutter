import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../domain/services/piece_state_machine.dart';
import '../../domain/services/state_transitions.dart';

/// Visual debugger for piece state machines
class StateMachineVisualizer extends StatefulWidget {
  final PieceStateMachine stateMachine;
  final bool showEventHistory;
  final bool showStateGraph;
  final bool showMetadata;
  final bool showTransitions;
  final VoidCallback? onClose;
  
  const StateMachineVisualizer({
    Key? key,
    required this.stateMachine,
    this.showEventHistory = true,
    this.showStateGraph = true,
    this.showMetadata = true,
    this.showTransitions = true,
    this.onClose,
  }) : super(key: key);
  
  @override
  State<StateMachineVisualizer> createState() => _StateMachineVisualizerState();
}

class _StateMachineVisualizerState extends State<StateMachineVisualizer>
    with TickerProviderStateMixin {
  late StreamSubscription<PieceStateType> _stateSubscription;
  late StreamSubscription<PieceEvent> _eventSubscription;
  
  PieceStateType _currentState = PieceStateType.idle;
  final List<_EventRecord> _recentEvents = [];
  final Map<StateRegion, PieceStateType> _parallelStates = {};
  Map<String, dynamic> _metadata = {};
  Duration _timeInState = Duration.zero;
  Timer? _timeUpdateTimer;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _transitionController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _transitionAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _transitionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
    ));
    
    // Subscribe to state machine
    _currentState = widget.stateMachine.currentState;
    _parallelStates.addAll(widget.stateMachine.parallelStates);
    _metadata = Map.from(widget.stateMachine.metadata);
    
    _stateSubscription = widget.stateMachine.stateChangeStream.listen((state) {
      setState(() {
        _currentState = state;
        _parallelStates.addAll(widget.stateMachine.parallelStates);
        _transitionController.forward(from: 0.0);
      });
    });
    
    _eventSubscription = widget.stateMachine.eventStream.listen((event) {
      setState(() {
        _recentEvents.add(_EventRecord(
          event: event,
          timestamp: DateTime.now(),
        ));
        if (_recentEvents.length > 10) {
          _recentEvents.removeAt(0);
        }
        _metadata = Map.from(widget.stateMachine.metadata);
      });
    });
    
    // Update time in state
    _timeUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _timeInState = widget.stateMachine.timeInCurrentState;
      });
    });
  }
  
  @override
  void dispose() {
    _stateSubscription.cancel();
    _eventSubscription.cancel();
    _timeUpdateTimer?.cancel();
    _pulseController.dispose();
    _transitionController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (widget.showStateGraph) _buildStateGraph(),
          if (widget.showTransitions) _buildAvailableTransitions(),
          if (widget.showEventHistory) _buildEventHistory(),
          if (widget.showMetadata) _buildMetadata(),
          _buildControls(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.memory,
            color: Colors.green.shade400,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'State Machine: ${widget.stateMachine.pieceId}',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Current: ${_currentState.toString().split('.').last}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStateGraph() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade800),
      ),
      child: CustomPaint(
        painter: _StateGraphPainter(
          currentState: _currentState,
          parallelStates: _parallelStates,
          pulseAnimation: _pulseAnimation,
          transitionAnimation: _transitionAnimation,
        ),
        child: Container(),
      ),
    );
  }
  
  Widget _buildAvailableTransitions() {
    final vizData = widget.stateMachine.getVisualizationData();
    final transitions = vizData['availableTransitions'] as List? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade900),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Transitions',
            style: TextStyle(
              color: Colors.green.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          if (transitions.isEmpty)
            const Text(
              'No transitions available',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            )
          else
            ...transitions.map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_forward,
                    size: 12,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${t['to']}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  if (t['hasGuard'] == true)
                    Icon(
                      Icons.shield,
                      size: 12,
                      color: Colors.orange.shade600,
                    ),
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }
  
  Widget _buildEventHistory() {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade900),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Event History',
                style: TextStyle(
                  color: Colors.green.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                'Time in state: ${_formatDuration(_timeInState)}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _recentEvents.length,
              itemBuilder: (context, index) {
                final record = _recentEvents[_recentEvents.length - 1 - index];
                return _buildEventRow(record);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventRow(_EventRecord record) {
    final eventName = record.event.runtimeType.toString()
        .replaceAll('Piece', '')
        .replaceAll('Event', '');
    final timeDiff = DateTime.now().difference(record.timestamp);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.green.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              eventName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Text(
            '${timeDiff.inSeconds}s ago',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetadata() {
    if (_metadata.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade900),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metadata',
            style: TextStyle(
              color: Colors.green.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          ..._metadata.entries.take(5).map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '${entry.key}:',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.undo,
            label: 'Undo',
            onPressed: () => widget.stateMachine.undo(),
          ),
          _buildControlButton(
            icon: Icons.history,
            label: 'Rollback',
            onPressed: () => widget.stateMachine.rollback(),
          ),
          _buildControlButton(
            icon: Icons.file_download,
            label: 'Export',
            onPressed: _exportState,
          ),
          _buildControlButton(
            icon: Icons.bug_report,
            label: widget.stateMachine.debugMode ? 'Debug On' : 'Debug Off',
            onPressed: () {
              setState(() {
                widget.stateMachine.debugMode = !widget.stateMachine.debugMode;
              });
            },
            active: widget.stateMachine.debugMode,
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.green.shade800 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : Colors.white54,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _exportState() {
    final state = widget.stateMachine.exportState();
    final stateString = state.toString();
    
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: stateString));
    
    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('State exported to clipboard'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = (duration.inMilliseconds % 1000) ~/ 100;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else if (seconds > 0) {
      return '${seconds}.${milliseconds}s';
    } else {
      return '${duration.inMilliseconds}ms';
    }
  }
}

/// Record of an event for display
class _EventRecord {
  final PieceEvent event;
  final DateTime timestamp;
  
  _EventRecord({
    required this.event,
    required this.timestamp,
  });
}

/// Custom painter for state graph visualization
class _StateGraphPainter extends CustomPainter {
  final PieceStateType currentState;
  final Map<StateRegion, PieceStateType> parallelStates;
  final Animation<double> pulseAnimation;
  final Animation<double> transitionAnimation;
  
  _StateGraphPainter({
    required this.currentState,
    required this.parallelStates,
    required this.pulseAnimation,
    required this.transitionAnimation,
  }) : super(repaint: Listenable.merge([pulseAnimation, transitionAnimation]));
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // Define state positions
    final statePositions = _calculateStatePositions(size);
    
    // Draw connections
    _drawConnections(canvas, statePositions, paint);
    
    // Draw states
    for (final entry in statePositions.entries) {
      final state = entry.key;
      final position = entry.value;
      final isActive = state == currentState || parallelStates.values.contains(state);
      final isCurrent = state == currentState;
      
      _drawState(
        canvas,
        position,
        state.toString().split('.').last,
        isActive,
        isCurrent,
        paint,
      );
    }
  }
  
  Map<PieceStateType, Offset> _calculateStatePositions(Size size) {
    final positions = <PieceStateType, Offset>{};
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Arrange states in a circular pattern
    final states = PieceStateType.values;
    final angleStep = (2 * math.pi) / states.length;
    final radius = math.min(size.width, size.height) * 0.35;
    
    for (int i = 0; i < states.length; i++) {
      final angle = i * angleStep - math.pi / 2;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      positions[states[i]] = Offset(x, y);
    }
    
    return positions;
  }
  
  void _drawConnections(
    Canvas canvas,
    Map<PieceStateType, Offset> positions,
    Paint paint,
  ) {
    paint
      ..color = Colors.green.withOpacity(0.2)
      ..strokeWidth = 1.0;
    
    // Define state connections (simplified)
    final connections = [
      [PieceStateType.idle, PieceStateType.hovering],
      [PieceStateType.hovering, PieceStateType.selected],
      [PieceStateType.selected, PieceStateType.dragging],
      [PieceStateType.dragging, PieceStateType.snapping],
      [PieceStateType.snapping, PieceStateType.placed],
      [PieceStateType.placed, PieceStateType.locked],
      [PieceStateType.dragging, PieceStateType.magnetized],
      [PieceStateType.dragging, PieceStateType.returning],
      [PieceStateType.placed, PieceStateType.celebrating],
      [PieceStateType.dragging, PieceStateType.invalid],
      [PieceStateType.invalid, PieceStateType.returning],
      [PieceStateType.returning, PieceStateType.idle],
    ];
    
    for (final connection in connections) {
      final from = positions[connection[0]];
      final to = positions[connection[1]];
      if (from != null && to != null) {
        canvas.drawLine(from, to, paint);
        
        // Draw arrow
        final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
        final arrowLength = 8.0;
        final arrowAngle = 0.3;
        
        final arrowPoint = Offset(
          to.dx - 20 * math.cos(angle),
          to.dy - 20 * math.sin(angle),
        );
        
        canvas.drawLine(
          arrowPoint,
          Offset(
            arrowPoint.dx - arrowLength * math.cos(angle - arrowAngle),
            arrowPoint.dy - arrowLength * math.sin(angle - arrowAngle),
          ),
          paint,
        );
        
        canvas.drawLine(
          arrowPoint,
          Offset(
            arrowPoint.dx - arrowLength * math.cos(angle + arrowAngle),
            arrowPoint.dy - arrowLength * math.sin(angle + arrowAngle),
          ),
          paint,
        );
      }
    }
  }
  
  void _drawState(
    Canvas canvas,
    Offset position,
    String label,
    bool isActive,
    bool isCurrent,
    Paint paint,
  ) {
    final radius = isCurrent ? 20.0 * pulseAnimation.value : 20.0;
    
    // Draw outer circle
    paint
      ..style = PaintingStyle.fill
      ..color = isActive
          ? (isCurrent ? Colors.green.shade400 : Colors.green.shade700)
          : Colors.grey.shade800;
    
    canvas.drawCircle(position, radius, paint);
    
    // Draw border
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = isActive
          ? (isCurrent ? Colors.green.shade300 : Colors.green.shade600)
          : Colors.grey.shade600;
    
    canvas.drawCircle(position, radius, paint);
    
    // Draw label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white54,
          fontSize: 9,
          fontFamily: 'monospace',
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
  
  @override
  bool shouldRepaint(_StateGraphPainter oldDelegate) {
    return oldDelegate.currentState != currentState ||
           oldDelegate.parallelStates != parallelStates;
  }
}

/// Debug panel that shows all state machines
class StateMachineDebugPanel extends StatefulWidget {
  final Map<String, PieceStateMachine> stateMachines;
  final TransitionRecorder? recorder;
  final bool floating;
  
  const StateMachineDebugPanel({
    Key? key,
    required this.stateMachines,
    this.recorder,
    this.floating = true,
  }) : super(key: key);
  
  @override
  State<StateMachineDebugPanel> createState() => _StateMachineDebugPanelState();
}

class _StateMachineDebugPanelState extends State<StateMachineDebugPanel> {
  bool _expanded = false;
  String? _selectedMachine;
  
  @override
  Widget build(BuildContext context) {
    if (widget.floating) {
      return Positioned(
        top: 100,
        right: 10,
        child: _buildContent(),
      );
    }
    
    return _buildContent();
  }
  
  Widget _buildContent() {
    if (!_expanded) {
      return _buildCollapsedView();
    }
    
    if (_selectedMachine != null && widget.stateMachines[_selectedMachine] != null) {
      return StateMachineVisualizer(
        stateMachine: widget.stateMachines[_selectedMachine]!,
        onClose: () {
          setState(() {
            _selectedMachine = null;
            _expanded = false;
          });
        },
      );
    }
    
    return _buildMachineList();
  }
  
  Widget _buildCollapsedView() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.memory, color: Colors.green.shade400, size: 20),
            const SizedBox(width: 4),
            Text(
              'State Machines (${widget.stateMachines.length})',
              style: TextStyle(
                color: Colors.green.shade300,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMachineList() {
    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade400, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildListHeader(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.stateMachines.length,
              itemBuilder: (context, index) {
                final entry = widget.stateMachines.entries.elementAt(index);
                return _buildMachineRow(entry.key, entry.value);
              },
            ),
          ),
          if (widget.recorder != null) _buildStatistics(),
        ],
      ),
    );
  }
  
  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Icon(Icons.memory, color: Colors.green.shade400, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'State Machines',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 16),
            onPressed: () => setState(() => _expanded = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMachineRow(String id, PieceStateMachine machine) {
    return InkWell(
      onTap: () => setState(() => _selectedMachine = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.green.shade900.withOpacity(0.3)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getStateColor(machine.currentState),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    machine.currentState.toString().split('.').last,
                    style: TextStyle(
                      color: Colors.green.shade400,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatistics() {
    final stats = widget.recorder!.getStatistics();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStat('Total', stats['totalTransitions'].toString()),
          _buildStat('Success', '${((stats['successRate'] as double) * 100).toInt()}%'),
          _buildStat('Avg Time', '${stats['averageDuration']}ms'),
        ],
      ),
    );
  }
  
  Widget _buildStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.green.shade400,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
  
  Color _getStateColor(PieceStateType state) {
    switch (state) {
      case PieceStateType.idle:
        return Colors.grey;
      case PieceStateType.hovering:
        return Colors.blue;
      case PieceStateType.selected:
        return Colors.yellow;
      case PieceStateType.dragging:
        return Colors.orange;
      case PieceStateType.snapping:
        return Colors.purple;
      case PieceStateType.magnetized:
        return Colors.pink;
      case PieceStateType.placed:
        return Colors.green;
      case PieceStateType.locked:
        return Colors.teal;
      case PieceStateType.celebrating:
        return Colors.amber;
      case PieceStateType.invalid:
        return Colors.red;
      case PieceStateType.returning:
        return Colors.indigo;
    }
  }
}
