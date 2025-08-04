# Advanced Android Signing with System Keyring Integration

## Overview
This solution eliminates manual password management for Android app signing by integrating with system keyrings and developer password managers. No more typing passwords or storing them in plaintext files!

## Supported Backends

### System Keyrings
- **Linux (GNOME Keyring)** - Uses `secret-tool` via libsecret
- **macOS (Keychain)** - Uses built-in `security` command
- **Windows (Credential Store)** - Uses `cmdkey` (future implementation)

### Developer Password Managers
- **1Password CLI** - `op` command with vault integration
- **Bitwarden CLI** - `bw` command with secure storage
- **pass** - Unix password manager with GPG encryption
- **gopass** - Go-based password manager

## Quick Setup

### Option 1: Keyring-Based Setup (Recommended)
```bash
# Run the enhanced setup with keyring integration
./setup_signing_keyring.sh

# Follow the interactive prompts to:
# 1. Select your preferred credential backend
# 2. Provide keystore file path and alias
# 3. Securely store passwords in the selected backend
```

### Option 2: Traditional Setup (Fallback)
```bash
# Manual setup (stores passwords in file)
./setup_signing.sh
```

## How It Works

### Keyring Integration Flow
1. **Setup Phase**: Passwords are stored securely in your chosen backend
2. **Build Phase**: Gradle calls `load_keyring_credentials.sh` to retrieve passwords
3. **Temporary Usage**: A temporary `key.properties` file is created with actual passwords
4. **Cleanup**: Temporary file is used for signing then can be discarded

### Example Configuration Files

**Keyring-based key.properties:**
```properties
# Android signing configuration
# Passwords are stored securely in gnome-keyring
storePassword=__FROM_KEYRING__
keyPassword=__FROM_KEYRING__
keyAlias=upload
storeFile=/home/user/android-keys/upload-keystore.jks

# Keyring backend configuration
__keyring_backend=gnome-keyring
```

## Backend-Specific Setup

### GNOME Keyring (Linux)
```bash
# Install required packages (Ubuntu/Debian)
sudo apt install libsecret-tools gnome-keyring

# Setup will automatically use secret-tool to store credentials
./setup_signing_keyring.sh
```

### 1Password CLI
```bash
# Install 1Password CLI
# Download from: https://1password.com/downloads/command-line

# Sign in to your account
op signin

# Run setup (will store in 1Password vault)
./setup_signing_keyring.sh
```

## Security Benefits

### Passwords Never in Files
- ✅ No plaintext passwords in `key.properties`
- ✅ No passwords in version control
- ✅ No accidental password exposure in logs

### Encrypted Storage
- 🔐 **GNOME Keyring**: AES encryption tied to user login
- 🔐 **macOS Keychain**: Hardware-backed encryption when available
- 🔐 **1Password/Bitwarden**: Zero-knowledge architecture
- 🔐 **pass**: GPG encryption with your personal key

## Commands Reference

### Setup and Configuration
```bash
./setup_signing_keyring.sh    # Interactive keyring-based setup
./setup_signing.sh            # Manual setup (fallback)
./validate_signing.sh         # Validate current configuration
```

### Testing
```bash
flutter build apk --release          # Test release build
flutter build appbundle --release    # Test app bundle build
```

## Benefits Summary

### For Individual Developers
- 🚀 **No more password typing** - stored securely in system keyring
- 🔒 **Better security** - encrypted storage, no plaintext passwords
- ⚡ **Faster setup** - automated credential management
- 🛡️ **No accidental exposure** - passwords never in files or logs

### For Teams
- 👥 **Consistent setup** - standardized across team members
- 📋 **Easy onboarding** - new team members follow same process
- 🔄 **Flexible backends** - teams can choose their preferred tools
- 🏢 **Enterprise ready** - works with company password managers
