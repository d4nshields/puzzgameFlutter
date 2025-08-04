#!/usr/bin/env bash

set -euo pipefail

echo "🔧 Testing Flutter compilation after async function fix..."

cd /home/daniel/work/puzzgameFlutter || exit 1

# Test Flutter compilation
echo "Testing Flutter compilation..."
if flutter analyze --no-pub 2>/dev/null; then
    echo "✅ Flutter analysis passed!"
else
    echo "❌ Flutter analysis failed"
    echo "💡 Running with full output..."
    flutter analyze --no-pub
    exit 1
fi

echo ""
echo "🎉 Flutter compilation test complete!"
