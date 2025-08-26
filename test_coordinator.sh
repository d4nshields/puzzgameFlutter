#!/bin/bash
# Test the gesture coordinator implementation

cd /home/daniel/work/puzzgameFlutter

echo "================================"
echo "Testing Gesture Coordinator"
echo "================================"
echo ""

# Run the test
flutter test test/gesture_coordinator_test.dart --reporter compact

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Gesture Coordinator tests passed!"
else
    echo ""
    echo "❌ Tests failed. Checking for compilation errors..."
    flutter analyze lib/game_module2/presentation/gestures/gesture_coordinator.dart
fi
