# Test Execution Guide

## How Tests Are Organized

```
test/
├── performance/
│   ├── performance_test.dart      # Standard Flutter test runner compatible
│   ├── ci_runner.dart             # CI/CD specific runner with exit codes
│   ├── performance_framework.dart # Core framework
│   └── puzzle_benchmarks.dart    # Benchmark scenarios
├── game_module2/                 # Domain tests
├── test_config.dart              # Test configuration
└── *.dart                        # Other unit tests
```

## Running Tests with `flutter test`

### Default Behavior

```bash
flutter test
```

This runs:
- ✅ All unit tests in `/test/`
- ✅ All tests in subdirectories
- ❌ **Performance tests are SKIPPED by default** (controlled by `test_config.dart`)

### Why Performance Tests Are Skipped by Default

1. **Time**: Performance tests take 2-10 minutes vs milliseconds for unit tests
2. **Resources**: They consume significant CPU/memory
3. **Purpose**: They're for benchmarking, not correctness validation
4. **CI/CD**: They should run in dedicated performance pipelines

## How to Run Performance Tests

### Option 1: Enable in Configuration (Temporary)

Edit `test/test_config.dart`:
```dart
const bool runPerformanceTests = true;  // Change from false
```

Then run:
```bash
flutter test
```

### Option 2: Run Performance Tests Directly

```bash
# Run only performance tests
flutter test test/performance/performance_test.dart

# With detailed output
flutter test test/performance/performance_test.dart --reporter expanded

# With custom timeout
flutter test test/performance/performance_test.dart --timeout 10m
```

### Option 3: Use the Performance Test Runner Script

```bash
# Run standard performance tests
./run_performance_tests.sh

# Run quick tests only
./run_performance_tests.sh --quick

# Run full test suite including long sessions
./run_performance_tests.sh --full

# Create a new baseline
./run_performance_tests.sh --baseline

# Run in CI mode with strict thresholds
./run_performance_tests.sh --ci

# Run the CI runner directly
./run_performance_tests.sh --ci-runner
```

### Option 4: Run Specific Performance Tests

```bash
# Run only small puzzle benchmark
flutter test test/performance/performance_test.dart \
  --name "Small Puzzle"

# Run only stress tests
flutter test test/performance/performance_test.dart \
  --name "Stress Tests"

# Skip long-running tests
flutter test test/performance/performance_test.dart \
  --exclude-tags slow
```

## CI/CD Performance Testing

For CI/CD pipelines, use the dedicated runner:

```bash
# Run full CI suite with exit codes
dart test/performance/ci_runner.dart

# Or use the performance script
./run_performance_tests.sh --ci
```

## Test Tags and Filtering

Performance tests can be tagged for filtering:

```dart
testWidgets('30-minute session', (tester) async {
  // test code
}, tags: ['performance', 'slow']);
```

Run with tags:
```bash
# Run only performance tagged tests
flutter test --tags performance

# Exclude slow tests
flutter test --exclude-tags slow
```

## Configuration Options

### In `test/test_config.dart`:

```dart
// Control which tests run by default
const bool runPerformanceTests = false;  // Set to true to include
const bool runLongTests = false;         // Set to true for long tests

// Timeout configurations
const Duration quickTestTimeout = Duration(seconds: 30);
const Duration normalTestTimeout = Duration(minutes: 2);
const Duration longTestTimeout = Duration(minutes: 10);
```

### In Individual Tests:

```dart
testWidgets('My test', (tester) async {
  // test code
}, 
  skip: !runPerformanceTests,  // Skip based on config
  timeout: Timeout(longTestTimeout),  // Custom timeout
  tags: ['performance'],  // Tag for filtering
);
```

## Best Practices

### During Development

1. **Keep performance tests disabled** in `test_config.dart`
2. **Run unit tests frequently**: `flutter test`
3. **Run performance tests before commits**: `./run_tests.sh performance`

### Before Pull Requests

```bash
# Run full test suite
./run_tests.sh all

# Or manually
flutter test  # Unit tests
flutter test test/performance/performance_test.dart  # Performance
```

### In CI/CD

```yaml
# GitHub Actions example
- name: Unit Tests
  run: flutter test
  
- name: Performance Tests
  run: dart test/performance/ci_runner.dart
```

## Troubleshooting

### Tests Not Running

If performance tests don't run with `flutter test`:
1. Check `test_config.dart` - ensure `runPerformanceTests = true`
2. Check individual test `skip` parameters
3. Use `--reporter expanded` to see skipped tests

### Tests Timing Out

```bash
# Increase timeout
flutter test test/performance/performance_test.dart --timeout 10m
```

### Memory Issues

```bash
# Run with increased memory
flutter test --platform-args="--old-gen-heap-size=4096"
```

## Summary

- **Default**: `flutter test` runs unit tests only (fast)
- **Performance**: Explicitly run with `flutter test test/performance/performance_test.dart`
- **All Tests**: Use `./run_tests.sh all` or enable in config
- **CI/CD**: Use `ci_runner.dart` for proper exit codes and reports
