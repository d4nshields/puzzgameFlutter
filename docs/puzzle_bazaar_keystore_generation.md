# Keystore Generation Guide for Puzzle Bazaar

## Overview
This guide provides step-by-step instructions for generating a new PKCS12 (.p12) keystore for the Puzzle Bazaar app with the new TinkerPlex Labs organization identity and app ID `com.tinkerplexlabs.puzzlebazaar`.

---

## Prerequisites

- Java Development Kit (JDK) installed
- `keytool` command available in your PATH
- Secure location for storing keystore files

---

## Step 1: Generate the Upload Keystore

### Command
```bash
keytool -genkey -v \\
  -keystore upload-keystore-puzzlebazaar.p12 \\
  -storetype PKCS12 \\
  -keyalg RSA \\
  -keysize 2048 \\
  -validity 10000 \\
  -alias upload
```

### Parameter Explanation
- **`-keystore upload-keystore-puzzlebazaar.p12`**: Output filename for the new keystore
- **`-storetype PKCS12`**: Modern keystore format (preferred over JKS)
- **`-keyalg RSA`**: Use RSA encryption algorithm
- **`-keysize 2048`**: Key size in bits (2048 is standard, secure)
- **`-validity 10000`**: Certificate valid for ~27 years
- **`-alias upload`**: Alias name for the key within the keystore

---

## Step 2: Certificate Information

When prompted, enter the following information for TinkerPlex Labs:

```
What is your first and last name?
[Unknown]: Dan Shields

What is the name of your organizational unit?
[Unknown]: Development Division

What is the name of your organization?
[Unknown]: TinkerPlex Labs

What is the name of your City or Locality?
[Unknown]: Whitby

What is the name of your State or Province?
[Unknown]: ON

What is the two-letter country code for this unit?
[Unknown]: CA

Is CN=Dan Shields, OU=Development Division, O=TinkerPlex Labs, L=Whitby, ST=ON, C=CA correct?
[no]: yes

Enter keystore password:
Re-enter new password:

Enter key password for <upload>
(RETURN if same as keystore password):
```

### Password Guidelines
- Use a **strong, unique password** (at least 12 characters)
- Include uppercase, lowercase, numbers, and symbols
- **Document the password securely** in a password manager
- Consider using the same password for both keystore and key for simplicity

---

## Step 3: Verify the New Keystore

After generation, verify the keystore was created correctly:

```bash
keytool -list -v -keystore upload-keystore-puzzlebazaar.p12
```

**Expected Output:**
```
Keystore type: PKCS12
Keystore provider: SUN

Your keystore contains 1 entry

Alias name: upload
Creation date: [Current Date]
Entry type: PrivateKeyEntry
Certificate chain length: 1
Certificate[1]:
Owner: CN=Dan Shields, OU=Development Division, O=TinkerPlex Labs, L=Whitby, ST=ON, C=CA
Issuer: CN=Dan Shields, OU=Development Division, O=TinkerPlex Labs, L=Whitby, ST=ON, C=CA
Serial number: [Generated Number]
Valid from: [Start Date] until: [End Date ~27 years later]
Certificate fingerprints:
         SHA1: [Fingerprint]
         SHA256: [Fingerprint]
Signature algorithm name: SHA384withRSA
Subject Public Key Algorithm: 2048-bit RSA key
Version: 3
```

---

## Step 4: Create/Update key.properties File

Create or update the file `/home/daniel/work/puzzgameFlutter/android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD  
keyAlias=upload
storeFile=../upload-keystore-puzzlebazaar.p12
```

**Important Notes:**
- Replace `YOUR_KEYSTORE_PASSWORD` and `YOUR_KEY_PASSWORD` with actual passwords
- The `storeFile` path is relative to the `android/app` directory
- **Never commit this file to version control** (should be in `.gitignore`)

---

## Step 5: Backup Your Keystore

### Create Multiple Backups
```bash
# Create a backup copy
cp upload-keystore-puzzlebazaar.p12 upload-keystore-puzzlebazaar-backup.p12

# Create a base64 encoded version for secure storage
base64 upload-keystore-puzzlebazaar.p12 > upload-keystore-puzzlebazaar.p12.base64
```

### Storage Recommendations
1. **Local secure storage** (encrypted drive/folder)
2. **Cloud storage** (encrypted, private)
3. **Password manager** (for the base64 version)
4. **Physical backup** (USB drive in secure location)

---

## Step 6: Update Build Configuration

The Android build configuration has already been updated during the rebranding to reference the new keystore location. Verify that `android/app/build.gradle.kts` contains:

```kotlin
// Load key.properties file if it exists
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

And the signing configuration:
```kotlin
signingConfigs {
    if (keystorePropertiesFile.exists()) {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
}
```

---

## Step 7: Test the Setup

### Build a Release App Bundle
```bash
cd /home/daniel/work/puzzgameFlutter
flutter clean
flutter pub get
flutter build appbundle --release
```

### Expected Result
- App bundle created successfully at: `build/app/outputs/bundle/release/app-release.aab`
- No signing errors in the build output
- App bundle is signed with your new keystore

### Build a Release APK (for local testing)
```bash
flutter build apk --release
```

---

## Troubleshooting

### Common Issues

**1. "keytool: command not found"**
- Ensure JDK is installed and `JAVA_HOME` is set
- Add JDK bin directory to your PATH

**2. "keystore was tampered with, or password was incorrect"**
- Verify password in `key.properties` matches what you set
- Check that keystore file path is correct

**3. "Could not read key ... from store"**
- Verify `keyAlias` in `key.properties` matches what you used (should be "upload")
- Ensure key password is correct

**4. Build fails with signing errors**
- Check that `key.properties` file exists and is readable
- Verify all paths in `key.properties` are correct relative to android/ directory

---

## Security Best Practices

1. **Never share your keystore file or passwords**
2. **Store backups in multiple secure locations**
3. **Use strong, unique passwords**
4. **Never commit key.properties to version control**
5. **Regularly verify backups are intact**
6. **Consider using a hardware security module for production**

---

## Google Play Console Setup

When uploading to Google Play Console for the first time:

1. **Create a new app** (this will be treated as completely separate from the old Nook app)
2. **Set package name** to `com.tinkerplexlabs.puzzlebazaar`
3. **Enroll in Google Play App Signing** (mandatory for new apps)
4. **Upload your signed app bundle**
5. **Google will extract your upload certificate** and generate their own app signing key

**Important:** Save the upload certificate fingerprint that Google shows you - you'll need it if you ever need to reset your upload key.

---

## Migration Notes

- **This is a NEW app**: Google Play will treat this as completely separate from `org.shields.apps.nook`
- **No data migration**: Users will need to download the new app separately
- **Fresh start**: Reviews, ratings, and download counts start from zero
- **Different permissions**: Users will need to grant permissions to the new app

---

*This keystore will be used for all future releases of Puzzle Bazaar under the TinkerPlex Labs organization.*
