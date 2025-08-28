#!/bin/bash
# Test runner for Day 9 fixes

echo "======================================"
echo "Running Day 9 State Machine Tests"
echo "======================================"
echo ""

cd /home/daniel/work/puzzgameFlutter

# Run only the specific tests that were failing
echo "Testing specific failing cases..."
flutter test test/piece_state_machine_test.dart \
  --name "should handle drag sequence correctly" \
  --name "should not transition from locked state" \
  --name "should verify state sequence"

echo ""
echo "======================================"
echo "Running Full State Machine Test Suite"
echo "======================================"
echo ""

# Run the full test suite
flutter test test/piece_state_machine_test.dart

echo ""
echo "======================================"
echo "Test Results Summary"
echo "======================================"
