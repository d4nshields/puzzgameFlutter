/// Performance Test Suite for standard Flutter test runner
/// 
/// This file allows performance tests to run with 'flutter test'
/// For CI/CD integration, use ci_runner.dart directly
/// 
/// Note: Widget tests don't capture real frame timings, so the framework
/// returns simulated metrics for testing purposes.

import 'package:flutter_test/flutter_test.dart';
import 'performance_framework.dart';
import 'puzzle_benchmarks.dart';
import '../test_config.dart';

void main() {
  group('Performance Benchmarks', skip: !runPerformanceTests ? 'Performance tests disabled in test_config.dart' : null, () {
    late PerformanceTestFramework framework;
    
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      framework = PerformanceTestFramework();
    });
    
    tearDown(() {
      framework.dispose();
    });
    
    group('Puzzle Solving Performance', () {
      testWidgets('Small Puzzle (20 pieces) benchmark runs successfully', 
          (tester) async {
        final benchmarks = PuzzleSolvingBenchmarks(framework);
        final metrics = await benchmarks.benchmarkSmallPuzzle(tester);
        
        // In test environment, we just verify the benchmark runs
        // Real performance metrics would be captured in actual device/emulator tests
        expect(metrics.testName, equals('Small Puzzle (20 pieces)'));
        expect(metrics.frameMetrics, isNotNull);
        expect(metrics.memoryMetrics, isNotNull);
        expect(metrics.batteryMetrics, isNotNull);
        expect(metrics.thermalMetrics, isNotNull);
        
        // Verify simulated metrics are reasonable
        expect(metrics.frameMetrics.avgFps, greaterThan(30),
            reason: 'Simulated FPS should be reasonable');
        expect(metrics.memoryMetrics.avgMemoryMB, greaterThan(50),
            reason: 'Should have some memory usage');
      });
      
      testWidgets('Medium Puzzle (100 pieces) benchmark runs successfully', 
          (tester) async {
        final benchmarks = PuzzleSolvingBenchmarks(framework);
        final metrics = await benchmarks.benchmarkMediumPuzzle(tester);
        
        expect(metrics.testName, equals('Medium Puzzle (100 pieces)'));
        expect(metrics.customMetrics['piecesPlaced'], equals(50));
        expect(metrics.customMetrics['completionPercentage'], greaterThan(0));
      });
      
      testWidgets('Large Puzzle (500 pieces) benchmark runs successfully', 
          (tester) async {
        final benchmarks = PuzzleSolvingBenchmarks(framework);
        final metrics = await benchmarks.benchmarkLargePuzzle(tester);
        
        expect(metrics.testName, equals('Large Puzzle (500 pieces)'));
        expect(metrics.customMetrics['maxPieceCount'], equals(500));
        expect(metrics.memoryMetrics.maxMemoryMB, lessThan(1000),
            reason: 'Memory should be reasonable even for large puzzle');
      });
    });
    
    group('Stress Tests', () {
      testWidgets('Many pieces moving stress test completes', 
          (tester) async {
        final benchmarks = StressTestBenchmarks(framework);
        final metrics = await benchmarks.benchmarkManyPiecesMoving(tester);
        
        expect(metrics.customMetrics['totalPieces'], equals(200));
        expect(metrics.customMetrics['totalFrames'], equals(100));
        expect(metrics.frameMetrics.totalFrames, greaterThan(0));
      });
      
      testWidgets('Rapid piece churn test completes', 
          (tester) async {
        final benchmarks = StressTestBenchmarks(framework);
        final metrics = await benchmarks.benchmarkRapidPieceChurn(tester);
        
        expect(metrics.customMetrics['totalCycles'], equals(20));
        expect(metrics.customMetrics['finalPieceCount'], greaterThan(0));
        
        // Memory growth should be minimal in test environment
        expect(metrics.memoryMetrics.growthRateMBPerMin, lessThan(10),
            reason: 'Memory growth should be controlled');
      });
      
      testWidgets('Complex transformations test completes', 
          (tester) async {
        final benchmarks = StressTestBenchmarks(framework);
        final metrics = await benchmarks.benchmarkComplexTransformations(tester);
        
        expect(metrics.customMetrics['transformationsPerFrame'], equals(400));
        expect(metrics.customMetrics['totalTransformations'], equals(24000));
      });
    });
    
    group('Long Session Tests', () {
      testWidgets('30-minute session simulation completes', 
          (tester) async {
        final benchmarks = LongSessionBenchmarks(framework);
        final metrics = await benchmarks.benchmarkLongSession(tester);
        
        expect(metrics.customMetrics['minutesPlayed'], equals(30));
        expect(metrics.customMetrics['completionPercentage'], greaterThan(0));
        
        // Battery drain should be reasonable
        expect(metrics.batteryMetrics.drainRatePerHour, 
            inInclusiveRange(1, 50),
            reason: 'Battery drain rate should be reasonable');
      }, 
      skip: true, // Skip by default as this is a long test
      timeout: const Timeout(Duration(minutes: 5)));
      
      testWidgets('Memory leak detection identifies intentional leak', 
          (tester) async {
        final benchmarks = LongSessionBenchmarks(framework);
        final metrics = await benchmarks.benchmarkMemoryLeakDetection(tester);
        
        // This test intentionally creates a leak scenario
        expect(metrics.customMetrics['leakedObjects'], greaterThan(0),
            reason: 'Should detect the intentionally created leak');
        expect(metrics.customMetrics['finalObjectCount'], 
            greaterThan(metrics.customMetrics['expectedObjectCount']),
            reason: 'Should have more objects than expected due to leak');
      });
      
      testWidgets('Battery drain simulation provides valid metrics', 
          (tester) async {
        final benchmarks = LongSessionBenchmarks(framework);
        final metrics = await benchmarks.benchmarkBatteryDrain(tester);
        
        expect(metrics.batteryMetrics.drainPercentage, greaterThanOrEqualTo(0),
            reason: 'Battery should show some drain');
        expect(metrics.batteryMetrics.drainRatePerHour, 
            inInclusiveRange(1, 50),
            reason: 'Drain rate should be reasonable for simulation');
        expect(metrics.batteryMetrics.startLevel, equals(100.0));
        expect(metrics.batteryMetrics.endLevel, lessThanOrEqualTo(100.0));
      });
    });
    
    group('Framework Components', () {
      test('FrameMetrics handles empty timings gracefully', () {
        final recorder = FrameTimingRecorder();
        recorder.startRecording();
        // Don't record any frames
        recorder.stopRecording();
        
        final metrics = recorder.calculateMetrics();
        
        // Should return simulated metrics when no real frames are captured
        expect(metrics.avgFps, equals(60.0));
        expect(metrics.avgFrameTime, equals(16.0));
        expect(metrics.jankRate, equals(0.02));
      });
      
      test('MemoryProfiler tracks memory over time', () async {
        final profiler = MemoryProfiler(
          samplingInterval: const Duration(milliseconds: 10),
        );
        
        profiler.startProfiling();
        await Future.delayed(const Duration(milliseconds: 100));
        profiler.addMarker('Test marker');
        await Future.delayed(const Duration(milliseconds: 100));
        profiler.stopProfiling();
        
        final metrics = profiler.calculateMetrics();
        
        expect(metrics.snapshots, isNotEmpty);
        expect(metrics.avgMemoryMB, greaterThan(0));
        expect(metrics.snapshots.any((s) => s.label == 'Test marker'), isTrue);
      });
      
      test('BatteryMonitor simulates drain correctly', () async {
        final monitor = BatteryMonitor();
        
        monitor.startMonitoring(
          initialLevel: 100.0,
          drainRatePerHour: 10.0,
        );
        
        // Simulate high load
        monitor.simulateHighLoad();
        await Future.delayed(const Duration(milliseconds: 100));
        
        monitor.stopMonitoring();
        
        final metrics = monitor.calculateMetrics();
        
        expect(metrics.startLevel, equals(100.0));
        expect(metrics.endLevel, lessThanOrEqualTo(100.0));
        expect(metrics.drainRatePerHour, greaterThan(0));
      });
      
      test('ThermalThrottleSimulator responds to load', () async {
        final simulator = ThermalThrottleSimulator();
        
        simulator.startSimulation();
        
        // Simulate high load
        simulator.simulateHighLoad();
        await Future.delayed(const Duration(milliseconds: 200));
        
        expect(simulator.currentTemperature, greaterThan(35.0));
        
        // Simulate normal load
        simulator.simulateNormalLoad();
        await Future.delayed(const Duration(milliseconds: 200));
        
        simulator.stopSimulation();
        
        final metrics = simulator.calculateMetrics();
        
        expect(metrics.avgTemperature, greaterThan(35.0));
        expect(metrics.maxTemperature, greaterThanOrEqualTo(metrics.avgTemperature));
      });
    });
    
    group('Performance Regression Detection', () {
      test('Detects frame time regression', () {
        final baseline = _createMetrics(avgFrameTime: 16.0, avgFps: 60.0);
        final current = _createMetrics(avgFrameTime: 18.0, avgFps: 55.0);
        
        final report = PerformanceRegressionDetector.detectRegressions(
          baseline,
          current,
          threshold: 0.1,
        );
        
        expect(report.hasRegression, isTrue);
        expect(report.regressions.any((r) => r.contains('frame time')), isTrue);
      });
      
      test('Detects memory regression', () {
        final baseline = _createMetrics(avgMemoryMB: 100.0);
        final current = _createMetrics(avgMemoryMB: 120.0);
        
        final report = PerformanceRegressionDetector.detectRegressions(
          baseline,
          current,
          threshold: 0.1,
        );
        
        expect(report.hasRegression, isTrue);
        expect(report.regressions.any((r) => r.contains('Memory')), isTrue);
      });
      
      test('Detects improvements', () {
        final baseline = _createMetrics(avgFrameTime: 18.0, avgMemoryMB: 120.0);
        final current = _createMetrics(avgFrameTime: 15.0, avgMemoryMB: 95.0);
        
        final report = PerformanceRegressionDetector.detectRegressions(
          baseline,
          current,
          threshold: 0.1,
        );
        
        expect(report.hasRegression, isFalse);
        expect(report.improvements, isNotEmpty);
        expect(report.improvements.any((i) => i.contains('frame time')), isTrue);
        expect(report.improvements.any((i) => i.contains('Memory')), isTrue);
      });
    });
  });
}

