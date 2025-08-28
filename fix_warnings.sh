#!/bin/bash

# Script to fix all flutter analyze warnings
cd /home/daniel/work/puzzgameFlutter

echo "==================================================="
echo "Fixing Flutter Analyze Warnings"
echo "==================================================="

# Fix 1: Remove unused import in interaction_integration.dart
echo "1. Fixing interaction_integration.dart..."
sed -i "s/import '..\/infrastructure\/haptic_patterns.dart';/\/\/ Removed unused import: haptic_patterns.dart/" lib/game_module2/application/interaction_integration.dart

# Fix 2: Comment out unused fields (will be used later)
# These need more careful editing with the edit_file function

# Fix 3: Remove unused import in interaction_debug_panel.dart  
echo "2. Fixing interaction_debug_panel.dart..."
sed -i "s/import '..\/..\/infrastructure\/feature_flags.dart';/\/\/ Removed unused import: feature_flags.dart/" lib/game_module2/presentation/debug/interaction_debug_panel.dart

# Fix 4: Remove unused imports in test file
echo "3. Fixing interaction_integration_test.dart..."
sed -i "s/import 'package:puzzgame_flutter\/game_module2\/application\/interaction_integration.dart';/\/\/ Removed unused import/" test/integration/interaction_integration_test.dart
sed -i "s/import 'package:puzzgame_flutter\/game_module2\/domain\/entities\/puzzle_workspace.dart';/\/\/ Removed unused import/" test/integration/interaction_integration_test.dart  
sed -i "s/import 'package:puzzgame_flutter\/game_module2\/domain\/entities\/puzzle_piece.dart';/\/\/ Removed unused import/" test/integration/interaction_integration_test.dart

echo "Done with sed replacements. Manual edits still needed for some files."
echo "==================================================="
