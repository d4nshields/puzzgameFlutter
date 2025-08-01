# Fix for Integration Test Plugin Build Error

## Issue
The Flutter build was failing with:
```
error: package dev.flutter.plugins.integration_test does not exist
```

## Root Cause
Flutter incorrectly included the `integration_test` plugin (which should only be used during testing) in the generated plugin registrant for regular app builds.

## Solution Applied

### 1. Immediate Fix
- Manually removed the integration_test plugin registration from:
  `/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`

### 2. Clean Build Process
- Created `clean_and_rebuild.sh` script for thorough project cleanup
- This removes cached Flutter and Gradle build artifacts

### 3. Prevention
The issue occurs when Flutter's plugin registration generation gets confused about dev vs regular dependencies. To prevent this:

1. Always run `flutter clean` after adding new dependencies
2. Use the clean rebuild script when switching between test and regular builds
3. If the error reappears, manually remove the integration_test line from GeneratedPluginRegistrant.java

## Build Process
```bash
# Clean everything
./clean_and_rebuild.sh

# Or manually:
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..

# Then build normally
flutter run
# or
flutter build apk
```

## File Modified
- `/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` - Removed integration_test plugin registration

## Note
The GeneratedPluginRegistrant.java file is auto-generated by Flutter, so this manual fix may need to be reapplied if Flutter regenerates the file incorrectly again. The clean build process should prevent this from happening.
