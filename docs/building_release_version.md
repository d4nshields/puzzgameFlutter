# Building a Release Version for Google Play Store

This guide walks you through the process of building a release version of your Nook app for submission to the Google Play Store.

## Prerequisites
- Completed the signing key setup (see `signing_key_instructions.md`)
- Updated the application ID to a unique value (com.yourdomain.nook)
- Tested your app thoroughly in debug mode

## Building an App Bundle (Recommended)

Google Play's preferred submission format is an Android App Bundle (AAB). This allows Google Play to generate optimized APKs for different device configurations.

```bash
# Navigate to your project directory
cd /home/daniel/work/puzzgameFlutter

# Ensure you have the latest dependencies
flutter pub get

# Build the release App Bundle
flutter build appbundle

# The bundle will be created at:
# build/app/outputs/bundle/release/app-release.aab
```

## Building an APK (Alternative)

If you need an APK (for testing or other distribution channels):

```bash
# Build a release APK
flutter build apk --release

# The APK will be created at:
# build/app/outputs/flutter-apk/app-release.apk

# For split APKs optimized by ABI
flutter build apk --split-per-abi --release
# This creates three APKs:
# - build/app/outputs/apk/release/app-armeabi-v7a-release.apk
# - build/app/outputs/apk/release/app-arm64-v8a-release.apk
# - build/app/outputs/apk/release/app-x86_64-release.apk
```

## Testing the Release Build

Before uploading to Google Play, test your release build:

1. Using an APK:
   ```bash
   flutter install
   ```

2. Or manually install the APK:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

3. Verify that:
   - The app launches correctly with the Nook splash screen
   - All functionality works as expected
   - The app icon appears correctly
   - The app name shows as "Nook"

## Troubleshooting Common Issues

- **App crashes on launch in release mode**: Check for missing release configurations or ProGuard rules
- **Splash screen doesn't show**: Verify flutter_native_splash configuration
- **Images or assets missing**: Check that assets are properly referenced in pubspec.yaml
- **Performance issues**: Test on lower-tier devices if possible

## Final Checklist Before Publishing

- [ ] App launches and functions correctly
- [ ] App icon displays properly
- [ ] Splash screen works
- [ ] Version code and version name are correct
- [ ] Application ID is unique (not com.example.*)
- [ ] Signing configuration is properly set up
