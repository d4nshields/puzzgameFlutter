# App Rebranding: Puzzle Bazaar to Puzzle Nook

## Date
July 15, 2025

## Overview
This document records the architectural decision to rebrand the application from "Puzzle Bazaar" to "Puzzle Nook" and change the package identifier from `com.tinkerplexlabs.puzzlebazaar` to `com.tinkerplexlabs.puzzlenook`.

## Context
The application was previously rebranded from "Nook" to "Puzzle Bazaar" in May 2025. However, a decision has been made to revert to a "Nook"-style branding for better market positioning and brand consistency.

## Decision
Rename the application to "Puzzle Nook" with the following changes:

### Package/Bundle Identifiers
- **Previous**: `com.tinkerplexlabs.puzzlebazaar`
- **New**: `com.tinkerplexlabs.puzzlenook`

### Application Display Names
- **Previous**: "Puzzle Bazaar"
- **New**: "Puzzle Nook"

## Files Modified

### Flutter Source Code
- `lib/main.dart` - Updated app title, class names (PuzzleNookGameApp), and widget references
- `lib/presentation/screens/home_screen.dart` - Updated app bar title, welcome message, and about dialog
- All user-facing text changed from "Puzzle Bazaar" to "Puzzle Nook"

### Test Files
- `test/widget/home_screen_test.dart` - Updated test expectations for new app name
- `integration_test/app_test.dart` - Updated integration test expectations for new welcome message

### Core Configuration
- `pubspec.yaml` - Updated app description
- `README.md` - Updated project title and description

### Android Platform
- `android/app/build.gradle.kts` - Updated namespace and applicationId
- `android/app/src/main/AndroidManifest.xml` - Updated app label and activity name
- `android/app/src/main/kotlin/com/tinkerplexlabs/puzzlenook/MainActivity.kt` - Created new package structure
- Removed old package: `android/app/src/main/kotlin/com/tinkerplexlabs/puzzlebazaar/`

### iOS Platform
- `ios/Runner/Info.plist` - Updated CFBundleDisplayName and CFBundleName
- `ios/Runner.xcodeproj/project.pbxproj` - Updated PRODUCT_BUNDLE_IDENTIFIER for all build configurations:
  - Debug, Release, and Profile configurations for main app
  - Debug, Release, and Profile configurations for RunnerTests

### Documentation
- `docs/github_actions_puzzle_bazaar_setup.md` - Updated title and references
- `docs/puzzle_bazaar_keystore_generation.md` - Updated title and app ID references
- `docs/puzzle_bazaar_rebranding_summary.md` - Updated to reflect new rebranding

## Consequences

### Positive
1. **Brand Consistency**: "Puzzle Nook" provides a more cozy, welcoming brand identity
2. **Clean Architecture**: Package structure follows standard conventions
3. **Platform Consistency**: Both Android and iOS use consistent identifiers

### Considerations
1. **App Store Impact**: If the app was previously published, this change will require:
   - New app store listing (new package ID means new app)
   - User migration strategy if needed
   - Updated signing certificates and provisioning profiles

2. **Development Impact**: 
   - Clean rebuilds required
   - IDE project configurations may need refresh
   - Any hardcoded references in external tools need updating

## Implementation Notes

### Android Package Migration
The Android package structure was migrated from:
```
com/tinkerplexlabs/puzzlebazaar/MainActivity.kt
```
to:
```
com/tinkerplexlabs/puzzlenook/MainActivity.kt
```

The MainActivity class package declaration was updated accordingly.

### iOS Bundle Identifier Migration
iOS bundle identifiers were updated in all build configurations:
- Main app: `com.tinkerplexlabs.puzzlenook`
- Test target: `com.tinkerplexlabs.puzzlenook.RunnerTests`

### Testing Requirements
After this change, the following should be verified:
1. Clean build and run on both Android and iOS
2. App signing works correctly with new identifiers
3. App installation and uninstallation work properly
4. No conflicts with previously installed versions

## Next Steps
1. Update any CI/CD pipeline configurations
2. Update signing certificates and provisioning profiles
3. Test app deployment to ensure new package ID works correctly
4. Update any external integrations that reference the old package ID
5. Consider updating keystore documentation with new package references

## Related Files
- This document: `docs/app_rebranding_puzzlebazaar_to_puzzlenook.md`
- Previous rebranding: `docs/puzzle_bazaar_rebranding_summary.md`
- Keystore guide: `docs/puzzle_bazaar_keystore_generation.md`
