#!/bin/bash

# Quick build test to check for compilation errors
cd /home/daniel/work/puzzgameFlutter

echo "=== Checking for build errors ==="
echo ""

echo "1. Installing dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "2. Running code analysis..."
flutter analyze --no-current-package
if [ $? -ne 0 ]; then
    echo "❌ Code analysis found issues"
    exit 1
fi

echo "3. Running unit tests..."
flutter test test/game_session_tracking_test.dart
if [ $? -ne 0 ]; then
    echo "❌ Unit tests failed"
    exit 1
fi

echo "4. Testing compilation (dry run)..."
flutter build apk --debug --target-platform android-arm64 --no-tree-shake-icons --dry-run
if [ $? -ne 0 ]; then
    echo "❌ Compilation test failed"
    exit 1
fi

echo ""
echo "✅ All checks passed! The tracking implementation is ready."
echo ""
echo "Next steps:"
echo "1. Run: flutter run"
echo "2. Play a game session"
echo "3. Check Supabase dashboard for tracking data"
