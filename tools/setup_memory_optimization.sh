#!/bin/bash
# Memory Optimization Setup Script
# File: tools/setup_memory_optimization.sh

set -e

echo "🔧 Setting up Memory Optimization for Puzzle Game"
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Run this script from the Flutter project root directory"
    exit 1
fi

# Check Python installation
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is required but not installed"
    exit 1
fi

echo "✅ Python 3 found: $(python3 --version)"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install pillow numpy

# Make Python scripts executable
chmod +x tools/optimize_puzzle_assets.py
chmod +x tools/test_optimization.py

echo "🧪 Running optimization tests..."
python3 tools/test_optimization.py

# Run optimization on sample puzzle
echo "🔄 Optimizing sample puzzle assets..."
if [ -d "assets/puzzles/sample_puzzle_01" ]; then
    python3 tools/optimize_puzzle_assets.py sample_puzzle_01 --verbose
    echo "📊 Memory analysis results:"
    python3 tools/optimize_puzzle_assets.py sample_puzzle_01 --analyze-only
else
    echo "⚠️  Warning: sample_puzzle_01 not found, skipping optimization"
fi

# Check Flutter dependencies
echo "📱 Checking Flutter dependencies..."
flutter pub get

echo ""
echo "✅ Memory Optimization Setup Complete!"
echo "======================================"
echo ""
echo "📋 Next Steps:"
echo "1. Update your game module to use MemoryOptimizedPuzzleGameModule"
echo "2. Replace image widgets with MemoryOptimizedPuzzleImage"
echo "3. Test with 12x12 and 15x15 grids"
echo ""
echo "📖 See docs/memory_optimization_implementation.md for detailed instructions"
echo ""
echo "🚀 Expected Results:"
echo "   - 8x8:  1GB → ~300MB (70% reduction)"
echo "   - 12x12: 2.3GB → ~600MB (74% reduction)" 
echo "   - 15x15: 3.6GB → ~900MB (75% reduction)"
echo ""
