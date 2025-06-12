#!/bin/bash

# Simple build test script for the puzzle game
echo "🔨 Testing Flutter build..."

cd /home/daniel/work/puzzgameFlutter

# Clean build artifacts
echo "🧹 Cleaning build artifacts..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Analyze code for issues
echo "🔍 Analyzing code..."
flutter analyze --no-fatal-infos

# Try to compile (but don't run)
echo "🏗️ Testing compilation..."
flutter build linux --debug --verbose

echo "✅ Build test complete!"
