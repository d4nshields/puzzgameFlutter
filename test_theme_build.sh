#!/bin/bash

# Quick compile test for theme integration
echo "Testing theme integration..."

cd /home/daniel/work/puzzgameFlutter

# Test build without running
flutter build apk --debug --no-tree-shake-icons --target-platform android-arm64 --dry-run

echo "Build test completed!"
