# Performance Testing Framework

## Overview

The Puzzle Nook Performance Testing Framework provides comprehensive benchmarking and monitoring capabilities for ensuring optimal game performance across different scenarios and platforms.

## Features

### 🎯 Core Components

1. **FrameTimingRecorder**
   - Records frame timing information
   - Calculates FPS, jank rate, and frame time percentiles
   - Detects dropped frames

2. **MemoryProfiler**
   - Monitors memory usage over time
   - Detects memory leaks
   - Tracks memory growth patterns

3. **BatteryMonitor**
   - Simulates battery consumption
   - Estimates drain rate per hour
   - Supports high/normal load scenarios

4. **ThermalThrottleSimulator**
   - Simulates device thermal behavior
   - Tracks throttling events
   - Provides performance multiplier feedback

### 📊 Benchmark Scenarios

#### Puzzle Solving Benchmarks
- **Small Puzzle (20 pieces)**: Quick performance validation
- **Medium Puzzle (100 pieces)**: Standard gameplay scenario
- **Large Puzzle (500 pieces)**: High-load scenario with thermal testing

#### Stress Tests
- **Many Pieces Moving**: 200 pieces animated simultaneously
- **Rapid Piece Churn**: Memory allocation/deallocation stress
- **Complex Transformations**: Coordinate system performance

#### Long Session Tests
- **30-Minute Session**: Extended gameplay simulation
- **Memory Leak Detection**: Identifies memory retention issues
- **Battery Drain Simulation**: Power consumption analysis

## Important Note about Test Execution

### Two Different Test Files:

1. **`performance_test.dart`** - For use with `flutter test`
   - Standard Flutter widget tests
   - Compatible with Flutter test runner
   - Used for local development
   - Does NOT call `exit()`

2. **`ci_runner.dart`** - For CI/CD pipelines
   - Standalone Dart application
   - Must be run with `dart` command, NOT `flutter test`
   - Calls `exit()` with appropriate exit codes
   - Generates comprehensive reports

### Correct Usage:

```bash
# For local development (uses performance_test.dart)
./run_performance_tests.sh

# For CI/CD pipeline (uses ci_runner.dart)
./run_performance_tests.sh --ci-runner
# OR directly:
dart test/performance/ci_runner.dart

# WRONG - Will fail!
flutter test test/performance/ci_runner.dart  # ❌ Don't do this!
```

### Running Tests Locally

```bash
# Run standard test suite
./run_performance_tests.sh

# Run quick tests only
./run_performance_tests.sh --quick

# Run full test suite including long sessions
./run_performance_tests.sh --full

# Create a new performance baseline
./run_performance_tests.sh --baseline

# Run in CI mode with strict thresholds
./run_performance_tests.sh --ci
```

### Running Individual Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'test/performance/performance_framework.dart';
import 'test/performance/puzzle_benchmarks.dart';

void main() {
  testWidgets('Custom performance test', (tester) async {
    final framework = PerformanceTestFramework();
    
    // Start recording
    framework.startTest('My Custom Test');
    
    // Your test code here
    await tester.pumpWidget(YourWidget());
    
    // Simulate interactions
    for (int i = 0; i < 100; i++) {
      await tester.pump(Duration(milliseconds: 16));
    }
    
    // Stop and get metrics
    final metrics = framework.stopTest();
    
    // Check performance
    expect(metrics.frameMetrics.avgFps, greaterThan(55));
    expect(metrics.memoryMetrics.hasMemoryLeak(1.0), isFalse);
    
    framework.dispose();
  });
}
```

## Performance Targets

### Frame Performance
- **Average FPS**: ≥ 58
- **P95 Frame Time**: ≤ 20ms
- **Jank Rate**: ≤ 5%
- **Average Frame Time**: ≤ 16.67ms

### Memory Performance
- **Memory Growth**: < 1MB/minute
- **Peak Memory**: < 500MB
- **No memory leaks detected**

### Battery Performance
- **Normal Play**: < 5%/hour
- **Heavy Play**: < 10%/hour

### Thermal Performance
- **Average Temperature**: < 40°C
- **Throttle Events**: Minimal
- **Performance Multiplier**: > 0.8

## CI/CD Integration

### GitHub Actions

The framework includes a complete GitHub Actions workflow that:

1. Runs on every push to main/develop
2. Runs on pull requests
3. Runs daily performance regression tests
4. Generates performance reports
5. Comments on PRs with results
6. Detects performance regressions

### Jenkins Integration

```groovy
pipeline {
  agent any
  
  stages {
    stage('Performance Tests') {
      steps {
        sh 'flutter test test/performance/ci_runner.dart'
      }
    }
    
    stage('Publish Results') {
      steps {
        publishHTML([
          reportDir: 'test_results/performance',
          reportFiles: '*.md',
          reportName: 'Performance Report'
        ])
      }
    }
  }
  
  post {
    always {
      archiveArtifacts artifacts: 'test_results/performance/**/*'
    }
  }
}
```

## Report Generation

### JSON Reports

Detailed metrics in JSON format for programmatic analysis:

```json
{
  "version": "1.0.0",
  "generated": "2024-01-15T10:30:00Z",
  "metrics": [
    {
      "testName": "Small Puzzle (20 pieces)",
      "frameMetrics": {
        "avgFps": 59.8,
        "avgFrameTime": 16.5,
        "jankRate": 0.02
      }
    }
  ]
}
```

### Markdown Reports

Human-readable reports with detailed analysis:

```markdown
# Performance Test Report

## Test Results

### Small Puzzle (20 pieces)
- Average FPS: 59.8
- Frame Time: 16.5ms
- Memory Usage: 120MB
```

### CI Summary

Simplified summary for CI/CD systems:

```json
{
  "status": "completed",
  "passed": 8,
  "failed": 2,
  "passRate": 0.8
}
```

## Regression Detection

The framework automatically detects performance regressions by:

1. Comparing current metrics with baseline
2. Using configurable thresholds (default 10%)
3. Identifying both regressions and improvements
4. Generating detailed comparison reports

### Setting Baselines

```bash
# Create initial baseline
./run_performance_tests.sh --baseline

# Update baseline after improvements
flutter test test/performance/ci_runner.dart
cp test_results/performance/*.json performance_baseline.json
```

## Troubleshooting

### Common Issues

1. **Tests timing out**
   - Increase timeout: `--timeout 15m`
   - Run fewer tests: `--quick`

2. **Memory measurements inaccurate**
   - Run in release mode for accurate measurements
   - Ensure no other apps are running

3. **Frame timing not recorded**
   - Ensure `TestWidgetsFlutterBinding.ensureInitialized()` is called
   - Check that animations are actually running

### Debug Mode

Enable detailed logging:

```dart
final framework = PerformanceTestFramework();
framework.enableDebugLogging = true;
```

## Best Practices

1. **Run tests in consistent environment**
   - Close other applications
   - Use consistent device/emulator
   - Disable background processes

2. **Create realistic scenarios**
   - Test with actual game assets
   - Simulate real user interactions
   - Include edge cases

3. **Monitor trends over time**
   - Track metrics across releases
   - Identify gradual degradation
   - Celebrate improvements

4. **Act on results**
   - Fix regressions immediately
   - Optimize bottlenecks
   - Update baselines after improvements

## Contributing

To add new performance tests:

1. Create test scenario in `puzzle_benchmarks.dart`
2. Add to CI runner in `ci_runner.dart`
3. Update performance targets if needed
4. Document new scenarios in this README

## License

See main project LICENSE file.
