#!/bin/bash

echo "Checking for warnings/errors in magnetic workspace widget..."
echo "=========================================="
flutter analyze lib/game_module2/presentation/widgets/puzzle_workspace_widget_magnetic.dart 2>&1 | grep -E "warning|error" || echo "✅ No warnings or errors found!"

echo ""
echo "Full analyze output:"
echo "=========================================="
flutter analyze lib/game_module2/presentation/widgets/puzzle_workspace_widget_magnetic.dart 2>&1
