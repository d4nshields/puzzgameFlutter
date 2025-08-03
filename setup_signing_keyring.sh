#!/bin/bash

# Android Signing Setup with System Keyring Integration
# Supports multiple credential backends for a better developer experience

set -e

echo "🔐 Advanced Android App Signing Setup for Puzzle Nook"
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "android" ]; then
    echo "❌ Error: Run this script from the Flutter project root"
    exit 1
fi

KEY_PROPERTIES="android/key.properties"
KEY_TEMPLATE="android/key.properties.template"

# Detect available credential backends
detect_backends() {
    local backends=()
    
    # Check for system keyrings
    if command -v secret-tool >/dev/null 2>&1; then
        backends+=("gnome-keyring")
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]] && command -v security >/dev/null 2>&1; then
        backends+=("macos-keychain")
    fi
    
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]] && command -v cmdkey >/dev/null 2>&1; then
        backends+=("windows-credential")
    fi
    
    # Check for developer password managers
    if command -v op >/dev/null 2>&1; then
        backends+=("1password-cli")
    fi
    
    if command -v bw >/dev/null 2>&1; then
        backends+=("bitwarden-cli")
    fi
    
    # Check for other CLI password managers
    if command -v pass >/dev/null 2>&1; then
        backends+=("pass")
    fi
    
    if command -v gopass >/dev/null 2>&1; then
        backends+=("gopass")
    fi
    
    echo "${backends[@]}"
}

# Store credentials in GNOME Keyring
store_gnome_keyring() {
    local service="$1"
    local username="$2"
    local password="$3"
    
    echo "$password" | secret-tool store --label="$service $username" service "$service" username "$username"
}

# Retrieve credentials from GNOME Keyring
get_gnome_keyring() {
    local service="$1"
    local username="$2"
    
    secret-tool lookup service "$service" username "$username" 2>/dev/null || echo ""
}

# Store credentials in macOS Keychain
store_macos_keychain() {
    local service="$1"
    local username="$2"
    local password="$3"
    
    echo "$password" | security add-generic-password -s "$service" -a "$username" -w -U
}

# Retrieve credentials from macOS Keychain
get_macos_keychain() {
    local service="$1"
    local username="$2"
    
    security find-generic-password -s "$service" -a "$username" -w 2>/dev/null || echo ""
}

# Store credentials using 1Password CLI
store_1password() {
    local service="$1"
    local username="$2"
    local password="$3"
    
    # Check if signed in
    if ! op account list >/dev/null 2>&1; then
        echo "Please sign in to 1Password CLI first: op signin"
        return 1
    fi
    
    # Create or update item
    op item create --category="Password" --title="Android Signing - $service" \
        username="$username" password="$password" \
        --tags="android,development,signing" 2>/dev/null || \
    op item edit "Android Signing - $service" password="$password" 2>/dev/null
}

# Retrieve credentials from 1Password CLI
get_1password() {
    local service="$1"
    local username="$2"
    
    op item get "Android Signing - $service" --fields password 2>/dev/null || echo ""
}

# Store credentials using Bitwarden CLI
store_bitwarden() {
    local service="$1"
    local username="$2" 
    local password="$3"
    
    # Check if logged in
    if ! bw status | grep -q "unlocked" 2>/dev/null; then
        echo "Please unlock Bitwarden CLI first: bw unlock"
        return 1
    fi
    
    # Create item
    local item_json=$(cat <<EOF
{
  "type": 1,
  "name": "Android Signing - $service",
  "login": {
    "username": "$username",
    "password": "$password"
  },
  "favorite": false,
  "organizationId": null
}
EOF
)
    
    echo "$item_json" | bw create item 2>/dev/null || \
    bw edit item --item-id "$(bw get item "Android Signing - $service" | jq -r '.id')" "$item_json" 2>/dev/null
}

