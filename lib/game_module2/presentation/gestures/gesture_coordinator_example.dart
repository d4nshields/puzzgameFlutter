import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:puzzgame_flutter/game_module2/presentation/gestures/gesture_coordinator.dart';
import 'package:puzzgame_flutter/game_module2/presentation/gestures/magnetic_gesture_recognizer.dart';

/// Example widget demonstrating the GestureCoordinator usage.
class GestureCoordinatorExample extends StatefulWidget {
  const GestureCoordinatorExample({super.key});

  @override
  State<GestureCoordinatorExample> createState() => _GestureCoordinatorExampleState();
}

class _GestureCoordinatorExampleState extends State<GestureCoordinatorExample> {
  late GestureCoordinator _coordinator;
  
  // UI State
  String _lastGesture = 'None';
  String _lastAction = 'None';
  Offset _piecePosition = const Offset(200, 200);
  double _rotation = 0.0;
  double _scale = 1.0;
  bool _isRecording = false;
  RecordedGestures? _recordedGestures;
  
  // Gesture recognizers
  late TapGestureRecognizer _tapRecognizer;
  late DoubleTapGestureRecognizer _doubleTapRecognizer;
  late LongPressGestureRecognizer _longPressRecognizer;
  late PanGestureRecognizer _panRecognizer;
  late ScaleGestureRecognizer _scaleRecognizer;
  late MagneticGestureRecognizer _magneticRecognizer;

  @override
  void initState() {
    super.initState();
    _initializeCoordinator();
    _setupGestureRecognizers();
    _registerInputActions();
    _setupComposedGestures();
  }

  void _initializeCoordinator() {
    _coordinator = GestureCoordinator();
    
    // We'll initialize with context in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize coordinator with context
    _coordinator.initialize(
      context: context,
      config: GestureConfiguration(
        dragThreshold: 18.0,
        longPressTimeout: const Duration(milliseconds: 500),
        doubleTapTimeout: const Duration(milliseconds: 300),
        recordGestures: false,
      ),
    );
  }

  void _setupGestureRecognizers() {
    // Tap recognizer
    _tapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        setState(() {
          _lastGesture = 'Tap';
        });
      };
    
    _coordinator.registerGesture(
      type: GestureType.tap,
      recognizer: _tapRecognizer,
      priority: 5,
      callback: (type, state) {
        if (state == GestureState.recognized) {
          debugPrint('Tap recognized');
        }
      },
    );
    
    // Double tap recognizer
    _doubleTapRecognizer = DoubleTapGestureRecognizer()
      ..onDoubleTap = () {
        setState(() {
          _lastGesture = 'Double Tap';
          _scale = 1.0; // Reset scale
        });
      };
    
    _coordinator.registerGesture(
      type: GestureType.doubleTap,
      recognizer: _doubleTapRecognizer,
      priority: 6,
    );
    
    // Long press recognizer
    _longPressRecognizer = LongPressGestureRecognizer()
      ..onLongPress = () {
        setState(() {
          _lastGesture = 'Long Press';
        });
        _showContextMenu();
      };
    
    _coordinator.registerGesture(
      type: GestureType.longPress,
      recognizer: _longPressRecognizer,
      priority: 4,
    );
    
    // Pan recognizer for dragging
    _panRecognizer = PanGestureRecognizer()
      ..onUpdate = (details) {
        setState(() {
          _piecePosition += details.delta;
          _lastGesture = 'Drag';
        });
      };
    
    _coordinator.registerGesture(
      type: GestureType.drag,
      recognizer: _panRecognizer,
      priority: 8,
    );
    
    // Scale recognizer for pinch zoom and rotation
    _scaleRecognizer = ScaleGestureRecognizer()
      ..onUpdate = (details) {
        setState(() {
          _scale = details.scale.clamp(0.5, 3.0);
          _rotation = details.rotation;
          _lastGesture = 'Scale/Rotate';
        });
      };
    
    _coordinator.registerGesture(
      type: GestureType.scale,
      recognizer: _scaleRecognizer,
      priority: 9,
    );
    
    // Magnetic gesture recognizer
    _magneticRecognizer = MagneticGestureRecognizer(
      fieldConfig: MagneticFieldConfiguration(
        snapPoints: [
          const MagneticSnapPoint(
            position: Offset(200, 400),
            radius: 50,
            strength: 0.8,
          ),
          const MagneticSnapPoint(
            position: Offset(400, 400),
            radius: 50,
            strength: 0.8,
          ),
        ],
        strength: 0.4,
      ),
    )
      ..onUpdate = (details) {
        setState(() {
          _piecePosition += details.delta;
          _lastGesture = 'Magnetic Drag';
        });
      }
      ..onMagneticInfluence = (influence) {
        debugPrint('Magnetic influence: ${influence.strength}');
      };
    
