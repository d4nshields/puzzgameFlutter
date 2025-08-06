#!/bin/bash

# Final verification and setup script for the feature flag system

set -e

echo "🎯 Feature Flag System - Final Setup & Verification"
echo "=================================================="
echo ""

# Make all scripts executable
echo "📋 Making scripts executable..."
chmod +x build.sh switch_config.sh usage_examples.sh setup_feature_flags.sh test_compilation.sh 2>/dev/null || true
echo "✅ All scripts are now executable"
echo ""

# Show current configuration
echo "🔍 Current Configuration:"
if [ -f "lib/core/configuration/build_config.dart" ]; then
    if grep -q "BuildVariant.internal" lib/core/configuration/build_config.dart; then
        echo "   📱 INTERNAL build (development mode)"
        echo "      • Sample puzzle: SKIPPED"
        echo "      • Debug tools: ENABLED"
        echo "      • All features: ON"
    else
        echo "   📱 EXTERNAL build (production mode)"
        echo "      • Sample puzzle: INCLUDED"
        echo "      • Debug tools: DISABLED"
        echo "      • Production features: ON"
    fi
else
    echo "   ❌ Configuration file not found!"
    exit 1
fi
echo ""

# Check if main compilation issue is fixed
echo "🔍 Checking for compilation issues..."
if grep -q "BuildConfig.current" lib/main.dart lib/presentation/screens/*.dart lib/core/configuration/*.dart 2>/dev/null; then
    echo "   ❌ Found remaining 'BuildConfig.current' references!"
    echo "   These need to be changed to 'BuildConfig.isInternal' or 'BuildConfig.isExternal'"
    grep -n "BuildConfig.current" lib/main.dart lib/presentation/screens/*.dart lib/core/configuration/*.dart 2>/dev/null || true
    exit 1
else
    echo "   ✅ No 'BuildConfig.current' references found"
fi

# Quick syntax check
echo ""
echo "🧪 Quick syntax validation..."
if command -v flutter &> /dev/null; then
    flutter analyze lib/core/configuration/build_config.dart --no-preamble --quiet
    if [ $? -eq 0 ]; then
        echo "   ✅ Configuration syntax is valid"
    else
        echo "   ❌ Configuration has syntax issues"
        exit 1
    fi
else
    echo "   ⚠️  Flutter not found - skipping syntax check"
fi

echo ""
echo "🎉 SUCCESS! Feature Flag System is ready to use!"
echo ""
echo "📖 Quick Reference:"
echo "   ./switch_config.sh internal     # Development mode (skip sample puzzle)"
echo "   ./switch_config.sh external     # Production mode (complete flow)"
echo "   ./build.sh internal debug       # Build dev APK"
echo "   ./build.sh external release     # Build production APK"
echo "   ./test_compilation.sh           # Test full compilation"
echo ""

# Show the key change needed for switching
echo "🔧 Manual Configuration (if needed):"
echo "   Edit: lib/core/configuration/build_config.dart"
echo "   Line: const BuildVariant _activeBuildVariant = BuildVariant.external;"
echo "         Change 'external' to 'internal' for development builds"
echo ""

echo "✨ The compilation error should now be fixed!"
echo "   Try running: flutter run"