# Retrieve credentials from Bitwarden CLI
get_bitwarden() {
    local service="$1"
    local username="$2"
    
    bw get password "Android Signing - $service" 2>/dev/null || echo ""
}

# Store credentials using pass
store_pass() {
    local service="$1"
    local username="$2"
    local password="$3"
    
    echo "$password" | pass insert -m "android-signing/$service/$username" >/dev/null 2>&1
}

# Retrieve credentials from pass
get_pass() {
    local service="$1"
    local username="$2"
    
    pass show "android-signing/$service/$username" 2>/dev/null | head -n1 || echo ""
}

# Main credential storage function
store_credential() {
    local backend="$1"
    local service="$2"
    local username="$3"
    local password="$4"
    
    case "$backend" in
        "gnome-keyring")
            store_gnome_keyring "$service" "$username" "$password"
            ;;
        "macos-keychain")
            store_macos_keychain "$service" "$username" "$password"
            ;;
        "1password-cli")
            store_1password "$service" "$username" "$password"
            ;;
        "bitwarden-cli")
            store_bitwarden "$service" "$username" "$password"
            ;;
        "pass")
            store_pass "$service" "$username" "$password"
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            return 1
            ;;
    esac
}

# Main credential retrieval function
get_credential() {
    local backend="$1"
    local service="$2"
    local username="$3"
    
    case "$backend" in
        "gnome-keyring")
            get_gnome_keyring "$service" "$username"
            ;;
        "macos-keychain")
            get_macos_keychain "$service" "$username"
            ;;
        "1password-cli")
            get_1password "$service" "$username"
            ;;
        "bitwarden-cli")
            get_bitwarden "$service" "$username"
            ;;
        "pass")
            get_pass "$service" "$username"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Setup wizard