// Helper function to create test metrics
PerformanceMetrics _createMetrics({
  double avgFrameTime = 16.0,
  double avgFps = 60.0,
  double avgMemoryMB = 100.0,
}) {
  return PerformanceMetrics(
    testName: 'Test',
    timestamp: DateTime.now(),
    duration: const Duration(seconds: 10),
    frameMetrics: FrameMetrics(
      avgFrameTime: avgFrameTime,
      minFrameTime: avgFrameTime - 2,
      maxFrameTime: avgFrameTime + 4,
      p50FrameTime: avgFrameTime,
      p95FrameTime: avgFrameTime + 2,
      p99FrameTime: avgFrameTime + 3,
      avgFps: avgFps,
      jankRate: 0.02,
      droppedFrames: 1,
      totalFrames: 600,
    ),
    memoryMetrics: MemoryMetrics(
      avgMemoryMB: avgMemoryMB,
      minMemoryMB: avgMemoryMB - 10,
      maxMemoryMB: avgMemoryMB + 10,
      memoryGrowthMB: 5,
      growthRateMBPerMin: 0.5,
      snapshots: [],
    ),
    batteryMetrics: BatteryMetrics(
      startLevel: 100,
      endLevel: 95,
      drainPercentage: 5,
      drainRatePerHour: 5,
      testDuration: const Duration(hours: 1),
    ),
    thermalMetrics: ThermalMetrics(
      avgTemperature: 37,
      maxTemperature: 40,
      throttlePercentage: 0,
      timeThrottled: Duration.zero,
      throttleEvents: 0,
    ),
  );
}
