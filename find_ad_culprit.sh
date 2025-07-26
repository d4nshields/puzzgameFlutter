#!/bin/bash

echo "🔍 Deep Android Dependency Analysis for AD_ID Permission"
echo "======================================================"

cd android

echo "📦 Step 1: Full dependency tree analysis..."
echo "Looking for advertising-related dependencies..."

# Get full dependency tree and filter for suspicious packages
./gradlew app:dependencies --configuration releaseRuntimeClasspath > /tmp/deps.txt

echo "🎯 Found these advertising/analytics related dependencies:"
grep -E "(ads|advertising|ad-id|analytics|firebase|gms)" /tmp/deps.txt | head -20

echo ""
echo "📋 Step 2: Checking for com.google.android.gms dependencies specifically..."
grep "com.google.android.gms" /tmp/deps.txt | sort | uniq

echo ""
echo "🔍 Step 3: Checking Firebase BOM contents..."
./gradlew app:dependencies --configuration releaseRuntimeClasspath | grep -A 50 "firebase-bom" | head -30

echo ""
echo "📦 Step 4: Checking what Firebase Analytics actually includes..."
./gradlew app:dependencies --configuration releaseRuntimeClasspath | grep -E "(firebase-analytics|firebase-common)" -A 5 -B 5

echo ""
echo "🔍 Step 5: Manifest merger report (if available)..."
if [ -f "app/build/outputs/logs/manifest-merger-release-report.txt" ]; then
    echo "✅ Found manifest merger report:"
    grep -i "ad_id\|advertising" app/build/outputs/logs/manifest-merger-release-report.txt
else
    echo "❌ No manifest merger report found. Build the app first:"
    echo "   flutter build appbundle --release"
fi

echo ""
echo "🔍 Step 6: Check what's actually in the built APK..."
if [ -f "../build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "✅ Analyzing built app bundle..."
    cd ..
    
    # Extract the bundle
    unzip -q build/app/outputs/bundle/release/app-release.aab -d /tmp/aab_extract
    
    # Check base manifest
    if [ -f "/tmp/aab_extract/base/AndroidManifest.xml" ]; then
        echo "📱 Permissions in built app bundle:"
        aapt dump permissions build/app/outputs/bundle/release/app-release.aab 2>/dev/null | grep -i "ad_id\|advertising" || echo "No AD_ID permission found"
        
        echo ""
        echo "📱 Raw manifest content (searching for AD_ID):"
        strings /tmp/aab_extract/base/AndroidManifest.xml | grep -i "ad_id\|advertising" || echo "No AD_ID found in manifest strings"
    fi
    
    # Clean up
    rm -rf /tmp/aab_extract
else
    echo "❌ No app bundle found. Build first with:"
    echo "   flutter build appbundle --release"
fi

echo ""
echo "💡 Next steps to investigate:"
echo "   1. If AD_ID permission appears in built app, the removal isn't working"
echo "   2. Check specific Firebase Analytics version for known issues"
echo "   3. Try excluding the permission at the dependency level"
