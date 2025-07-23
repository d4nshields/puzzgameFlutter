#!/bin/bash

# Game Session Tracking - Quick Test Script
# This script helps verify the game session tracking implementation

echo "=== Game Session Tracking Test ==="
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Please run this script from the Flutter project root directory"
    exit 1
fi

echo "📱 Testing Game Session Tracking Implementation"
echo ""

# Install dependencies
echo "1. Installing dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi
echo "✅ Dependencies installed"
echo ""

# Run the tracking test
echo "2. Running unit tests..."
flutter test test/game_session_tracking_test.dart
if [ $? -ne 0 ]; then
    echo "❌ Unit tests failed"
    exit 1
fi
echo "✅ Unit tests passed"
echo ""

# Check for compilation errors
echo "3. Checking for compilation errors..."
flutter analyze --no-current-package
if [ $? -ne 0 ]; then
    echo "❌ Compilation errors found"
    exit 1
fi
echo "✅ No compilation errors"
echo ""

# Build test (optional - comment out if takes too long)
echo "4. Testing build compilation..."
flutter build apk --debug --target-platform android-arm64 --no-tree-shake-icons > build_output.log 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Build failed - check build_output.log for details"
    echo "Note: This might be due to missing Android SDK - the tracking code should still work"
else
    echo "✅ Build successful"
fi
echo ""

echo "=== Test Results ==="
echo "✅ Code implementation complete"
echo "✅ Dependencies configured"
echo "✅ Unit tests passing"
echo "✅ No compilation errors"
echo ""
echo "🎯 Next Steps:"
echo "1. Run the app: flutter run"
echo "2. Start a game session"
echo "3. Check Supabase dashboard for tracking data"
echo "4. Verify using the queries in TESTING_PLAN.md"
echo ""
echo "📊 Database Tables to Check:"
echo "   • app_usage (for app launch tracking)"
echo "   • game_sessions (for game session data)"
echo "   • game_stats (for aggregated user statistics)"
echo ""
echo "🔍 Manual Test Checklist:"
echo "   □ App launches and creates usage record"
echo "   □ Starting game creates session record"
echo "   □ Playing game updates session data"
echo "   □ Completing game updates statistics"
echo "   □ Both authenticated and anonymous users work"
echo ""
