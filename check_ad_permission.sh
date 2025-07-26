#!/bin/bash

echo "🔍 Checking for AD_ID permission sources..."
echo "=========================================="

# Check the built APK/AAB for permissions
echo "📱 Checking built app bundle permissions..."

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "✅ Found app bundle, extracting manifest..."
    
    # Extract and check manifest
    unzip -p build/app/outputs/bundle/release/app-release.aab base/AndroidManifest.xml > /tmp/manifest.xml 2>/dev/null
    
    # Check for AD_ID permission
    if grep -q "AD_ID" /tmp/manifest.xml 2>/dev/null; then
        echo "❌ AD_ID permission found in manifest"
        echo "📋 Permissions in manifest:"
        strings /tmp/manifest.xml | grep "permission" | sort | uniq
    else
        echo "✅ No AD_ID permission found in manifest"
    fi
else
    echo "❌ No app bundle found. Build the app first:"
    echo "   flutter build appbundle --release"
fi

echo ""
echo "🔍 Checking dependencies that might add AD_ID..."

# Check Flutter dependencies
echo "📦 Flutter dependencies that might add advertising permissions:"
flutter deps --style=tree | grep -E "(ads|analytics|firebase|gms)" || echo "None found"

echo ""
echo "🔍 Checking Android dependencies..."
cd android && ./gradlew app:dependencies --configuration releaseRuntimeClasspath | grep -E "(ads|analytics|firebase|gms)" | head -10
