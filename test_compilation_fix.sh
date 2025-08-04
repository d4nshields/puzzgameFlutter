#!/usr/bin/env bash

set -euo pipefail

echo "🔧 Testing Android build compilation after fixes..."

cd /home/daniel/work/puzzgameFlutter || exit 1

# Test the Gradle compilation
echo "Testing Gradle configuration compilation..."
if cd android 2>/dev/null; then
    ./gradlew --no-daemon clean >/dev/null 2>&1
    gradle_ok=$?
    cd - >/dev/null || exit 1
    if [ $gradle_ok -eq 0 ]; then
        echo "✅ Gradle compilation successful!"
    else
        echo "❌ Gradle compilation failed"
        echo "💡 Running with verbose output..."
        cd android && ./gradlew --no-daemon clean --stacktrace
        exit 1
    fi
else
    echo "❌ Could not enter android directory"
    exit 1
fi

echo ""
echo "🎉 Compilation test complete!"
