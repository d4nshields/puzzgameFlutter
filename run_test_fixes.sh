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
  --name "should verify state sequence" 2>&1 | head -30

echo ""
echo "======================================"
echo "Testing Results:"
echo "======================================"

# Run all tests and capture result
flutter test test/piece_state_machine_test.dart 2>&1 | tail -10
