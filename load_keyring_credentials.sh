#!/bin/bash

# Load Android signing credentials from keyring and create key.properties
# This script is called by the Gradle build process

set -e

# Function to retrieve credentials based on backend
get_credential() {
    local backend="$1"
    local service="$2"
    local username="$3"
    
    case "$backend" in
        "gnome-keyring")
            secret-tool lookup service "$service" username "$username" 2>/dev/null || echo ""
            ;;
        "macos-keychain")
            security find-generic-password -s "$service" -a "$username" -w 2>/dev/null || echo ""
            ;;
        "1password-cli")
            op item get "Android Signing - $service" --fields password 2>/dev/null || echo ""
            ;;
        "bitwarden-cli")
            bw get password "Android Signing - $service" 2>/dev/null || echo ""
            ;;
        "pass")
            pass show "android-signing/$service/$username" 2>/dev/null | head -n1 || echo ""
            ;;
        *)
            echo ""
            ;;
    esac
}

# Main function to load credentials
load_keyring_credentials() {
    local key_properties="$1"
    
    if [ ! -f "$key_properties" ]; then
        echo "❌ key.properties file not found: $key_properties"
        return 1
    fi
    
    # Check if this is a keyring-based configuration
    if ! grep -q "__keyring_backend=" "$key_properties" 2>/dev/null; then
        echo "📄 Using direct key.properties (not keyring-based)"
        return 0
    fi
    
    # Extract keyring backend
    local backend=$(grep "__keyring_backend=" "$key_properties" | cut -d'=' -f2)
    
    if [ -z "$backend" ]; then
        echo "❌ No keyring backend specified in key.properties"
        return 1
    fi
    
    echo "🔐 Loading credentials from $backend keyring..."
    
    # Retrieve passwords from keyring
    local store_password=$(get_credential "$backend" "android-keystore" "store-password")
    local key_password=$(get_credential "$backend" "android-keystore" "key-password")
    
    if [ -z "$store_password" ] || [ -z "$key_password" ]; then
        echo "❌ Failed to retrieve passwords from $backend"
        echo "💡 Run ./setup_signing_keyring.sh to reconfigure"
        return 1
    fi
    
    # Get other properties
    local key_alias=$(grep "keyAlias=" "$key_properties" | cut -d'=' -f2)
    local store_file=$(grep "storeFile=" "$key_properties" | cut -d'=' -f2)
    
    # Create temporary key.properties with actual passwords
    local temp_key_properties="${key_properties}.tmp"
    
    cat > "$temp_key_properties" << EOF
storePassword=$store_password
keyPassword=$key_password
keyAlias=$key_alias
storeFile=$store_file
EOF
    
    chmod 600 "$temp_key_properties"
    
    # Replace the original with the temporary one
    mv "$temp_key_properties" "$key_properties"
    
    echo "✅ Credentials loaded successfully"
    return 0
}

# If called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    key_properties="${1:-android/key.properties}"
    load_keyring_credentials "$key_properties"
fi
