#!/bin/bash
# Simple compilation test script
# File: tools/test_compilation.sh

echo "🔍 Testing Flutter compilation for memory optimization files..."

# Test individual files
echo "Testing memory_optimized_asset_manager.dart..."
flutter analyze lib/game_module/services/memory_optimized_asset_manager.dart

echo "Testing memory_optimized_asset_manager_painters.dart..."
flutter analyze lib/game_module/services/memory_optimized_asset_manager_painters.dart

echo "Testing puzzle_game_module.dart..."
flutter analyze lib/game_module/puzzle_game_module.dart

echo "Testing overall project compilation..."
flutter analyze

echo "✅ Compilation test complete!"