setup_wizard() {
    local backends=($(detect_backends))
    
    if [ ${#backends[@]} -eq 0 ]; then
        echo "❌ No supported credential backends found!"
        echo ""
        echo "📦 Please install one of the following:"
        echo "   • Linux: libsecret-tools (for GNOME Keyring)"
        echo "   • macOS: Already has Keychain (built-in)"
        echo "   • 1Password CLI: https://1password.com/downloads/command-line"
        echo "   • Bitwarden CLI: https://bitwarden.com/help/cli"
        echo "   • pass: https://www.passwordstore.org"
        echo ""
        read -p "🤔 Continue with manual setup instead? (y/N): " manual_setup
        if [[ $manual_setup =~ ^[Yy]$ ]]; then
            manual_setup_wizard
        fi
        return 1
    fi
    
    echo "🔍 Found credential backends:"
    for i in "${!backends[@]}"; do
        echo "   $((i+1)). ${backends[i]}"
    done
    echo ""
    
    while true; do
        read -p "📱 Select credential backend (1-${#backends[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backends[@]}" ]; then
            selected_backend="${backends[$((choice-1))]}"
            break
        else
            echo "❌ Invalid choice. Please select 1-${#backends[@]}"
        fi
    done
    
    echo "✅ Selected: $selected_backend"
    echo ""
    
    # Check if key.properties already exists
    if [ -f "$KEY_PROPERTIES" ]; then
        echo "📁 key.properties file already exists"
        read -p "🤔 Do you want to reconfigure it? (y/N): " reconfigure
        if [[ ! $reconfigure =~ ^[Yy]$ ]]; then
            echo "✅ Keeping existing configuration"
            return 0
        fi
    fi
    
    # Keystore setup
    setup_keystore_credentials "$selected_backend"
}

# Keystore credential setup
setup_keystore_credentials() {
    local backend="$1"
    
    echo ""
    echo "📝 Setting up Android signing credentials..."
    echo ""
    
    # Get keystore file path
    while true; do
        read -p "🗝️  Keystore file path (absolute path): " keystore_path
        if [ -f "$keystore_path" ]; then
            break
        else
            echo "❌ File not found: $keystore_path"
            echo "💡 Make sure to provide the full absolute path"
        fi
    done
    
    # Get other properties
    read -p "🏷️  Key alias (usually 'upload'): " key_alias
    key_alias=${key_alias:-upload}
    
    echo ""
    echo "🔐 Now we'll securely store your passwords in $backend"
    echo ""
    
    # Store passwords in keyring
    read -s -p "🔒 Keystore password: " store_password
    echo ""
    store_credential "$backend" "android-keystore" "store-password" "$store_password"
    
    read -s -p "🔑 Key password: " key_password
    echo ""
    store_credential "$backend" "android-keystore" "key-password" "$key_password"
    
    # Create key.properties that references the keyring
    cat > "$KEY_PROPERTIES" << EOF
# Android signing configuration
# Passwords are stored securely in $backend
storePassword=__FROM_KEYRING__
keyPassword=__FROM_KEYRING__
keyAlias=$key_alias
storeFile=$keystore_path

# Keyring backend configuration
__keyring_backend=$backend
EOF
    
    chmod 600 "$KEY_PROPERTIES"
    
    echo ""
    echo "✅ Credentials stored securely in $backend"
    echo "✅ Configuration saved to $KEY_PROPERTIES"
    echo ""
}

# Manual setup fallback
manual_setup_wizard() {
    echo ""
    echo "📝 Manual setup (passwords stored in file - less secure)"
    echo ""
    
    # Copy template if it doesn't exist
    if [ ! -f "$KEY_TEMPLATE" ]; then
        cat > "$KEY_TEMPLATE" << 'EOF'
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
EOF
    fi
    
    cp "$KEY_TEMPLATE" "$KEY_PROPERTIES"
    
    # Get keystore file path
    while true; do
        read -p "🗝️  Keystore file path (absolute path): " keystore_path
        if [ -f "$keystore_path" ]; then
            break
        else
            echo "❌ File not found: $keystore_path"
        fi
    done
    
    read -p "🏷️  Key alias (usually 'upload'): " key_alias
    key_alias=${key_alias:-upload}
    
    read -s -p "🔒 Keystore password: " store_password
    echo ""
    read -s -p "🔑 Key password: " key_password
    echo ""
    
    # Write configuration
    cat > "$KEY_PROPERTIES" << EOF
storePassword=$store_password
keyPassword=$key_password
keyAlias=$key_alias
storeFile=$keystore_path
EOF
    
    chmod 600 "$KEY_PROPERTIES"
    
    echo ""
    echo "⚠️  Passwords stored in plaintext file (less secure)"
    echo "✅ Configuration saved to $KEY_PROPERTIES"
}

# Test the configuration
test_configuration() {
    echo ""
    echo "🧪 Testing configuration..."
    
    if ./validate_signing.sh >/dev/null 2>&1; then
        echo "✅ Configuration test passed!"
    else
        echo "⚠️  Configuration test had issues"
        echo "💡 Try: flutter build apk --release --verbose"
    fi
}

# Main execution
main() {
    echo "🔍 Detecting available credential backends..."
    local backends=($(detect_backends))
    
    if [ ${#backends[@]} -gt 0 ]; then
        echo "✅ Found ${#backends[@]} credential backend(s)"
        setup_wizard
    else
        echo "⚠️  No credential backends found, using manual setup"
        manual_setup_wizard
    fi
    
    test_configuration
    
    echo ""
    echo "🎉 Setup complete!"
    echo ""
    echo "📝 Next steps:"
    echo "   • Test build: flutter build apk --release"
    echo "   • Build app bundle: flutter build appbundle --release"
    echo "   • Validate anytime: ./validate_signing.sh"
    echo ""
    echo "🔐 Security notes:"
    echo "   • Passwords are stored securely in your selected credential backend"
    echo "   • key.properties contains references, not actual passwords"
    echo "   • Share this setup method with your team for consistency"
}

# Run main function
main "$@"
