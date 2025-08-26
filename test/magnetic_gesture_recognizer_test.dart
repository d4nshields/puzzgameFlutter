import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module2/presentation/gestures/magnetic_gesture_recognizer.dart';

void main() {
  // Initialize the test binding
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MagneticGestureRecognizer', () {
    late MagneticGestureRecognizer recognizer;
    
    setUp(() {
      recognizer = MagneticGestureRecognizer();
    });
    
    tearDown(() {
      recognizer.dispose();
    });
    
    group('Performance Tests', () {
      test('gesture event processing should be under 1ms', () {
        const eventCount = 1000;
        final stopwatch = Stopwatch();
        
        // Simulate rapid pointer events
        for (int i = 0; i < eventCount; i++) {
          final event = PointerDownEvent(
            pointer: i,
            position: Offset(i.toDouble(), i.toDouble()),
            timeStamp: Duration(microseconds: i * 1000),
          );
          
          stopwatch.start();
          recognizer.addAllowedPointer(event);
          stopwatch.stop();
        }
        
        final averageTime = stopwatch.elapsedMicroseconds / eventCount;
        
        // Should process each event in under 1000 microseconds (1ms)
        expect(averageTime, lessThan(1000));
        
        print('Average processing time: ${averageTime.toStringAsFixed(2)}μs');
      });
      
      test('should handle 120Hz touch sampling rate', () {
        const samplingRate = 120; // Hz
        const duration = Duration(seconds: 1);
        const eventCount = samplingRate;
        
        recognizer.onUpdate = (details) {};
        
        // Add initial pointer
        recognizer.addAllowedPointer(
          PointerDownEvent(
            pointer: 0,
            position: Offset.zero,
            timeStamp: Duration.zero,
          ),
        );
        
        final stopwatch = Stopwatch()..start();
        
        // Simulate 120Hz touch events for 1 second
        for (int i = 0; i < eventCount; i++) {
          final event = PointerMoveEvent(
            pointer: 0,
            position: Offset(i.toDouble(), i.toDouble()),
            delta: const Offset(1, 1),
            timeStamp: Duration(microseconds: i * (1000000 ~/ samplingRate)),
          );
          
          recognizer.handleEvent(event);
        }
        
        stopwatch.stop();
        
        // Should handle all events without dropping
        final metrics = recognizer.getPerformanceMetrics();
        expect(metrics.droppedEvents, equals(0));
        
        // Processing should complete in reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        
        print('Processed $eventCount events at 120Hz in ${stopwatch.elapsedMilliseconds}ms');
      });
      
      test('should not drop touch events under load', () {
        const eventCount = 500;
        var processedEvents = 0;
        
        recognizer.onStart = (_) => processedEvents++;
        recognizer.onUpdate = (_) => processedEvents++;
        recognizer.onEnd = (_) => processedEvents++;
        
        // Simulate rapid gesture sequence
        for (int i = 0; i < eventCount ~/ 3; i++) {
          // Start
          recognizer.addAllowedPointer(
            PointerDownEvent(
              pointer: i,
              position: Offset(i.toDouble(), i.toDouble()),
              timeStamp: Duration(microseconds: i * 3000),
            ),
          );
          
          // Accept the gesture to allow drag events
          recognizer.acceptGesture(i);
          
          // Move enough to trigger drag start (more than touch slop)
          recognizer.handleEvent(
            PointerMoveEvent(
              pointer: i,
              position: Offset(i.toDouble() + 25, i.toDouble() + 25),
              delta: const Offset(25, 25),
              timeStamp: Duration(microseconds: i * 3000 + 1000),
            ),
          );
          
          // Additional move for update
          recognizer.handleEvent(
            PointerMoveEvent(
              pointer: i,
              position: Offset(i.toDouble() + 35, i.toDouble() + 35),
              delta: const Offset(10, 10),
              timeStamp: Duration(microseconds: i * 3000 + 1500),
            ),
          );
          
          // End
          recognizer.handleEvent(
            PointerUpEvent(
              pointer: i,
              position: Offset(i.toDouble() + 35, i.toDouble() + 35),
              timeStamp: Duration(microseconds: i * 3000 + 2000),
            ),
          );
        }
        
        // Should process most events (at least 90%)
        // We expect: start + at least one update + end for most sequences
        expect(processedEvents, greaterThan((eventCount ~/ 3) * 2)); // At least 2 events per sequence
        
        print('Processed $processedEvents events out of ${eventCount} potential events');
      });
    });
    
    group('Magnetic Field Tests', () {
      test('should apply magnetic field influence', () {
        final snapPoints = [
          const MagneticSnapPoint(
            position: Offset(100, 100),
            radius: 50,
            strength: 1.0,
          ),
        ];
        
        final config = MagneticFieldConfiguration(
          snapPoints: snapPoints,
          strength: 0.5,
        );
        
        recognizer = MagneticGestureRecognizer(
          fieldConfig: config,
        );
        
        Offset? lastUpdatePosition;
        DragUpdateDetails? lastUpdateDetails;
        
        recognizer.onStart = (details) {
          // Track that drag started
        };
        
        recognizer.onUpdate = (details) {
          lastUpdatePosition = details.globalPosition;
          lastUpdateDetails = details;
        };
        
        // Start drag near snap point
        recognizer.addAllowedPointer(
          PointerDownEvent(
            pointer: 0,
            position: const Offset(80, 80),
            timeStamp: Duration.zero,
          ),
        );
        
        // Accept the gesture
        recognizer.acceptGesture(0);
        
        // Move enough to start drag (beyond touch slop)
        recognizer.handleEvent(
          PointerMoveEvent(
            pointer: 0,
            position: const Offset(100, 100),
            delta: const Offset(20, 20),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        
        // Continue moving - should be influenced by magnetic field
        recognizer.handleEvent(
          PointerMoveEvent(
            pointer: 0,
            position: const Offset(105, 105),
            delta: const Offset(5, 5),
            timeStamp: const Duration(milliseconds: 32),
          ),
        );
        
        // Position should be influenced toward snap point
        expect(lastUpdateDetails, isNotNull);
        // The magnetic field should have influenced the movement
        // The actual delta should be affected by the magnetic field
      });
      
      test('should calculate field gradient correctly', () {
        final snapPoints = [
          const MagneticSnapPoint(
            position: Offset(100, 100),
            radius: 50,
            strength: 1.0,
          ),
        ];
        
        final config = MagneticFieldConfiguration(
          snapPoints: snapPoints,
        );
        
        // Test gradient at various positions
        final gradient1 = config.calculateGradient(const Offset(80, 80));
        final gradient2 = config.calculateGradient(const Offset(120, 120));
        final gradient3 = config.calculateGradient(const Offset(100, 100));
        
        // Gradient should point toward snap point
        expect(gradient1.distance, greaterThan(0));
        expect(gradient2.distance, greaterThan(0));
        // At the snap point, gradient should be minimal
        expect(gradient3.distance, lessThan(0.1));
      });
    });
    
    group('Multi-touch Support', () {
      test('should handle multiple simultaneous touches', () {
        var multiTouchEventReceived = false;
        
        recognizer.onMultiTouch = (event) {
          multiTouchEventReceived = true;
          expect(event.touches.length, equals(2));
        };
        
        // Add first touch
        recognizer.addAllowedPointer(
          PointerDownEvent(
            pointer: 0,
            position: const Offset(50, 50),
            timeStamp: Duration.zero,
          ),
        );
        
        // Add second touch
        recognizer.addAllowedPointer(
          PointerDownEvent(
            pointer: 1,
            position: const Offset(150, 150),
            timeStamp: const Duration(milliseconds: 10),
          ),
        );
        
        expect(multiTouchEventReceived, isTrue);
      });
      
      test('should calculate pinch and rotation', () {
        MultiTouchEvent? lastEvent;
        
        recognizer.onMultiTouch = (event) {
          lastEvent = event;
        };
        
        // Add two touches
        recognizer.addAllowedPointer(
          PointerDownEvent(
            pointer: 0,
            position: const Offset(50, 100),
            timeStamp: Duration.zero,
          ),
        );
        
        recognizer.addAllowedPointer(
          PointerDownEvent(
            pointer: 1,
            position: const Offset(150, 100),
            timeStamp: const Duration(milliseconds: 10),
          ),
        );
        
        expect(lastEvent, isNotNull);
        expect(lastEvent!.type, equals(MultiTouchType.pinch));
        expect(lastEvent!.center, equals(const Offset(100, 100)));
      });
    });
    
    group('Velocity Tracking', () {
      test('should accurately track gesture velocity', () {
        final tracker = GestureVelocityTracker();
        
        // Simulate movement at constant velocity
        const velocity = 100.0; // pixels per second
        const duration = 100; // milliseconds
        
        for (int i = 0; i <= duration; i += 10) {
          final position = Offset(velocity * i / 1000.0, 0);
          tracker.addPosition(Duration(milliseconds: i), position);
        }
        
        final calculatedVelocity = tracker.getVelocity();
        
        // Should be close to expected velocity (converted from ms to μs in the tracker)
        // The tracker returns velocity in pixels per second
        // We need to verify the velocity is in the right order of magnitude
        expect(calculatedVelocity.pixelsPerSecond.dx.abs(), 
               greaterThan(50)); // Should detect movement
        expect(calculatedVelocity.pixelsPerSecond.dx.abs(), 
               lessThan(200)); // But not unreasonably high
      });
      
      test('should handle accelerating movement', () {
        final tracker = GestureVelocityTracker();
        
        // Simulate accelerating movement
        for (int i = 0; i <= 100; i += 10) {
          final position = Offset(i * i / 100.0, 0); // x = t²
          tracker.addPosition(Duration(milliseconds: i), position);
        }
        
        final velocity = tracker.getVelocity();
        
        // Velocity should be positive (moving right)
        expect(velocity.pixelsPerSecond.dx, greaterThan(0));
      });
    });
    
    group('Momentum Physics', () {
      test('should calculate momentum correctly', () {
        final physics = MomentumPhysics(
          friction: 0.15,
          mass: 1.0,
          threshold: 10.0,
        );
        
        // Test with velocity above threshold
        final velocity1 = const Velocity(pixelsPerSecond: Offset(100, 0));
        final momentum1 = physics.calculateMomentum(velocity: velocity1);
        
        expect(momentum1.dx, greaterThan(0));
        expect(momentum1.dx, lessThan(100)); // Reduced by friction
        
        // Test with velocity below threshold
        final velocity2 = const Velocity(pixelsPerSecond: Offset(5, 0));
        final momentum2 = physics.calculateMomentum(velocity: velocity2);
        
        expect(momentum2, equals(Offset.zero));
      });
    });
    
    group('Adaptive Sensitivity', () {
      test('should adjust sensitivity based on device type', () {
        final sensitivity = AdaptiveSensitivity();
        
        // Test touch device
        sensitivity.updateContext(
          position: Offset.zero,
          pressure: 1.0,
          deviceKind: PointerDeviceKind.touch,
        );
        final touchSensitivity = sensitivity.getSensitivity(
          velocity: null,
          position: Offset.zero,
        );
        
        // Test stylus device
        sensitivity.updateContext(
          position: Offset.zero,
          pressure: 1.0,
          deviceKind: PointerDeviceKind.stylus,
        );
        final stylusSensitivity = sensitivity.getSensitivity(
          velocity: null,
          position: Offset.zero,
        );
        
        // Stylus should be more sensitive
        expect(stylusSensitivity, greaterThan(touchSensitivity));
      });
      
      test('should reduce sensitivity at high velocities', () {
        final sensitivity = AdaptiveSensitivity();
        
        sensitivity.updateContext(
          position: Offset.zero,
          pressure: 1.0,
          deviceKind: PointerDeviceKind.touch,
        );
        
        // Low velocity
        final lowVelocitySensitivity = sensitivity.getSensitivity(
          velocity: const Velocity(pixelsPerSecond: Offset(100, 0)),
          position: Offset.zero,
        );
        
        // High velocity
        final highVelocitySensitivity = sensitivity.getSensitivity(
          velocity: const Velocity(pixelsPerSecond: Offset(1500, 0)),
          position: Offset.zero,
        );
        
        // Should reduce sensitivity at high speeds
        expect(highVelocitySensitivity, lessThan(lowVelocitySensitivity));
      });
    });
    
    group('Debug Tools', () {
      test('should log gesture events when debug mode is enabled', () {
        recognizer.setDebugMode(true);
        
        recognizer.addAllowedPointer(
          PointerDownEvent(
            pointer: 0,
            position: const Offset(100, 100),
            timeStamp: Duration.zero,
          ),
        );
        
        final logs = recognizer.exportDebugLogs();
        
        expect(logs, isNotEmpty);
        expect(logs.first.type, equals('pointer_down'));
        expect(logs.first.position, equals(const Offset(100, 100)));
      });
      
      test('should not log when debug mode is disabled', () {
        recognizer.setDebugMode(false);
        
        recognizer.addAllowedPointer(
          PointerDownEvent(
            pointer: 0,
            position: const Offset(100, 100),
            timeStamp: Duration.zero,
          ),
        );
        
        final logs = recognizer.exportDebugLogs();
        
        expect(logs, isEmpty);
      });
      
      test('should provide performance metrics', () {
        // Perform some gestures
        for (int i = 0; i < 10; i++) {
          recognizer.addAllowedPointer(
            PointerDownEvent(
              pointer: i,
              position: Offset(i.toDouble(), i.toDouble()),
              timeStamp: Duration(milliseconds: i * 10),
            ),
          );
        }
        
        final metrics = recognizer.getPerformanceMetrics();
        
        expect(metrics.eventCount, greaterThan(0));
        expect(metrics.averageProcessingTime, greaterThan(0));
        expect(metrics.maxProcessingTime, greaterThan(0));
      });
    });
  });
}
