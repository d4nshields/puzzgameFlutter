#!/bin/bash
# Test runner with detailed output for debugging

cd /home/daniel/work/puzzgameFlutter

echo "Running Magnetic Gesture Recognizer Tests"
echo "=========================================="
echo ""

# Run tests with verbose output to see what's happening
flutter test test/magnetic_gesture_recognizer_test.dart \
  --reporter expanded \
  --concurrency=1 \
  2>&1 | tee test_output.log

exit_code=${PIPESTATUS[0]}

echo ""
echo "=========================================="
if [ $exit_code -eq 0 ]; then
    echo "✅ All tests passed!"
    echo ""
    echo "Performance Summary:"
    grep -E "(Average processing|Processed|Sampling)" test_output.log || true
else
    echo "❌ Tests failed with exit code: $exit_code"
    echo ""
    echo "Failed tests:"
    grep -E "\[E\]" test_output.log || true
fi

# Clean up
rm -f test_output.log

exit $exit_code
