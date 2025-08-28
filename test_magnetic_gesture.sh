#!/bin/bash
# Test the magnetic gesture recognizer

echo "Running Magnetic Gesture Recognizer Tests..."
flutter test test/magnetic_gesture_recognizer_test.dart --no-pub

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Tests failed. Check the output above."
fi
