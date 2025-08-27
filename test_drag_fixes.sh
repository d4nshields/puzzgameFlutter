#!/bin/bash
# Test the specific failing tests

cd /home/daniel/work/puzzgameFlutter

echo "Testing drag sequence tests..."
echo "================================"

echo -e "\n1. Testing main drag sequence:"
flutter test test/piece_state_machine_test.dart --name "should handle drag sequence correctly" 2>&1 | grep -A5 -B5 "Expected"

echo -e "\n2. Testing debug drag sequence:"
flutter test test/debug_state_machine_test.dart --name "should handle drag sequence correctly" 2>&1 | grep -A5 -B5 "Expected" 

echo -e "\n3. Running full test suite:"
flutter test test/piece_state_machine_test.dart test/debug_state_machine_test.dart 2>&1 | tail -15
