#!/bin/bash
# Run the magnetic gesture recognizer tests

echo "================================"
echo "Magnetic Gesture Recognizer Test"
echo "================================"
echo ""

# Navigate to project directory
cd /home/daniel/work/puzzgameFlutter

# Get dependencies first
echo "Getting dependencies..."
flutter pub get --no-example

echo ""
echo "Running tests..."
flutter test test/magnetic_gesture_recognizer_test.dart --reporter expanded

# Check exit code
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ All tests passed successfully!"
    echo ""
    echo "Summary:"
    echo "- Gesture processing < 1ms ✓"
    echo "- 120Hz touch sampling support ✓"
    echo "- No dropped events under load ✓"
    echo "- Magnetic field calculations ✓"
    echo "- Multi-touch support ✓"
    echo "- Velocity tracking ✓"
    echo "- Momentum physics ✓"
    echo "- Debug tools ✓"
else
    echo ""
    echo "❌ Some tests failed. Please review the output above."
fi
