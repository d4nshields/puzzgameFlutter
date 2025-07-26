#!/bin/bash

echo "🔍 Checking if AD_ID permission was removed from AAB..."
echo "=================================================="

AAB_FILE="build/app/outputs/bundle/release/app-release.aab"

if [ ! -f "$AAB_FILE" ]; then
    echo "❌ App bundle not found. Build first:"
    echo "   flutter build appbundle --release"
    exit 1
fi

echo "✅ Found app bundle: $AAB_FILE"

# Extract the AAB file
TEMP_DIR="/tmp/aab_extract_$$"
mkdir -p "$TEMP_DIR"

echo "📦 Extracting app bundle..."
unzip -q "$AAB_FILE" -d "$TEMP_DIR"

# Check the base AndroidManifest.xml
MANIFEST_FILE="$TEMP_DIR/base/AndroidManifest.xml"

if [ -f "$MANIFEST_FILE" ]; then
    echo "📱 Found manifest file, checking for permissions..."
    
    # Use aapt2 or bundletool to dump manifest from the extracted AAB
    echo "🔍 Searching for AD_ID permission in manifest..."
    
    # Try multiple approaches to read the binary manifest
    if command -v aapt2 >/dev/null 2>&1; then
        echo "Using aapt2 to dump manifest..."
        aapt2 dump xmltree "$AAB_FILE" --file base/AndroidManifest.xml | grep -i "ad_id\|advertising" || echo "✅ No AD_ID permission found!"
    elif command -v bundletool >/dev/null 2>&1; then
        echo "Using bundletool to extract manifest..."
        bundletool dump manifest --bundle="$AAB_FILE" | grep -i "ad_id\|advertising" || echo "✅ No AD_ID permission found!"
    else
        echo "📋 Checking strings in binary manifest..."
        # Extract readable strings from binary manifest
        strings "$MANIFEST_FILE" | grep -i "ad_id\|advertising" || echo "✅ No AD_ID permission found in strings!"
        
        echo ""
        echo "📋 All permissions found in manifest:"
        strings "$MANIFEST_FILE" | grep -E "android\.permission\.|com\.google\.android\.gms\.permission\." | sort | uniq
    fi
else
    echo "❌ Manifest file not found in extracted AAB"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "💡 Alternative check: Look at dependency tree to confirm exclusion worked..."
cd android
./gradlew app:dependencies --configuration releaseRuntimeClasspath | grep "play-services-ads-identifier" || echo "✅ play-services-ads-identifier successfully excluded!"
