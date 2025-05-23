# App Signing Guide for Nook

This guide explains how to handle app signing for both Google Play uploads and local debugging with Android Studio.

## Understanding the Different Keys

For your app with ID `org.shields.apps.nook`, you'll be working with two different signing setups:

1. **Google Play App Signing Key**: 
   - Managed by Google
   - Used to sign the APKs delivered to users
   - You don't have direct access to this key

2. **Upload Key**:
   - Managed by you
   - Used to authenticate your app uploads to Google Play
   - Will be enrolled in Google Play App Signing when you first upload

3. **Debug Key**:
   - Used automatically by Android Studio for debug builds
   - Located in your home directory (`~/.android/debug.keystore`)
   - Password is typically "android"

## Setting Up Your Upload Key

### Step 1: Generate a New Upload Key

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Step 2: Create key.properties File

Copy the template file and edit it with your actual key information:

```bash
cp /home/daniel/work/puzzgameFlutter/android/key.properties.template /home/daniel/work/puzzgameFlutter/android/key.properties
```

Edit the file to include your actual keystore path and passwords.

## Building for Different Purposes

### For Local Testing/Debugging from Android Studio

Use the debug configuration:

```bash
flutter run
# or
flutter install
```

This will use the debug keystore automatically.

### For Google Play Upload

Build an app bundle signed with your upload key:

```bash
flutter build appbundle
```

The AAB will be located at:
`/home/daniel/work/puzzgameFlutter/build/app/outputs/bundle/release/app-release.aab`

## First-Time Play Store Upload Process

When you upload your app for the first time:

1. Create a new app in the Google Play Console
2. Set the package name to `org.shields.apps.nook`
3. When prompted, enroll in Google Play App Signing (mandatory for new apps)
4. Follow the prompts to upload your app bundle

Google will:
- Extract your upload certificate from the app bundle
- Generate a new app signing key that they will manage
- Use your upload key to verify future uploads

## If You Need to Install a Release Build Locally

You can build a release APK signed with your upload key:

```bash
flutter build apk --release
flutter install
```

## Key Management Best Practices

1. **Back up your upload keystore file** in multiple secure locations
2. **Remember your keystore and key passwords**
3. **Document your key details** in a secure password manager
4. **Never share your upload key** with unauthorized parties

## Troubleshooting

If you encounter installation conflicts due to different signatures:

1. Uninstall the existing app from your device first:
   ```bash
   adb uninstall org.shields.apps.nook
   ```

2. Then install the new version:
   ```bash
   flutter install
   ```

This is normal when switching between debug builds (from Android Studio) and release builds (from Play Store).
