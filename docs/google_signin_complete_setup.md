# Complete Google Sign-In Setup Guide for Puzzle Bazaar

## Part 1: Get Your SHA-1 Fingerprint

### Step 1: Open Terminal
Navigate to your project directory:
```bash
cd /home/daniel/work/puzzgameFlutter
```

### Step 2: Get Debug SHA-1
Run this command to get your debug SHA-1:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Look for the line that says `SHA1:` and copy the fingerprint (it looks like: `XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX`)

### Step 3: Get Release SHA-1 (if you have a release keystore)
```bash
keytool -list -v -keystore android/app/puzzlebazaar-keystore.p12 -storetype PKCS12
```
Enter your keystore password when prompted.

Save both SHA-1 fingerprints in a text file - you'll need them.

## Part 2: Configure Supabase

### Step 1: Open Supabase Dashboard
1. Go to https://supabase.com/dashboard
2. Select your "core" project
3. Navigate to **Authentication** (shield icon) in the left sidebar

### Step 2: Enable Google Provider
1. Click on **Providers** tab
2. Find **Google** in the list
3. Toggle it **ON**
4. You'll see configuration fields appear

### Step 3: Configure Google Provider Settings
For now, just enable it. We'll come back after setting up Firebase.

## Part 3: Set Up Firebase Project

### Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com
2. Click **Add project**
3. Name it: `puzzle-bazaar` (or similar)
4. **Disable Google Analytics** (not needed)
5. Click **Create project**

### Step 2: Add Android App
1. In Firebase console, click the **Android icon** to add an Android app
2. Fill in:
   - **Android package name**: `com.tinkerplexlabs.puzzlebazaar`
   - **App nickname**: Puzzle Bazaar
   - **Debug signing certificate SHA-1**: Paste your debug SHA-1 from Part 1
3. Click **Register app**

### Step 3: Download google-services.json
1. Click **Download google-services.json**
2. Save the file
3. Copy it to your project:
   ```bash
   cp ~/Downloads/google-services.json /home/daniel/work/puzzgameFlutter/android/app/
   ```

### Step 4: Skip Remaining Firebase Steps
Click **Next** through the remaining steps - we've already configured the Gradle files.

### Step 5: Add Release SHA-1 (if applicable)
1. In Firebase Console, go to **Project settings** (gear icon)
2. Under **Your apps**, find your Android app
3. Click **Add fingerprint**
4. Add your release SHA-1

## Part 4: Get OAuth 2.0 Client ID

### Step 1: Go to Google Cloud Console
1. Firebase automatically created a Google Cloud project
2. Click the link in Firebase Console that says **Google Cloud Console** or go to:
   https://console.cloud.google.com
3. Make sure your project is selected (top dropdown)

### Step 2: Find OAuth 2.0 Client IDs
1. Navigate to **APIs & Services** → **Credentials**
2. You should see OAuth 2.0 Client IDs created by Firebase:
   - **Web client (auto created by Google Service)**
   - **Android client for com.tinkerplexlabs.puzzlebazaar**

### Step 3: Copy Web Client ID
1. Click on **Web client (auto created by Google Service)**
2. Copy the **Client ID** (looks like: `xxxxx.apps.googleusercontent.com`)
3. Copy the **Client secret**

## Part 5: Complete Supabase Configuration

### Step 1: Return to Supabase Dashboard
1. Go back to your Supabase project
2. Navigate to **Authentication** → **Providers** → **Google**

### Step 2: Configure Google Provider
1. Paste the **Client ID** (from Web client)
2. Paste the **Client secret**
3. **Authorized Client IDs**: Add your Android client ID(s) here:
   - Find this in Google Cloud Console under the Android client
   - Add multiple IDs separated by commas if you have debug + release
4. Click **Save**

### Step 3: Configure Redirect URLs
1. Still in Supabase, go to **Authentication** → **URL Configuration**
2. Add to **Redirect URLs**:
   ```
   com.tinkerplexlabs.puzzlebazaar://google-auth
   ```
3. Click **Save**

## Part 6: Update Your Flutter Code

### Step 1: Update SupabaseAuthService (Optional)
If you want to use the Web Client ID for better compatibility:

```dart
// In /lib/core/infrastructure/supabase/supabase_auth_service.dart
final _googleSignIn = GoogleSignIn(
  clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com', // Add this line
);
```

### Step 2: Run Code Generation
```bash
cd /home/daniel/work/puzzgameFlutter
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## Part 7: Test Your Implementation

### Step 1: Run the App
```bash
flutter run
```

### Step 2: Test Sign-In Flow
1. Tap the account icon in the top right of the home screen
2. Tap "Sign in with Google"
3. Choose your Google account
4. You should be signed in and returned to the home screen
5. Check the settings screen - you should see your email

### Step 3: Verify in Supabase
1. Go to Supabase Dashboard
2. Navigate to **Authentication** → **Users**
3. You should see your signed-in user

## Part 8: Troubleshooting

### Common Issues:

#### "Google Sign-In Failed"
- Check that SHA-1 fingerprints match exactly
- Ensure package name is correct
- Wait 5-10 minutes after Firebase setup

#### "Configuration Error"
- Verify google-services.json is in the correct location
- Check that all Client IDs are properly configured in Supabase

#### Build Errors
- Run `flutter clean` then `flutter pub get`
- Make sure you have the latest Flutter SDK

### Debug Tips:
1. Check logs: `flutter run -v`
2. In Supabase Dashboard, check **Authentication** → **Logs**
3. Test with a different Google account

## Part 9: Next Steps

### 1. Implement User Data Persistence
Now that users can sign in, you can:
- Save game progress to Supabase
- Track high scores per user
- Sync settings across devices

### 2. Add User Profile Features
- Allow username customization
- Add avatar selection
- Show user stats

### 3. Test on Real Device
```bash
flutter build apk --debug
```
Install on your Android device and test.

### 4. Prepare for Production
When ready for release:
1. Add production SHA-1 to Firebase
2. Update google-services.json if needed
3. Test thoroughly

## Success Checklist
- [ ] SHA-1 fingerprints obtained
- [ ] Firebase project created
- [ ] google-services.json downloaded and placed
- [ ] Google provider enabled in Supabase
- [ ] Client ID and secret configured
- [ ] Redirect URLs added
- [ ] Code generation completed
- [ ] Sign-in tested successfully
- [ ] User appears in Supabase dashboard

Congratulations! Your app now has Google Sign-In integrated with Supabase! 🎉
