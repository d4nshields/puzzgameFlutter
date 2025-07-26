#!/bin/bash

echo "🔐 Android Signing Diagnosis for Puzzle Nook"
echo "=============================================="

# Check key.properties
echo "📋 Current key.properties:"
cat android/key.properties
echo ""

# Check if keystore file exists
KEYSTORE_PATH=$(grep "storeFile=" android/key.properties | cut -d'=' -f2)
echo "🔍 Checking keystore file: $KEYSTORE_PATH"

if [ -f "$KEYSTORE_PATH" ]; then
    echo "✅ Keystore file exists"
    
    # Get keystore info
    KEY_ALIAS=$(grep "keyAlias=" android/key.properties | cut -d'=' -f2)
    STORE_PASS=$(grep "storePassword=" android/key.properties | cut -d'=' -f2)
    
    echo "📊 Keystore details:"
    echo "   Alias: $KEY_ALIAS"
    echo "   Path: $KEYSTORE_PATH"
    
    echo ""
    echo "🔑 SHA1 Fingerprint of your keystore:"
    keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$KEY_ALIAS" -storepass "$STORE_PASS" | grep "SHA1:" | head -1
    
else
    echo "❌ Keystore file NOT found at: $KEYSTORE_PATH"
    echo ""
    echo "🔍 Searching for keystore files..."
    find . -name "*.p12" -o -name "*.jks" -o -name "*.keystore" 2>/dev/null | head -10
fi

echo ""
echo "🎯 Expected by Google Play:"
echo "   SHA1: 3B:24:0F:02:D9:30:9F:DF:D1:29:D8:9E:4F:55:0A:41:B6:F7:6B:58"

echo ""
echo "📝 Next Steps:"
echo "   1. Compare your SHA1 with expected SHA1"
echo "   2. If different, check Play Console App Signing settings"
echo "   3. Ensure you're using the upload key, not app signing key"
