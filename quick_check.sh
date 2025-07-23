#!/bin/bash

# Very quick compilation check
cd /home/daniel/work/puzzgameFlutter

echo "=== Quick Build Check ==="
echo "1. Getting dependencies..."
flutter pub get --quiet

echo "2. Analyzing code..."
flutter analyze --no-current-package lib/core/infrastructure/supabase/supabase_game_session_tracking_service.dart

if [ $? -eq 0 ]; then
    echo "✅ No compilation errors in tracking service!"
    echo ""
    echo "3. Running full analysis..."
    flutter analyze --no-current-package
    
    if [ $? -eq 0 ]; then
        echo "✅ Full project analysis passed!"
    else
        echo "⚠️  Some analysis warnings (but main issue is fixed)"
    fi
else
    echo "❌ Still has compilation errors"
fi

echo ""
echo "Ready to test: flutter run"
