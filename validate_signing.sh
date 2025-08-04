#!/bin/bash

echo "🔍 Validating Android signing configuration..."

KEY_PROPERTIES="android/key.properties"

if [ ! -f "$KEY_PROPERTIES" ]; then
    echo "❌ key.properties file not found"
    echo "💡 Run ./setup_signing_keyring.sh for keyring-based setup"
    echo "💡 Or run ./setup_signing.sh for manual setup"
    exit 1
fi

echo "📄 Found key.properties file"

# Check if it's keyring-based
if grep -q "__keyring_backend=" "$KEY_PROPERTIES" 2>/dev/null; then
    backend=$(grep "__keyring_backend=" "$KEY_PROPERTIES" | cut -d'=' -f2)
    echo "🔐 Keyring-based configuration detected (backend: $backend)"
    
    # Test keyring credential loading
    echo "🧪 Testing keyring credential access..."
    if ./load_keyring_credentials.sh "$KEY_PROPERTIES" >/dev/null 2>&1; then
        echo "✅ Keyring credentials accessible"
    else
        echo "❌ Failed to load keyring credentials"
        echo "💡 Run ./setup_signing_keyring.sh to reconfigure"
        exit 1
    fi
    
    # Restore keyring-based file (load script modifies it)
    git checkout "$KEY_PROPERTIES" 2>/dev/null || echo "⚠️  Could not restore keyring file (not in git)"
else
    echo "📝 Direct configuration (passwords in file)"
fi

# Extract values (handle potential spaces and quotes)
store_file=$(grep "storeFile=" "$KEY_PROPERTIES" | cut -d'=' -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')
key_alias=$(grep "keyAlias=" "$KEY_PROPERTIES" | cut -d'=' -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')

if [ -z "$store_file" ] || [ -z "$key_alias" ]; then
    echo "❌ key.properties appears to be incomplete"
    echo "📋 Required fields: storeFile, keyAlias"
    exit 1
fi

echo "🏷️  Key alias: $key_alias ✅"

# Check if keystore file exists (handle relative paths)
if [[ "$store_file" = /* ]]; then
    # Absolute path
    keystore_path="$store_file"
else
    # Relative path, assume relative to android directory
    keystore_path="android/$store_file"
fi

if [ ! -f "$keystore_path" ]; then
    echo "❌ Keystore file not found: $keystore_path"
    echo "🔍 Checking alternative locations..."
    
    # Try some common alternatives
    if [ -f "$store_file" ]; then
        echo "✅ Found at: $store_file"
        keystore_path="$store_file"
    elif [ -f "android/app/$(basename "$store_file")" ]; then
        echo "✅ Found at: android/app/$(basename "$store_file")"
        keystore_path="android/app/$(basename "$store_file")"
    else
        echo "💡 Please check the storeFile path in key.properties"
        exit 1
    fi
fi

echo "🗝️  Keystore file: $keystore_path ✅"

# Test if we can list the keystore contents
echo "🧪 Testing keystore accessibility..."
if command -v keytool >/dev/null 2>&1; then
    # For keyring-based configs, we need to temporarily load credentials
    if grep -q "__keyring_backend=" "$KEY_PROPERTIES" 2>/dev/null; then
        echo "🔐 Testing keystore with keyring credentials..."
        temp_props="/tmp/key.properties.test.$$"
        cp "$KEY_PROPERTIES" "$temp_props"
        
        if ./load_keyring_credentials.sh "$temp_props" >/dev/null 2>&1; then
            store_password=$(grep "storePassword=" "$temp_props" | cut -d'=' -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')
            if keytool -list -keystore "$keystore_path" -alias "$key_alias" -storepass "$store_password" >/dev/null 2>&1; then
                echo "✅ Keystore validation passed!"
            else
                echo "⚠️  Could not fully validate keystore"
                echo "💡 This might be OK - check if alias '$key_alias' exists:"
                echo "    keytool -list -keystore '$keystore_path'"
            fi
            rm -f "$temp_props"
        else
            echo "❌ Could not load keyring credentials for testing"
        fi
    else
        # Direct configuration - can't test without exposing password
        echo "⚠️  Cannot test direct configuration without exposing passwords"
        echo "💡 Run a build test: flutter build apk --release"
    fi
else
    echo "⚠️  keytool not found - skipping keystore validation"
fi

echo ""
echo "🧪 Testing Gradle configuration..."
if cd android && ./gradlew signingReport >/dev/null 2>&1; then
    echo "✅ Gradle signing configuration is valid!"
else
    echo "⚠️  Gradle validation had issues"
    echo "💡 Try running: cd android && ./gradlew signingReport"
fi

cd - >/dev/null 2>&1

echo ""
echo "🎉 Signing configuration validation complete!"
echo "💡 Test with: flutter build apk --release"
