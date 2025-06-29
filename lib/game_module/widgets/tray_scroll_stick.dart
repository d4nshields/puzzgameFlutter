// Accessible Tray Scroll Stick Widget
// File: lib/game_module/widgets/tray_scroll_stick.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Mini joystick-style scroll control for pieces tray navigation
/// Designed for users with motor difficulties - simple up/down movement
class TrayScrollStick extends StatefulWidget {
  const TrayScrollStick({
    super.key,
    required this.scrollController,
    required this.itemCount,
    required this.visibleItemCount,
    this.stickWidth = 30.0,
    this.stickHeight = 80.0,
    this.onScrollChanged,
  });

  final ScrollController scrollController;
  final int itemCount;
  final int visibleItemCount;
  final double stickWidth;
  final double stickHeight;
  final VoidCallback? onScrollChanged;

  @override
  State<TrayScrollStick> createState() => _TrayScrollStickState();
}

class _TrayScrollStickState extends State<TrayScrollStick>
    with TickerProviderStateMixin {
  late AnimationController _highlightController;
  late AnimationController _stickController;
  
  // Joystick state
  StickPosition _currentPosition = StickPosition.center;
  Timer? _scrollTimer;
  bool _isInteracting = false;
  
  // Accessibility and motor control settings
  static const double _deadZone = 0.3; // Center dead zone for stability
  static const int _scrollRepeatMs = 200; // Slower repeat for smooth scrolling
  static const double _scrollAmount = 20.0; // Smaller scroll steps for precision
  
  @override
  void initState() {
    super.initState();
    
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _stickController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _scrollTimer?.cancel();
    _highlightController.dispose();
    _stickController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Don't show stick if all items are visible
    if (widget.itemCount <= widget.visibleItemCount) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: widget.stickWidth,
      height: widget.stickHeight,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track with high contrast
          _buildStickTrack(),
          
          // Movable stick indicator
          _buildStickIndicator(),
          
          // Touch/drag detector
          _buildGestureDetector(),
          
          // Accessibility labels
          _buildAccessibilityLabel(),
        ],
      ),
    );
  }
  
  Widget _buildStickTrack() {
    return AnimatedBuilder(
      animation: _highlightController,
      builder: (context, child) {
        final highlightValue = _highlightController.value;
        return Container(
          width: widget.stickWidth,
          height: widget.stickHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.stickWidth / 2),
            color: Colors.white,
            border: Border.all(
              color: Color.lerp(
                Colors.grey[400]!,
                Colors.blue[600]!,
                highlightValue,
              )!,
              width: 2 + (highlightValue * 1), // Thicker when active
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1 + (highlightValue * 0.1)),
                blurRadius: 2 + (highlightValue * 2),
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Up arrow indicator
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _highlightController,
                  builder: (context, child) {
                    final isUpActive = _currentPosition == StickPosition.up;
                    return Icon(
                      Icons.keyboard_arrow_up,
                      size: 16,
                      color: isUpActive 
                          ? Colors.blue[700]!
                          : Colors.grey[400]!.withOpacity(0.6),
                    );
                  },
                ),
              ),
              
              // Down arrow indicator  
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _highlightController,
                  builder: (context, child) {
                    final isDownActive = _currentPosition == StickPosition.down;
                    return Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDownActive 
                          ? Colors.blue[700]!
                          : Colors.grey[400]!.withOpacity(0.6),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStickIndicator() {
    return AnimatedBuilder(
      animation: _stickController,
      builder: (context, child) {
        // Calculate stick position based on current state
        double offsetY = 0;
        switch (_currentPosition) {
          case StickPosition.up:
            offsetY = -widget.stickHeight * 0.25;
            break;
          case StickPosition.down:
            offsetY = widget.stickHeight * 0.25;
            break;
          case StickPosition.center:
            offsetY = 0;
            break;
        }
        
        return Transform.translate(
          offset: Offset(0, offsetY * _stickController.value),
          child: AnimatedBuilder(
            animation: _highlightController,
            builder: (context, child) {
              final highlightValue = _highlightController.value;
              final isActive = _currentPosition != StickPosition.center;
              
              return Container(
                width: widget.stickWidth - 6,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular((widget.stickWidth - 6) / 2),
                  color: isActive 
                      ? Colors.blue[600]!
                      : Color.lerp(
                          Colors.grey[300]!,
                          Colors.blue[400]!,
                          highlightValue,
                        ),
                  border: Border.all(
                    color: isActive 
                        ? Colors.blue[800]!
                        : Colors.grey[500]!,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? Colors.blue : Colors.black)
                          .withOpacity(0.2),
                      blurRadius: isActive ? 4 : 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Up triangle
                      CustomPaint(
                        size: const Size(10, 6),
                        painter: _TrianglePainter(
                          color: isActive ? Colors.white : Colors.grey[600]!,
                          direction: TriangleDirection.up,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Down triangle
                      CustomPaint(
                        size: const Size(10, 6),
                        painter: _TrianglePainter(
                          color: isActive ? Colors.white : Colors.grey[600]!,
                          direction: TriangleDirection.down,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildGestureDetector() {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: _onTap,
      child: Container(
        width: widget.stickWidth,
        height: widget.stickHeight,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
      ),
    );
  }
  
  Widget _buildAccessibilityLabel() {
    // Use static values to avoid scroll position access during initialization
    return Semantics(
      label: 'Scroll control for pieces tray',
      hint: 'Push up to scroll up, push down to scroll down, or use increase/decrease',
      value: 'Ready',
      increasedValue: 'Scrolled down more',
      decreasedValue: 'Scrolled up more',
      onIncrease: _scrollDown,
      onDecrease: _scrollUp,
      child: const SizedBox(),
    );
  }
  
  void _onPanStart(DragStartDetails details) {
    _isInteracting = true;
    _highlightController.forward();
    
    // Calculate initial position
    _updateStickPosition(details.localPosition);
    
    // Haptic feedback for interaction start
    HapticFeedback.lightImpact();
  }
  
  void _onPanUpdate(DragUpdateDetails details) {
    _updateStickPosition(details.localPosition);
  }
  
  void _onPanEnd(DragEndDetails details) {
    _isInteracting = false;
    _setStickPosition(StickPosition.center);
    _highlightController.reverse();
    _stopScrolling();
    
    // Final haptic feedback
    HapticFeedback.lightImpact();
  }
  
  void _onTap() {
    // Provide alternative tap interaction - scroll down once
    HapticFeedback.lightImpact();
    _scrollDown();
  }
  
  void _updateStickPosition(Offset localPosition) {
    // Calculate relative position within the stick track
    final relativeY = (localPosition.dy - widget.stickHeight / 2) / (widget.stickHeight / 2);
    
    StickPosition newPosition;
    if (relativeY < -_deadZone) {
      newPosition = StickPosition.up;
    } else if (relativeY > _deadZone) {
      newPosition = StickPosition.down;
    } else {
      newPosition = StickPosition.center;
    }
    
    _setStickPosition(newPosition);
  }
  
  void _setStickPosition(StickPosition position) {
    if (_currentPosition != position) {
      setState(() {
        _currentPosition = position;
      });
      
      _stickController.reset();
      _stickController.forward();
      
      // Start/stop scrolling based on position
      if (position == StickPosition.center) {
        _stopScrolling();
      } else {
        _startScrolling(position);
      }
      
      // Haptic feedback for position changes
      if (position != StickPosition.center) {
        HapticFeedback.selectionClick();
      }
    }
  }
  
  void _startScrolling(StickPosition direction) {
    _stopScrolling(); // Clear any existing timer
    
    // Immediate scroll
    if (direction == StickPosition.up) {
      _scrollUp();
    } else if (direction == StickPosition.down) {
      _scrollDown();
    }
    
    // Continuous scrolling while held
    _scrollTimer = Timer.periodic(
      const Duration(milliseconds: _scrollRepeatMs),
      (timer) {
        if (direction == StickPosition.up) {
          _scrollUp();
        } else if (direction == StickPosition.down) {
          _scrollDown();
        }
      },
    );
  }
  
  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }
  
  String _getScrollPosition() {
    if (!widget.scrollController.hasClients) return 'Beginning';
    
    try {
      final position = widget.scrollController.position;
      final maxScroll = position.maxScrollExtent;
      final currentScroll = position.pixels;
      
      if (maxScroll == 0) return 'All items visible';
      
      final percentage = ((currentScroll / maxScroll) * 100).round();
      return 'Scrolled $percentage%';
    } catch (e) {
      return 'Loading';
    }
  }
  
  void _scrollUp() {
    if (!widget.scrollController.hasClients) return;
    
    final currentOffset = widget.scrollController.position.pixels;
    final newOffset = (currentOffset - _scrollAmount).clamp(0.0, double.infinity);
    
    widget.scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    
    if (_currentPosition == StickPosition.center) {
      HapticFeedback.selectionClick();
    }
    widget.onScrollChanged?.call();
  }
  
  void _scrollDown() {
    if (!widget.scrollController.hasClients) return;
    
    final maxScrollExtent = widget.scrollController.position.maxScrollExtent;
    final currentOffset = widget.scrollController.position.pixels;
    final newOffset = (currentOffset + _scrollAmount).clamp(0.0, maxScrollExtent);
    
    widget.scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    
    if (_currentPosition == StickPosition.center) {
      HapticFeedback.selectionClick();
    }
    widget.onScrollChanged?.call();
  }
}

/// Joystick position states
enum StickPosition {
  up,
  center,
  down,
}

/// Triangle direction for the stick indicator
enum TriangleDirection {
  up,
  down,
}

/// Custom painter for drawing directional triangles
class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({
    required this.color,
    required this.direction,
  });
  
  final Color color;
  final TriangleDirection direction;
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    
    if (direction == TriangleDirection.up) {
      // Up-pointing triangle
      path.moveTo(size.width / 2, 0); // Top center
      path.lineTo(0, size.height); // Bottom left
      path.lineTo(size.width, size.height); // Bottom right
      path.close();
    } else {
      // Down-pointing triangle
      path.moveTo(0, 0); // Top left
      path.lineTo(size.width, 0); // Top right
      path.lineTo(size.width / 2, size.height); // Bottom center
      path.close();
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.direction != direction;
  }
}
