#!/bin/bash

echo "🔧 Making Android signing scripts executable..."

# Make all signing-related scripts executable
chmod +x setup_signing.sh
chmod +x setup_signing_keyring.sh
chmod +x validate_signing.sh
chmod +x load_keyring_credentials.sh
chmod +x load_env_signing.sh

echo "✅ All signing scripts are now executable"
echo ""
echo "📋 Available signing commands:"
echo ""
echo "🔐 Keyring-Based Setup (Recommended):"
echo "   ./setup_signing_keyring.sh   - Interactive setup with system keyring"
echo ""
echo "📝 Traditional Setup:"
echo "   ./setup_signing.sh           - Manual setup (passwords in file)"
echo ""
echo "🧪 Validation & Testing:"
echo "   ./validate_signing.sh        - Validate current configuration"
echo ""
echo "🌍 CI/CD Support:"
echo "   ./load_env_signing.sh        - Load from environment variables"
echo ""
echo "🎯 Recommended workflow:"
echo "   1. Run: ./setup_signing_keyring.sh"
echo "   2. Test: ./validate_signing.sh"
echo "   3. Build: flutter build appbundle --release"
echo ""
echo "💡 The keyring-based setup eliminates manual password entry!"
echo "   Passwords are stored securely in your system keyring or"
echo "   developer password manager (1Password, Bitwarden, etc.)"
