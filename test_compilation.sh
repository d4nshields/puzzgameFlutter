#!/bin/bash

# Quick compilation test script
echo "🧪 Testing Feature Flag System Compilation..."
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found in PATH"
    echo "Please install Flutter or add it to your PATH"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -1)"
echo ""

# Test analyze on our configuration files
echo "🔍 Analyzing feature flag configuration..."
flutter analyze lib/core/configuration/ --no-preamble

if [ $? -eq 0 ]; then
    echo "✅ Configuration files analysis passed"
else
    echo "❌ Configuration files have analysis issues"
    exit 1
fi

echo ""

# Test analyze on main.dart
echo "🔍 Analyzing main.dart..."
flutter analyze lib/main.dart --no-preamble

if [ $? -eq 0 ]; then
    echo "✅ main.dart analysis passed"
else
    echo "❌ main.dart has analysis issues"
    exit 1
fi

echo ""

# Try to compile (this will catch const evaluation errors)
echo "🔨 Testing compilation..."
flutter build apk --debug --no-pub --quiet

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful! Feature flag system is working correctly."
    echo ""
    echo "🎯 Current build variant:"
    if grep -q "BuildVariant.internal" lib/core/configuration/build_config.dart; then
        echo "   INTERNAL - Sample puzzle will be skipped"
    else
        echo "   EXTERNAL - Complete user flow included"
    fi
else
    echo "❌ Compilation failed"
    echo ""
    echo "To debug:"
    echo "  flutter build apk --debug --verbose"
    exit 1
fi

echo ""
echo "🚀 Feature flag system is ready to use!"
echo ""
echo "Next steps:"
echo "  ./switch_config.sh internal    # For development"
echo "  ./switch_config.sh external    # For production"
echo "  ./build.sh external release    # Build production version"
