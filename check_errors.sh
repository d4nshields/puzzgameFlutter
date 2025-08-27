#!/bin/bash
# Check for remaining errors
echo "Checking for Flutter analyze errors..."
flutter analyze lib/game_module2/ 2>&1 | grep '^  error' | head -20

echo ""
echo "Total error count:"
flutter analyze lib/game_module2/ 2>&1 | grep '^  error' | wc -l
