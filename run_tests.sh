#!/bin/bash

# Test runner script with different configurations
# Usage: ./run_tests.sh [all|unit|performance|quick]

set -e

MODE=${1:-unit}

echo "🧪 Puzzle Nook Test Runner"
echo "========================="
echo "Mode: $MODE"
echo ""

case $MODE in
  all)
    echo "Running ALL tests (including performance)..."
    # Temporarily enable performance tests
    sed -i.bak 's/const bool runPerformanceTests = false/const bool runPerformanceTests = true/' test/test_config.dart
    flutter test
    # Restore original config
    mv test/test_config.dart.bak test/test_config.dart
    ;;
    
  unit)
    echo "Running unit tests only (no performance)..."
    flutter test
    ;;
    
  performance)
    echo "Running performance tests only..."
    flutter test test/performance/performance_test.dart --reporter expanded
    ;;
    
  quick)
    echo "Running quick tests only..."
    flutter test \
      --exclude-tags slow \
      --exclude-tags performance \
      test/
    ;;
    
  ci)
    echo "Running CI performance tests..."
    dart test/performance/ci_runner.dart
    ;;
    
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: $0 [all|unit|performance|quick|ci]"
    echo ""
    echo "Modes:"
    echo "  all         - Run all tests including performance"
    echo "  unit        - Run unit tests only (default)"
    echo "  performance - Run performance tests only"
    echo "  quick       - Run quick tests only"
    echo "  ci          - Run CI performance suite"
    exit 1
    ;;
esac

echo ""
echo "✅ Tests completed!"
