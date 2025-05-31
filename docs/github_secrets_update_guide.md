# GitHub Secrets Update Guide for Puzzle Bazaar

## Overview
This guide provides step-by-step instructions for updating the two critical GitHub repository secrets needed for automated releases of Puzzle Bazaar.

---

## 🔑 **Part 1: Update KEYSTORE_BASE64 Secret**

### Step 1: Generate Your New P12 Keystore
(If you haven't already done this)

```bash
keytool -genkey -v \
  -keystore upload-keystore-puzzlebazaar.p12 \
  -storetype PKCS12 \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

**Fill in the certificate information:**
- **Name:** Dan Shields
- **Organizational Unit:** Development Division
- **Organization:** TinkerPlex Labs
- **City:** Whitby
- **State:** ON
- **Country:** CA

### Step 2: Create Base64 Encoded Version

```bash
# Navigate to where your keystore is located
cd /home/daniel/work/puzzgameFlutter

# Create base64 encoded version
base64 upload-keystore-puzzlebazaar.p12 > keystore-base64.txt

# View the content (this is what you'll copy)
cat keystore-base64.txt
```

**Expected output:** A long string of letters/numbers like:
```
MIIKEgIBAzCCCdwGCSqGSIb3DQEHAaCCCc0EggnJMIIJxTCCBhAGCSqGSIb3...
[many more lines of encoded text]
...gICcAP4tpwHAP4tpwHAP4tpwHA==
```

### Step 3: Update GitHub Secret

1. **Go to your GitHub repository**: `https://github.com/YOUR_USERNAME/puzzgameFlutter`
2. **Click on "Settings"** tab
3. **Click on "Secrets and variables"** in the left sidebar
4. **Click on "Actions"**
5. **Find "KEYSTORE_BASE64"** in the list
6. **Click "Update"** (or "New repository secret" if it doesn't exist)
7. **Paste the entire base64 content** from `keystore-base64.txt`
8. **Click "Update secret"**

### Step 4: Verify Other Keystore-Related Secrets

While you're in GitHub secrets, verify these match your new keystore:

- **`KEYSTORE_PASSWORD`**: The password you set for the P12 keystore
- **`KEY_PASSWORD`**: Usually the same as keystore password
- **`KEY_ALIAS`**: Should be "upload"

---

## 🏪 **Part 2: Create New GOOGLE_PLAY_SERVICE_ACCOUNT_JSON**

### Step 1: Create New App in Google Play Console

1. **Go to Google Play Console**: https://play.google.com/console
2. **Click "Create app"**
3. **Fill in app details:**
   - **App name:** Puzzle Bazaar
   - **Default language:** English (United States)
   - **App or game:** Game
   - **Free or paid:** Free (or paid if applicable)
4. **Declarations:** Check the appropriate boxes
5. **Click "Create app"**
6. **IMPORTANT:** Note down the **Package name** field - set it to: `com.tinkerplexlabs.puzzlebazaar`

### Step 2: Set Up Google Cloud Project (If Not Already Done)

1. **Go to Google Cloud Console**: https://console.cloud.google.com
2. **Create new project** (or use existing one):
   - **Project name:** `puzzle-bazaar-releases`
   - **Organization:** Your organization (if applicable)
3. **Enable Google Play Android Developer API:**
   - Go to "APIs & Services" > "Library"
   - Search for "Google Play Android Developer API"
   - Click on it and click "Enable"

### Step 3: Create Service Account

1. **In Google Cloud Console**, go to "IAM & Admin" > "Service accounts"
2. **Click "Create Service Account"**
3. **Service account details:**
   - **Service account name:** `puzzle-bazaar-github-actions`
   - **Service account ID:** `puzzle-bazaar-github-actions` (auto-filled)
   - **Description:** `GitHub Actions CI/CD for Puzzle Bazaar app releases`
4. **Click "Create and Continue"**
5. **Grant permissions:** Skip this step for now (click "Continue")
6. **Grant users access:** Skip this step (click "Done")

### Step 4: Generate Service Account Key

1. **Find your new service account** in the list
2. **Click on the service account name**
3. **Go to the "Keys" tab**
4. **Click "Add Key" > "Create new key"**
5. **Select "JSON" format**
6. **Click "Create"**
7. **A JSON file will download** - this contains your credentials

### Step 5: Link Service Account to Google Play Console

1. **Go back to Google Play Console**
2. **Go to "Setup" > "API access"** (in left sidebar)
3. **If not already linked:** Click "Link" next to your Google Cloud project
4. **Find your service account** in the list: `puzzle-bazaar-github-actions`
5. **Click "Grant Access"**
6. **Set permissions:**
   - **Account permissions:** None needed
   - **App permissions:** 
     - Select "Puzzle Bazaar" app
     - Check "Release Manager" (allows uploading releases)
7. **Click "Send invitation"**
8. **Click "Done"**

### Step 6: Update GitHub Secret

1. **Open the downloaded JSON file** in a text editor
2. **Copy the ENTIRE contents** of the JSON file
3. **Go to your GitHub repository settings** > "Secrets and variables" > "Actions"
4. **Find "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"** 
5. **Click "Update"** (or "New repository secret" if it doesn't exist)
6. **Paste the entire JSON content**
7. **Click "Update secret"**

**The JSON should look like this:**
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "puzzle-bazaar-github-actions@your-project.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

---

## ✅ **Step 7: Test Your Setup**

### Test 1: Build Locally
```bash
cd /home/daniel/work/puzzgameFlutter

# Clean and build
flutter clean
flutter pub get
flutter build appbundle --release
```

**Expected result:** App bundle builds successfully at `build/app/outputs/bundle/release/app-release.aab`

### Test 2: Manual GitHub Action Test

1. **Go to your GitHub repository**
2. **Click "Actions" tab**
3. **Find "Build and Deploy to Play Store" workflow**
4. **Click "Run workflow"**
5. **Select parameters:**
   - **Branch:** main (or your default branch)
   - **Track:** internal
6. **Click "Run workflow"**

### Test 3: Check Workflow Logs

Look for these success indicators:
```
✅ Decode keystore - Success
✅ Create key.properties - Success  
✅ Build App Bundle - Success
✅ Upload to Play Store - Success
✅ Package: com.tinkerplexlabs.puzzlebazaar
```

### Test 4: Verify in Google Play Console

1. **Go to Google Play Console**
2. **Select your "Puzzle Bazaar" app**
3. **Go to "Release" > "Testing" > "Internal testing"**
4. **You should see a new release** with your app bundle

---

## 🔒 **Security Best Practices**

### For Keystore:
- ✅ **Backup the P12 file** in multiple secure locations
- ✅ **Store passwords in a password manager**
- ✅ **Never commit keystore files to Git**
- ✅ **Keep base64 version secure** (it's equivalent to the keystore)

### For Service Account:
- ✅ **Download JSON file only once** and store securely
- ✅ **Delete the JSON file** from Downloads folder after copying to GitHub
- ✅ **Limit service account permissions** to only what's needed
- ✅ **Regularly audit service account access**

---

## 🐛 **Troubleshooting**

### "Invalid keystore" error:
```bash
# Verify your keystore is valid
keytool -list -v -keystore upload-keystore-puzzlebazaar.p12
```

### "Package not found" error:
- Verify app exists in Google Play Console with exact package name: `com.tinkerplexlabs.puzzlebazaar`
- Check service account has access to the specific app

### "Permission denied" error:
- Verify service account has "Release Manager" permission
- Check that Google Play Android Developer API is enabled in Google Cloud

### "Invalid JSON" error:
- Ensure you copied the ENTIRE JSON file content
- Check for any trailing spaces or missing characters
- Verify JSON is valid at https://jsonlint.com

### GitHub Action fails at "Upload to Play Store":
- Check Google Play Console for any pending setup steps
- Verify app has at least one release (even if internal)
- Ensure store listing has minimum required information

---

## 📋 **Quick Checklist**

### Before running the workflow:
- [ ] New P12 keystore generated and backed up
- [ ] `KEYSTORE_BASE64` secret updated in GitHub
- [ ] `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` secrets verified
- [ ] New app created in Google Play Console with correct package name
- [ ] Google Cloud project created/configured
- [ ] Service account created with proper permissions
- [ ] `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret updated in GitHub
- [ ] Local build test successful

### After first successful workflow run:
- [ ] Release appears in Google Play Console internal testing
- [ ] App bundle has correct package name
- [ ] Version information is correct
- [ ] Can promote release to alpha/beta if desired

---

## 🚀 **Next Steps After Setup**

### For Future Releases:
```bash
# Create and push a tag to trigger automatic release
git tag v1.0.0
git push origin v1.0.0
```

### Or use manual workflow trigger:
1. Go to GitHub Actions
2. Select "Build and Deploy to Play Store"
3. Click "Run workflow"
4. Choose track (internal/alpha/beta/production)

---

*Once both secrets are updated and tested, your automated release pipeline for Puzzle Bazaar will be fully operational!*
