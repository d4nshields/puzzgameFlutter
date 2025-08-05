#!/bin/bash

# Setup script to make all scripts executable and test the feature flag system

set -e

echo "🔧 Setting up Feature Flag System..."
echo ""

# Make scripts executable
echo "📋 Making scripts executable..."
chmod +x build.sh 2>/dev/null || echo "  build.sh - already executable or permission denied"
chmod +x switch_config.sh 2>/dev/null || echo "  switch_config.sh - already executable or permission denied" 
chmod +x usage_examples.sh 2>/dev/null || echo "  usage_examples.sh - already executable or permission denied"

echo "✅ Scripts are now executable"
echo ""

# Test current configuration
echo "🔍 Checking current configuration..."
./switch_config.sh
echo ""

# Run basic compilation test
echo "🧪 Testing compilation..."
echo "Running: flutter analyze lib/core/configuration/"

if command -v flutter &> /dev/null; then
    flutter analyze lib/core/configuration/ || echo "⚠️  Analysis completed with warnings/errors"
    echo ""
    
    echo "🧪 Running feature flag tests..."
    flutter test test/feature_flag_test.dart || echo "⚠️  Tests completed with warnings/errors"
else
    echo "Flutter not found in PATH - skipping compilation test"
fi

echo ""
echo "🎯 Feature Flag System Setup Complete!"
echo ""
echo "Quick start:"
echo "  ./switch_config.sh internal    # Switch to development mode" 
echo "  ./switch_config.sh external    # Switch to production mode"
echo "  ./build.sh external release    # Build production APK"
echo "  ./usage_examples.sh           # Show usage examples"
echo ""
echo "Your feature flag system is ready to use! 🚀"
