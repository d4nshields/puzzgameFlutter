#!/bin/bash

# Run only the working tests
echo "Running Puzzle Nook Foundation Layer Tests"
echo "==========================================="
echo ""
echo "Running tests that are ready (skipping tests that need unimplemented dependencies)..."
echo ""

flutter test \
  test/coordinate_system_test.dart \
  test/performance/performance_test.dart \
  test/game_module2/ \
  --reporter expanded

echo ""
echo "Test Summary:"
echo "- coordinate_system_test.dart: Tests the coordinate transformation system"
echo "- performance_test.dart: Tests performance characteristics and benchmarks"
echo "- game_module2/: Tests for domain services and entities"
echo ""
echo "Skipped tests (need dependencies):"
echo "- golden_test.dart: Needs golden_toolkit package"
echo "- rendering_pipeline_test.dart: Needs mockito and actual implementations"
