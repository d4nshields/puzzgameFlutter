# Nook Alpha Release - Remaining Steps Checklist

This checklist focuses on the specific remaining tasks needed to publish your Nook game as an alpha release on Google Play.

## 1. App Signing Setup

- [ ] **Create Signing Key**
  ```bash
  keytool -genkey -v -keystore ~/nook-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nook
  ```
  - [ ] Store passwords securely (password manager recommended)
  - [ ] Back up keystore file in a safe location

- [ ] **Configure Signing in Project**
  - [ ] Create `android/key.properties` file with:
    ```
    storePassword=your-keystore-password
    keyPassword=your-key-password
    keyAlias=nook
    storeFile=/absolute/path/to/nook-keystore.jks
    ```
  - [ ] Update `android/app/build.gradle.kts` with signing configuration (see instructions in `docs/signing_key_instructions.md`)
  - [ ] Add `**/android/key.properties` to `.gitignore`

## 2. Take Game Screenshots

- [ ] **Capture Game Screens**
  - [ ] Home screen
  - [ ] Game play screen
  - [ ] Settings screen
  - [ ] Any other important screens
  - [ ] Ensure 16:9 aspect ratio (e.g., 1920x1080)
  - [ ] Save in PNG format

## 3. Build Release Version

- [ ] **Prepare for Release Build**
  - [ ] Ensure all assets are in place (icon and splash screen)
  - [ ] Update pubspec.yaml if needed
  - [ ] Run `flutter pub get` to update dependencies

- [ ] **Build App Bundle**
  ```bash
  cd /home/daniel/work/puzzgameFlutter
  flutter build appbundle
  ```
  - [ ] Verify file exists at `build/app/outputs/bundle/release/app-release.aab`

- [ ] **Test Release Build** (optional but recommended)
  ```bash
  flutter build apk --release
  flutter install
  ```
  - [ ] Verify app works correctly in release mode
  - [ ] Check for any performance issues

## 4. Google Play Console Setup

- [ ] **Create Developer Account** (if not already done)
  - [ ] Go to [play.google.com/console/signup](https://play.google.com/console/signup)
  - [ ] Pay $25 registration fee
  - [ ] Complete account setup

- [ ] **Host Privacy Policy Online**
  - [ ] Upload the privacy policy document (`docs/privacy_policy.md`) to a web hosting service
  - [ ] Get the public URL for the policy

- [ ] **Create New App in Play Console**
  - [ ] Fill in basic details (name, app type, free/paid)

## 5. Complete Store Listing

- [ ] **Required Text**
  - [ ] Short description (80 characters max)
  - [ ] Full description (4000 characters max)
  - [ ] Privacy policy URL

- [ ] **Upload Graphics Assets**
  - [ ] App icon (512x512) - already prepared
  - [ ] Feature graphic (1024x500) - already prepared at `/home/daniel/work/puzzgameFlutter/assets/images/feature-1024.png`
  - [ ] At least 2 screenshots (taken in step 2)

- [ ] **Categorization and Content Rating**
  - [ ] Select app category (Games > Puzzle)
  - [ ] Complete content rating questionnaire

## 6. Set Up Alpha Testing

- [ ] **Create Testing Track**
  - [ ] Go to "Testing" > "Internal testing" in Play Console
  - [ ] Create a new release
  - [ ] Upload your AAB file

- [ ] **Add Testers**
  - [ ] Create list of tester email addresses
  - [ ] Add testers to the internal testing track
  - [ ] Prepare instructions for testers

## 7. Submit for Review

- [ ] **Final Verification**
  - [ ] Review all details for accuracy
  - [ ] Check for any missing required information

- [ ] **Submit Release**
  - [ ] Click "Submit for review"
  - [ ] Monitor review status (typically 1-3 days)

## 8. Post-Approval

- [ ] **Distribute to Testers**
  - [ ] Notify testers when the app is available
  - [ ] Share installation instructions

- [ ] **Feedback Collection**
  - [ ] Set up system to collect tester feedback (email, form, etc.)
  - [ ] Define process for prioritizing feedback

## Notes

- Keep a copy of your signing key secure - losing it means you cannot update your app later
- Make sure your testers understand this is an alpha version and what feedback you want
- Be prepared to make quick updates based on initial feedback
- The alpha track is not visible to the public, only to invited testers

**Minimum Required Items for First Submission:**
- App Bundle (AAB file)
- App Icon
- Feature Graphic
- Privacy Policy URL
- At least 2 screenshots
