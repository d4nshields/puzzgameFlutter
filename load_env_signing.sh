#!/bin/bash

# Script to load signing configuration from environment variables
# Useful for CI/CD where you can't store files

set -e

echo "🌍 Loading signing configuration from environment variables..."

# Check required environment variables
required_vars=(
    "ANDROID_STORE_PASSWORD"
    "ANDROID_KEY_PASSWORD" 
    "ANDROID_KEY_ALIAS"
    "ANDROID_KEYSTORE_BASE64"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "❌ Missing required environment variables:"
    printf '   %s\n' "${missing_vars[@]}"
    echo ""
    echo "💡 Set these in your CI/CD environment:"
    echo "   export ANDROID_STORE_PASSWORD='your-store-password'"
    echo "   export ANDROID_KEY_PASSWORD='your-key-password'"
    echo "   export ANDROID_KEY_ALIAS='upload'"
    echo "   export ANDROID_KEYSTORE_BASE64='base64-encoded-keystore-file'"
    echo ""
    echo "📖 To encode your keystore: base64 -i your-keystore.jks"
    exit 1
fi

# Create keystore from base64
KEYSTORE_PATH="android/app/upload-keystore.jks"
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$KEYSTORE_PATH"
chmod 600 "$KEYSTORE_PATH"

# Create key.properties from environment
cat > "android/key.properties" << EOF
storePassword=$ANDROID_STORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=../app/upload-keystore.jks
EOF

chmod 600 "android/key.properties"

echo "✅ Signing configuration loaded from environment"
echo "🔐 Keystore saved to: $KEYSTORE_PATH"
echo "📄 key.properties created with environment values"
echo ""
echo "💡 You can now run: flutter build appbundle --release"
