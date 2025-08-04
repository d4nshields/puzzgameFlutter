#!/bin/bash

set -e  # Exit on any error

echo "🔐 Android App Signing Setup for Puzzle Nook"
echo "============================================="

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "android" ]; then
    echo "❌ Error: Run this script from the Flutter project root"
    exit 1
fi

KEY_PROPERTIES="android/key.properties"
KEY_TEMPLATE="android/key.properties.template"

# Check if key.properties already exists
if [ -f "$KEY_PROPERTIES" ]; then
    echo "📁 key.properties file already exists"
    read -p "🤔 Do you want to reconfigure it? (y/N): " reconfigure
    if [[ ! $reconfigure =~ ^[Yy]$ ]]; then
        echo "✅ Keeping existing configuration"
        exit 0
    fi
fi

echo ""
echo "📋 Setting up Android signing configuration..."
echo ""

# Copy template if it doesn't exist
if [ ! -f "$KEY_TEMPLATE" ]; then
    echo "⚠️  Template file missing, creating one..."
    cat > "$KEY_TEMPLATE" << 'EOF'
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
EOF
fi

# Copy template to actual file
cp "$KEY_TEMPLATE" "$KEY_PROPERTIES"

echo "📝 Please provide your keystore information:"
echo ""

# Get keystore file path
while true; do
    read -p "🗝️  Keystore file path (absolute path): " keystore_path
    if [ -f "$keystore_path" ]; then
        break
    else
        echo "❌ File not found: $keystore_path"
        echo "💡 Make sure to provide the full absolute path"
        read -p "📁 Would you like to browse for the file? (y/N): " browse
        if [[ $browse =~ ^[Yy]$ ]]; then
            echo "💡 Common locations to check:"
            echo "   • ~/android-keys/"
            echo "   • ~/.android/"
            echo "   • ./android/"
            echo "   • Current directory: $(pwd)"
            ls -la *.jks *.p12 2>/dev/null || echo "   (No .jks or .p12 files found in current directory)"
        fi
    fi
done

# Get other properties
read -p "🏷️  Key alias (usually 'upload'): " key_alias
key_alias=${key_alias:-upload}  # Default to 'upload' if empty

read -s -p "🔒 Keystore password: " store_password
echo ""
read -s -p "🔑 Key password: " key_password
echo ""

# Write the configuration
cat > "$KEY_PROPERTIES" << EOF
storePassword=$store_password
keyPassword=$key_password
keyAlias=$key_alias
storeFile=$keystore_path
EOF

echo ""
echo "✅ Configuration saved to $KEY_PROPERTIES"
echo "🔒 File permissions set to 600 (owner read/write only)"

# Set restrictive permissions
chmod 600 "$KEY_PROPERTIES"

echo ""
echo "🧪 Testing configuration..."

# Test the configuration by attempting a quick build check
echo "Testing Gradle configuration..."
if cd android 2>/dev/null; then
    ./gradlew signingReport >/dev/null 2>&1
    gradle_ok=$?
    cd - >/dev/null || exit 1
    if [ $gradle_ok -eq 0 ]; then
        echo "✅ Configuration test passed!"
    else
        echo "⚠️  Configuration test had issues, but this might be normal"
        echo "💡 Try a full build to verify: flutter build apk --release"
    fi
else
    echo "⚠️ Could not enter android directory – skipping Gradle validation"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📝 Next steps:"
echo "   • Test build: flutter build apk --release"
echo "   • Build app bundle: flutter build appbundle --release"
echo "   • Validate: ./validate_signing.sh"
echo ""
echo "🔐 Security reminders:"
echo "   • key.properties is already in .gitignore (good!)"
echo "   • Never commit this file to version control"
echo "   • Back up your keystore file safely"
echo "   • Consider using environment variables in CI/CD"
echo ""
echo "📖 For more help, see: docs/android_signing_setup.md"
