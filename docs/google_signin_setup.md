# Google Sign-In Setup for Puzzle Bazaar

## Android Setup

### 1. Configure SHA-1 Certificate Fingerprint

First, get your debug SHA-1 certificate:

```bash
# For debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# For release keystore (use your actual keystore path)
keytool -list -v -keystore path/to/your/release.keystore -alias your-key-alias
```

### 2. Configure in Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to Authentication > Providers
3. Enable Google provider
4. Add your Android package name: `com.puzzlebazaar.puzzgame_flutter`
5. Add your SHA-1 certificate fingerprints (both debug and release)

### 3. Download google-services.json

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project or use existing
3. Add an Android app with package name: `com.puzzlebazaar.puzzgame_flutter`
4. Download `google-services.json`
5. Place it in `android/app/google-services.json`

### 4. Update Android Configuration

The Android configuration files need to be updated to support Google Sign-In.

## iOS Setup (Future)

When you're ready for iOS:

1. Configure OAuth consent screen in Google Cloud Console
2. Create iOS OAuth client ID
3. Download `GoogleService-Info.plist`
4. Add to iOS project
5. Configure URL schemes

## Web Setup (if needed)

For web support:
1. Create OAuth 2.0 Web Client ID in Google Cloud Console
2. Add authorized redirect URIs
3. Update `SupabaseAuthService` with the web client ID

## Testing

Run the app and test the Google Sign-In flow:

```bash
flutter run
```

The sign-in button appears in the top-right corner of the home screen.
