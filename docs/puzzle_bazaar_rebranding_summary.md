# Puzzle Bazaar Rebranding Summary

## Overview
This document summarizes all changes made during the rebranding from "Nook" to "Puzzle Bazaar" and the app ID change from `org.shields.apps.nook` to `com.tinkerplexlabs.puzzlebazaar`.

**Date:** May 31, 2025  
**Previous Name:** Nook  
**New Name:** Puzzle Bazaar  
**Previous App ID:** org.shields.apps.nook  
**New App ID:** com.tinkerplexlabs.puzzlebazaar  

---

## Files Changed

### Core Application Files

#### 1. `pubspec.yaml`
- **Change:** Updated description
- **Before:** `"Nook - A Flutter-based puzzle game app with hexagonal architecture."`
- **After:** `"Puzzle Bazaar - A Flutter-based puzzle game app with hexagonal architecture."`

#### 2. `lib/main.dart`
- **Changes:**
  - Renamed class `NookGameApp` → `PuzzleBazaarGameApp`
  - Updated app title from `'Nook'` → `'Puzzle Bazaar'`

#### 3. `README.md`
- **Changes:**
  - Updated title: `"# Nook Game"` → `"# Puzzle Bazaar Game"`
  - Updated project description references

---

### Game Module Files

#### 4. `lib/game_module/nook_game_module.dart` → `lib/game_module/puzzle_bazaar_game_module.dart`
- **File Renamed:** Complete file rename
- **Class Changes:**
  - `NookGameModule` → `PuzzleBazaarGameModule`
  - `NookGameSession` → `PuzzleBazaarGameSession`
- **String Updates:** All debug print statements updated to use new class names
- **Comments:** Updated class documentation to reference "Puzzle Bazaar game"

#### 5. `lib/core/infrastructure/service_locator.dart`
- **Changes:**
  - Updated import: `puzzle_game_module.dart` → `puzzle_bazaar_game_module.dart`
  - Updated registration: `PuzzleGameModule()` → `PuzzleBazaarGameModule()`
  - Updated comment to reference new module name

---

### Android Configuration

#### 6. `android/app/build.gradle.kts`
- **Changes:**
  - `namespace = "org.shields.apps.nook"` → `namespace = "com.tinkerplexlabs.puzzlebazaar"`
  - `applicationId = "org.shields.apps.nook"` → `applicationId = "com.tinkerplexlabs.puzzlebazaar"`

#### 7. `android/app/src/main/AndroidManifest.xml`
- **Changes:**
  - `android:label="Nook"` → `android:label="Puzzle Bazaar"`
  - `android:name="org.shields.apps.nook.MainActivity"` → `android:name="com.tinkerplexlabs.puzzlebazaar.MainActivity"`

#### 8. Package Directory Structure
- **Old:** `/android/app/src/main/kotlin/org/shields/apps/nook/`
- **New:** `/android/app/src/main/kotlin/com/tinkerplexlabs/puzzlebazaar/`
- **Files Moved:** `MainActivity.kt` (with updated package declaration)

#### 9. `MainActivity.kt`
- **Change:** Package declaration updated from `org.shields.apps.nook` → `com.tinkerplexlabs.puzzlebazaar`

#### 12. `.github/workflows/deploy.yml`
- **Changes:**
  - Updated package name: `org.shields.apps.nook` → `com.tinkerplexlabs.puzzlebazaar`
  - Updated keystore filename: `keystore.jks` → `upload-keystore-puzzlebazaar.p12`
  - Updated storeFile reference in key.properties generation

#### 13. `lib/presentation/screens/home_screen.dart`
- **Changes:**
  - Updated app bar title: `'Nook'` → `'Puzzle Bazaar'`
  - Updated welcome text: `'Welcome to Nook!'` → `'Welcome to Puzzle Bazaar!'`
  - Updated about dialog application name: `'Nook'` → `'Puzzle Bazaar'`

#### 14. `test/unit/game_module_test.dart`
- **Changes:**
  - Updated import: `nook_game_module.dart` → `puzzle_bazaar_game_module.dart`
  - Updated class references: `NookGameModule` → `PuzzleBazaarGameModule`
  - Updated class references: `NookGameSession` → `PuzzleBazaarGameSession`
  - Updated test group names to reflect new class names

#### 15. `test/widget/home_screen_test.dart`
- **Changes:**
  - Updated expected text: `'Welcome to Nook!'` → `'Welcome to Puzzle Bazaar!'`
  - Updated expected app bar title: `'Nook'` → `'Puzzle Bazaar'`
  - Updated dialog text expectations to match new name

---

### iOS Configuration

