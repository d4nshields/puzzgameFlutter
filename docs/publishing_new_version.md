# Rebuilding and Publishing - Version 0.1.1

I've updated your app to version 0.1.1 (versionCode 2) and created a script to help with version increments in the future. Here are the steps to rebuild and publish your fixed app:

## Step 1: Make the Version Script Executable

```bash
chmod +x /home/daniel/work/puzzgameFlutter/increment_version.sh
```

## Step 2: Clean and Rebuild

```bash
cd /home/daniel/work/puzzgameFlutter
flutter clean
flutter pub get
```

## Step 3: Test the Build Locally

```bash
flutter build apk --release
flutter install
```

Verify that the app works and doesn't crash on launch.

## Step 4: Build the App Bundle

```bash
flutter build appbundle
```

The bundle will be created at:
`/home/daniel/work/puzzgameFlutter/build/app/outputs/bundle/release/app-release.aab`

## Step 5: Create a New Release in Google Play Console

1. Log into the Google Play Console
2. Go to your app > Testing > Internal testing
3. Create a new release
4. Upload the new AAB file 
5. Add release notes explaining the fix:
   ```
   Bug fix: Resolved app crash on launch
   - Fixed package name issues
   - Updated MainActivity location
   ```
6. Save and review the release
7. Submit for review

## For Future Version Updates

Whenever you need to increment the version number in the future, just run:

```bash
# For patch version updates (0.1.1 -> 0.1.2):
./increment_version.sh patch

# For minor version updates (0.1.1 -> 0.2.0):
./increment_version.sh minor

# For major version updates (0.1.1 -> 1.0.0):
./increment_version.sh major
```

This will automatically update both:
- `version` in pubspec.yaml
- `versionCode` and `versionName` in build.gradle.kts

After running the script, follow steps 2-5 above to build and publish.

## Current Version Info

- Version Name: 0.1.1
- Version Code: 2
- Previous Version: 0.1.0 (Code 1)

## Notes About Version Numbers

- **Version Code**: Must be incremented by at least 1 for each release
- **Version Name**: Follows semantic versioning (MAJOR.MINOR.PATCH)
  - MAJOR: Breaking changes
  - MINOR: New features, backward compatible
  - PATCH: Bug fixes, backward compatible
