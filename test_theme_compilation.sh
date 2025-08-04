#!/usr/bin/env bash

set -euo pipefail

# Quick compilation test for theme updates
echo "Testing Flutter compilation with new Cozy Puzzle Theme..."

cd /home/daniel/work/puzzgameFlutter || exit 1

# Clean build artifacts
echo "Cleaning build artifacts..."
flutter clean

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Try to compile (just analyze, don't run)
echo "Analyzing code for compilation errors..."
flutter analyze

# Check for any obvious issues
echo "Compilation test complete. Check output above for any errors."
