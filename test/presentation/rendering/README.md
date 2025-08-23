# Hybrid Renderer Tests

This directory contains tests for the hybrid rendering pipeline.

## Test Files

### test_compilation_test.dart
Tests that all public APIs of the hybrid renderer compile correctly and have the expected default values. This includes:
- `RenderingConfig` construction and default values
- `QualityLevel` enum accessibility
- `Layer` enum values
- `PerformanceMetrics` construction
- `RenderSettings` structure
- `RenderablePiece` interface

## Running Tests

From the project root:

```bash
# Run all rendering tests
flutter test test/presentation/rendering/

# Run specific test file
flutter test test/presentation/rendering/test_compilation_test.dart

# Run with coverage
flutter test --coverage test/presentation/rendering/
```

## Test Organization

Tests are organized to match the source code structure:
- `/test/presentation/rendering/` - Tests for rendering components
- `/test/presentation/rendering/core/` - Tests for core components (if needed)
- `/test/presentation/rendering/layers/` - Tests for layer implementations (if needed)

## Writing New Tests

When adding new features to the hybrid renderer:
1. Add corresponding tests in this directory
2. Follow the naming convention: `<feature>_test.dart`
3. Group related tests using `group()`
4. Use descriptive test names with `test()`
5. Verify both positive and negative cases
