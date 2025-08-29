#!/bin/bash

echo "Running flutter analyze to check for remaining errors..."
echo "=========================================="
flutter analyze lib/game_module2/presentation/widgets/puzzle_workspace_widget_magnetic.dart 2>&1

echo ""
echo "Checking for any errors in game_module2..."
echo "=========================================="
flutter analyze lib/game_module2/ 2>&1 | grep -E "^  error" || echo "✅ No errors found in game_module2!"
