#!/bin/bash
# Quick test runner for magnetic gesture recognizer

cd /home/daniel/work/puzzgameFlutter

echo "Running Magnetic Gesture Tests..."
echo "================================"

# Run the tests with minimal output
flutter test test/magnetic_gesture_recognizer_test.dart --reporter compact

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS: All tests passed!"
else
    echo ""
    echo "❌ FAILED: Some tests failed (exit code: $exit_code)"
    echo ""
    echo "To see detailed output, run:"
    echo "flutter test test/magnetic_gesture_recognizer_test.dart"
fi

exit $exit_code
