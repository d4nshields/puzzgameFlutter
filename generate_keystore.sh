#!/bin/bash

# Script to generate and test upload keystore for Nook app
# Run this script and follow the prompts

echo "=== Nook App Keystore Generation ==="
echo

# Set keystore path
KEYSTORE_PATH="$HOME/upload-keystore.jks"

# Remove existing keystore if it exists
if [ -f "$KEYSTORE_PATH" ]; then
    echo "Removing existing keystore..."
    rm "$KEYSTORE_PATH"
fi

echo "Generating new keystore with JKS format..."
echo "You will be prompted for:"
echo "1. Keystore password (remember this!)"
echo "2. Key password (can be the same as keystore password)"
echo "3. Your details (name, organization, etc.)"
echo

# Generate keystore
keytool -genkey -v -keystore "$KEYSTORE_PATH" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if [ $? -eq 0 ]; then
    echo
    echo "✓ Keystore generated successfully!"
    echo
    echo "Testing keystore access..."
    echo "Enter the same keystore password you just used:"
    
    keytool -list -v -keystore "$KEYSTORE_PATH" -alias upload
    
    if [ $? -eq 0 ]; then
        echo
        echo "✓ Keystore test successful!"
        echo "✓ Your upload keystore is ready at: $KEYSTORE_PATH"
        echo
        echo "Next steps:"
        echo "1. Copy android/key.properties.template to android/key.properties"
        echo "2. Edit key.properties with your keystore details"
        echo "3. Update the storeFile path to: $KEYSTORE_PATH"
    else
        echo
        echo "✗ Keystore test failed. There may be an issue with the password or keystore format."
    fi
else
    echo
    echo "✗ Keystore generation failed."
fi