    _coordinator.registerGesture(
      type: GestureType.magnetic,
      recognizer: _magneticRecognizer,
      priority: 10, // Highest priority for magnetic gestures
    );
    
    // Add conflict resolver
    _coordinator.addConflictResolver(_resolveGestureConflict);
  }

  ConflictResolution? _resolveGestureConflict(
    List<ActiveGesture> gestures,
    PointerEvent event,
  ) {
    // Custom conflict resolution logic
    // For example, if both drag and tap are possible, prefer drag
    final hasDrag = gestures.any((g) => g.type == GestureType.drag);
    final hasTap = gestures.any((g) => g.type == GestureType.tap);
    
    if (hasDrag && hasTap) {
      return ConflictResolution(
        allowedGestures: [GestureType.drag],
        primaryGesture: GestureType.drag,
      );
    }
    
    // Let default resolution handle other cases
    return null;
  }

  void _registerInputActions() {
    // Register keyboard actions
    final inputManager = UnifiedInputManager();
    
    inputManager.registerAction(GestureAction.moveUp, () {
      setState(() {
        _piecePosition = Offset(_piecePosition.dx, _piecePosition.dy - 10);
        _lastAction = 'Move Up';
      });
    });
    
    inputManager.registerAction(GestureAction.moveDown, () {
      setState(() {
        _piecePosition = Offset(_piecePosition.dx, _piecePosition.dy + 10);
        _lastAction = 'Move Down';
      });
    });
    
    inputManager.registerAction(GestureAction.moveLeft, () {
      setState(() {
        _piecePosition = Offset(_piecePosition.dx - 10, _piecePosition.dy);
        _lastAction = 'Move Left';
      });
    });
    
    inputManager.registerAction(GestureAction.moveRight, () {
      setState(() {
        _piecePosition = Offset(_piecePosition.dx + 10, _piecePosition.dy);
        _lastAction = 'Move Right';
      });
    });
    
    inputManager.registerAction(GestureAction.rotateLeft, () {
      setState(() {
        _rotation -= 0.1;
        _lastAction = 'Rotate Left';
      });
    });
    
    inputManager.registerAction(GestureAction.rotateRight, () {
      setState(() {
        _rotation += 0.1;
        _lastAction = 'Rotate Right';
      });
    });
    
    inputManager.registerAction(GestureAction.select, () {
      setState(() {
        _lastAction = 'Select';
      });
    });
    
    inputManager.registerAction(GestureAction.undo, () {
      setState(() {
        _lastAction = 'Undo';
        // Reset position
        _piecePosition = const Offset(200, 200);
        _rotation = 0;
        _scale = 1.0;
      });
    });
  }

  void _setupComposedGestures() {
    // Create a composed gesture for double-tap + drag
    _coordinator.composeGestures(
      types: [GestureType.doubleTap, GestureType.drag],
      callback: (gesture) {
        setState(() {
          _lastGesture = 'Double-Tap + Drag (Special Move)';
          // Perform special action
          _scale = 1.5;
        });
      },
    );
    
    // Create a gesture sequence for triple tap
    _coordinator.composeGestures(
      types: [GestureType.tap, GestureType.tap, GestureType.tap],
      callback: (gesture) {
        setState(() {
          _lastGesture = 'Triple Tap';
          // Show debug info
        });
        _showDebugInfo();
      },
    );
  }

  void _showContextMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Context Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _lastAction = 'Copy');
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('Paste'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _lastAction = 'Paste');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _lastAction = 'Delete');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDebugInfo() {
    final metrics = _coordinator.getMetrics();
    final customization = _coordinator.getCustomization();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event Count: ${metrics.eventCount}'),
            Text('Avg Processing: ${metrics.averageProcessingTime.toStringAsFixed(2)}μs'),
            Text('Max Processing: ${metrics.maxProcessingTime}μs'),
            const Divider(),
            Text('Drag Threshold: ${customization.dragThreshold}'),
            Text('Long Press: ${customization.longPressTimeout.inMilliseconds}ms'),
            Text('Double Tap: ${customization.doubleTapTimeout.inMilliseconds}ms'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _recordedGestures = _coordinator.stopRecording();
        _isRecording = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recorded ${_recordedGestures!.events.length} events'),
            action: SnackBarAction(
              label: 'Replay',
              onPressed: _replayRecording,
            ),
          ),
        );
      } else {
        _coordinator.startRecording();
        _isRecording = true;
      }
    });
  }

  void _replayRecording() async {
    if (_recordedGestures == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Replaying gestures...')),
    );
    
    await _coordinator.replayGestures(_recordedGestures!);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Replay complete')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture Coordinator Example'),
        actions: [
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
            onPressed: _toggleRecording,
            color: _isRecording ? Colors.red : null,
            tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showCustomizationDialog,
          ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          _coordinator.handleKeyEvent(event);
          return KeyEventResult.handled;
        },
        child: Stack(
          children: [
            // Background with snap points
            CustomPaint(
              painter: SnapPointPainter(
                snapPoints: [
                  const Offset(200, 400),
                  const Offset(400, 400),
                ],
              ),
              size: Size.infinite,
            ),
            
            // Draggable piece
            Positioned(
              left: _piecePosition.dx - 50,
              top: _piecePosition.dy - 50,
              child: GestureDetector(
                onTapDown: (details) {
                  _coordinator.handlePointerEvent(
                    PointerDownEvent(
                      position: details.globalPosition,
                      timeStamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
                    ),
                  );
                },
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(50.0, 50.0)
                    ..rotateZ(_rotation)
                    ..scale(_scale)
                    ..translate(-50.0, -50.0),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.gamepad,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Info overlay
            Positioned(
              left: 16,
              top: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last Gesture: $_lastGesture'),
                      Text('Last Action: $_lastAction'),
                      Text('Position: (${_piecePosition.dx.toInt()}, ${_piecePosition.dy.toInt()})'),
                      Text('Rotation: ${(_rotation * 180 / 3.14159).toInt()}°'),
                      Text('Scale: ${_scale.toStringAsFixed(2)}x'),
                      if (_isRecording)
                        const Text(
                          'Recording...',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Instructions
            Positioned(
              right: 16,
              top: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('• Tap: Single tap on piece'),
                      Text('• Double Tap: Reset scale'),
                      Text('• Long Press: Context menu'),
                      Text('• Drag: Move piece'),
                      Text('• Pinch: Scale piece'),
                      Text('• Rotate: Two-finger rotate'),
                      Text('• Arrow Keys: Move piece'),
                      Text('• Q/E: Rotate piece'),
                      Text('• Space: Select'),
                      Text('• Ctrl+Z: Undo (reset)'),
                      Text('• Triple Tap: Debug info'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomizationDialog() {
    final customization = _coordinator.getCustomization();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gesture Customization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Enable Tap'),
              value: customization.enabledGestures[GestureType.tap] ?? true,
              onChanged: (value) {
                _coordinator.setGestureEnabled(GestureType.tap, value);
                Navigator.pop(context);
                _showCustomizationDialog();
              },
            ),
            SwitchListTile(
              title: const Text('Enable Drag'),
              value: customization.enabledGestures[GestureType.drag] ?? true,
              onChanged: (value) {
                _coordinator.setGestureEnabled(GestureType.drag, value);
                Navigator.pop(context);
                _showCustomizationDialog();
              },
            ),
            SwitchListTile(
              title: const Text('Enable Scale'),
              value: customization.enabledGestures[GestureType.scale] ?? true,
              onChanged: (value) {
                _coordinator.setGestureEnabled(GestureType.scale, value);
                Navigator.pop(context);
                _showCustomizationDialog();
              },
            ),
            SwitchListTile(
              title: const Text('Debug Mode'),
              value: false,
              onChanged: (value) {
                _coordinator.setDebugMode(value);
                Navigator.pop(context);
                _showCustomizationDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tapRecognizer.dispose();
    _doubleTapRecognizer.dispose();
    _longPressRecognizer.dispose();
    _panRecognizer.dispose();
    _scaleRecognizer.dispose();
    _magneticRecognizer.dispose();
    _coordinator.dispose();
    super.dispose();
  }
}

/// Custom painter for visualizing snap points.
class SnapPointPainter extends CustomPainter {
  final List<Offset> snapPoints;

  SnapPointPainter({required this.snapPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final point in snapPoints) {
      // Draw outer ring
      paint.color = Colors.purple.withOpacity(0.3);
      canvas.drawCircle(point, 50, paint);
      
      // Draw inner circle
      paint.color = Colors.purple.withOpacity(0.5);
      canvas.drawCircle(point, 20, paint);
      
      // Draw center dot
      paint.style = PaintingStyle.fill;
      paint.color = Colors.purple;
      canvas.drawCircle(point, 5, paint);
      paint.style = PaintingStyle.stroke;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
