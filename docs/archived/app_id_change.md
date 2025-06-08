# App ID Change: org.shields.nook → org.shields.apps.nook

This document outlines the changes made to the app ID and provides instructions for rebuilding the app.

## Changes Made:

1. **Updated Application ID/Package Name**:
   - Changed from `org.shields.nook` to `org.shields.apps.nook`
   - Updated in `build.gradle.kts`
   - Updated in `AndroidManifest.xml`

2. **Created New Package Structure**:
   - Added `org/shields/apps/nook` directory structure
   - Moved `MainActivity.kt` to the new package location
   - Updated package declaration in `MainActivity.kt`

3. **Reset Version Numbers**:
   - Since this is considered a new app, versions have been reset:
     - `versionCode = 1` (in build.gradle.kts)
     - `versionName = "0.1.0"` (in build.gradle.kts)
     - `version = "0.1.0+1"` (in pubspec.yaml)

## Rebuilding Instructions:

1. **Clean the project**:
   ```bash
   cd /home/daniel/work/puzzgameFlutter
   flutter clean
   ```

2. **Get dependencies**:
   ```bash
   flutter pub get
   ```

3. **Validate the configuration**:
   ```bash
   flutter doctor
   ```

4. **Build a debug version to test**:
   ```bash
   flutter run
   ```

5. **Build the release version**:
   ```bash
   flutter build appbundle
   ```

6. **Create a new app in Google Play Console**:
   - Since the app ID has changed, this will be treated as a completely new app in the Play Store
   - Set up a new app in the Google Play Console with the ID `org.shields.apps.nook`
   - Upload the new AAB file to the internal testing track

## Important Notes:

- Users of the old app (if any) will not automatically get this new app as an update
- You will need to re-upload all assets and descriptions to the Play Store for this new app listing
- Consider adding a note in the old app's description informing users about the new app if needed

The file location for the new app bundle will be:
`/home/daniel/work/puzzgameFlutter/build/app/outputs/bundle/release/app-release.aab`
