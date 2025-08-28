#!/bin/bash
# Quick test to verify the gesture coordinator fix

cd /home/daniel/work/puzzgameFlutter

echo "Testing Gesture Coordinator compilation..."
flutter test test/gesture_coordinator_test.dart --reporter compact 2>&1 | head -20

echo ""
echo "Checking for compilation errors..."
if flutter analyze lib/game_module2/presentation/gestures/gesture_coordinator.dart 2>&1 | grep -q "No issues found"; then
    echo "✅ No compilation errors found!"
else
    echo "⚠️ There may still be issues:"
    flutter analyze lib/game_module2/presentation/gestures/gesture_coordinator.dart
fi
