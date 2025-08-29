#!/bin/bash

echo "Checking for errors in magnetic workspace widget..."
flutter analyze lib/game_module2/presentation/widgets/puzzle_workspace_widget_magnetic.dart 2>&1 | grep -E "error|warning" || echo "✅ No errors or warnings found in magnetic workspace widget!"