#### 10. `ios/Runner/Info.plist`
- **Changes:**
  - `CFBundleDisplayName`: `"Nook"` → `"Puzzle Bazaar"`
  - `CFBundleName`: `"Nook"` → `"Puzzle Bazaar"`

#### 11. `ios/Runner.xcodeproj/project.pbxproj`
- **Changes:** Updated all `PRODUCT_BUNDLE_IDENTIFIER` entries:
  - Main app: `com.example.puzzgameFlutter` → `com.tinkerplexlabs.puzzlebazaar`
  - Test target: `com.example.puzzgameFlutter.RunnerTests` → `com.tinkerplexlabs.puzzlebazaar.RunnerTests`

---

## Symbol/Class Naming Patterns Used

### Naming Conventions Applied:
- **Class Names (PascalCase):** `PuzzleBazaarGameModule`, `PuzzleBazaarGameSession`, `PuzzleBazaarGameApp`
- **File Names (snake_case):** `puzzle_bazaar_game_module.dart`
- **Variables/Methods (camelCase):** `puzzleBazaarGameModule` (when used as variables)
- **Package Names (lowercase with dots):** `com.tinkerplexlabs.puzzlebazaar`

### Transformation Pattern:
- "Nook" → "PuzzleBazaar" (in code symbols)
- "Nook" → "Puzzle Bazaar" (in user-visible strings)

---

## Directory Changes

### Old Directory Structure (Removed/Deprecated):
```
android/app/src/main/kotlin/org/shields/apps/nook/
├── MainActivity.kt
```

### New Directory Structure (Created):
```
android/app/src/main/kotlin/com/tinkerplexlabs/puzzlebazaar/
├── MainActivity.kt
```

---

## Required Post-Rebranding Actions

### 1. **New Keystore Generation Required**
Since the app ID changed, a completely new keystore must be generated for the new app:

```bash
keytool -genkey -v \\
  -keystore upload-keystore-puzzlebazaar.p12 \\
  -storetype PKCS12 \\
  -keyalg RSA \\
  -keysize 2048 \\
  -validity 10000 \\
  -alias upload
```

**Organization Details for New Keystore:**
- **Name:** Dan Shields
- **Organizational Unit:** Development Division  
- **Organization:** TinkerPlex Labs
- **City:** Whitby
- **State:** ON
- **Country:** CA

### 2. **Update key.properties File**
Create/update `android/key.properties`:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD  
keyAlias=upload
storeFile=../upload-keystore-puzzlebazaar.p12
```

### 3. **Google Play Console**
- This will be treated as a **completely new app** in Google Play Console
- Old app (org.shields.apps.nook) and new app (com.tinkerplexlabs.puzzlebazaar) are separate
- New app listing, store page, and reviews will start fresh

### 4. **GitHub Actions Update Required**
Update repository secrets and Google Play Console setup:
- Generate base64 of new P12 keystore: `base64 upload-keystore-puzzlebazaar.p12`
- Update GitHub secret `KEYSTORE_BASE64` with new keystore
- Create new Google Play Console app with package `com.tinkerplexlabs.puzzlebazaar`
- Create new service account for GitHub Actions API access
- Update GitHub secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- Test workflow with internal release

### 5. **Clean Build Required**
After these changes, perform a clean build:
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

---

## Files NOT Changed

These files were examined but did not require changes:
- Test files (no direct references to old naming)
- Asset files (image assets retain their current names)
- Most configuration files that don't reference app ID or display name
- Dependency specifications in pubspec.yaml

---

## Notes

1. **iOS Bundle Identifier:** Updated from placeholder `com.example.puzzgameFlutter` to proper `com.tinkerplexlabs.puzzlebazaar`
2. **Backwards Compatibility:** None - this is a complete rebrand with new app ID
3. **Store Presence:** Will require new app store listings on both Google Play and Apple App Store
4. **User Data:** Any existing user data from the old app will not carry over automatically

---

## Verification Checklist

- [ ] Build Android app bundle successfully
- [ ] Build iOS app successfully (if iOS development is set up)
- [ ] App displays "Puzzle Bazaar" in title and system UI
- [ ] Debug logs show new class names (PuzzleBazaarGameModule, etc.)
- [ ] App ID appears correctly in build outputs
- [ ] New keystore generated and configured
- [ ] Test installation on device confirms new package name

---

## Key Documentation Files

- `/docs/puzzle_bazaar_rebranding_summary.md` - This complete change summary
- `/docs/puzzle_bazaar_keystore_generation.md` - Step-by-step P12 keystore generation guide
- `/docs/github_actions_puzzle_bazaar_setup.md` - GitHub Actions and Google Play Console setup guide

---

*This document serves as a complete record of the rebranding changes made to transform the Nook game into Puzzle Bazaar with the new TinkerPlex Labs organization identity.*
