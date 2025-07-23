#!/bin/bash

# Quick compilation test for game session tracking implementation
cd /home/daniel/work/puzzgameFlutter

echo "=== Checking Flutter dependencies ==="
flutter pub get

echo ""
echo "=== Running code generation (if needed) ==="
flutter pub run build_runner build --delete-conflicting-outputs

echo ""
echo "=== Checking for compilation errors ==="
flutter analyze --no-current-package

echo ""
echo "=== Testing compilation ==="
flutter build apk --debug --target-platform android-arm64 --no-tree-shake-icons

echo ""
echo "=== Build test completed ==="
