# GitHub Actions Update Guide for Puzzle Bazaar

## Overview
This guide documents the required changes to GitHub Actions workflows after the Puzzle Bazaar rebranding and provides setup instructions for automated releases.

---

## ✅ Changes Made to GitHub Actions

### 1. Main Deployment Workflow (`deploy.yml`)

**Updated package name:**
```yaml
# OLD
packageName: org.shields.apps.nook

# NEW  
packageName: com.tinkerplexlabs.puzzlebazaar
```

**Updated keystore handling:**
```yaml
# OLD
- name: Decode keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/app/keystore.jks

- name: Create key.properties
  run: |
    echo "storeFile=keystore.jks" >> android/key.properties

# NEW
- name: Decode keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/app/upload-keystore-puzzlebazaar.p12

- name: Create key.properties
  run: |
    echo "storeFile=upload-keystore-puzzlebazaar.p12" >> android/key.properties
```

---

## 🔧 Required GitHub Secrets Update

You'll need to update the following GitHub repository secrets:

### 1. Update Keystore Secret
```bash
# Create base64 encoded version of your NEW keystore
base64 upload-keystore-puzzlebazaar.p12 > keystore.base64

# Copy the contents and update GitHub secret: KEYSTORE_BASE64
```

### 2. Update/Verify Other Secrets
- **`KEYSTORE_PASSWORD`**: Password for your new P12 keystore
- **`KEY_PASSWORD`**: Key password (often same as keystore password)  
- **`KEY_ALIAS`**: Should be "upload" (as used in keystore generation)
- **`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`**: ⚠️ **NEEDS UPDATE** (see below)

---

## 🏪 Google Play Console Setup Options

### Option A: Use Personal Developer Account (Recommended)

**Advantages:**
- ✅ Quick setup - no verification delays
- ✅ Display "TinkerPlex Labs" as developer name in store
- ✅ Maintain control and flexibility
- ✅ Can transfer to business account later if needed

**Steps:**
1. Create new app in your existing Google Play Console
2. Set package name: `com.tinkerplexlabs.puzzlebazaar`
3. Set developer name to "TinkerPlex Labs" in store listing
4. Users will see "TinkerPlex Labs" as the publisher

### Option B: Create Business Developer Account

**Only consider if:**
- You need formal business separation
- You have business registration documents ready
- You can wait 2-4 weeks for verification
- You want to invest in long-term business infrastructure

---

## 🔐 Google Play Service Account Update

**IMPORTANT:** You'll need a **new service account** for the new app because:
- Different package name = different API permissions needed
- Service accounts are scoped to specific apps

### Steps to Create New Service Account:

1. **Go to Google Cloud Console** for your project
2. **Create new service account**:
   - Name: `puzzle-bazaar-ci-cd`
   - Description: `GitHub Actions deployment for Puzzle Bazaar`
3. **Generate JSON key** and download it
4. **Add service account to Google Play Console**:
   - Go to Setup > API access
   - Link to your Google Cloud project
   - Grant access to the new app (`com.tinkerplexlabs.puzzlebazaar`)
   - Set permissions: `Release manager` or `Admin`

5. **Update GitHub secret**:
   ```bash
   # Copy the entire JSON file content to GitHub secret: 
   # GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
   ```

---

## 🧪 Testing the GitHub Action

### Before First Release:

1. **Create a test release** to verify everything works:
   ```bash
   git tag v0.1.8-test
   git push origin v0.1.8-test
   ```

2. **Use manual trigger** first:
   - Go to GitHub Actions
   - Select "Build and Deploy to Play Store"
   - Click "Run workflow"
   - Select track: "internal"

3. **Check the workflow logs** for:
   - ✅ Keystore decoding successful
   - ✅ App bundle builds without errors
   - ✅ Upload to Play Store succeeds
   - ✅ Correct package name in logs

### Expected Output:
```
✅ Building app bundle...
✅ Signing with upload-keystore-puzzlebazaar.p12
✅ Uploading to Play Store...
✅ Package: com.tinkerplexlabs.puzzlebazaar
✅ Track: internal
✅ Release completed
```

---

## 🔄 Migration Workflow

### 1. Pre-Migration (Current State)
- ❌ Old secrets (JKS keystore for org.shields.apps.nook)
- ❌ Old service account permissions  
- ❌ Old package name in workflows

### 2. During Migration
- ✅ Generate new P12 keystore
- ✅ Update GitHub secrets with new keystore
- ✅ Create new Google Play Console app
- ✅ Create new service account with proper permissions
- ✅ Update workflows (already done)

### 3. Post-Migration  
- ✅ Test internal release
- ✅ Verify everything works end-to-end
- ✅ Document new release process
- 🗑️ Clean up old secrets (keep as backup initially)

---

## 📝 Updated Release Process

### For Internal Testing:
```bash
# Manual trigger via GitHub Actions UI
# Track: internal
```

### For Alpha/Beta Releases:
```bash
git tag v0.2.0-alpha
git push origin v0.2.0-alpha
# Will auto-deploy to internal track
# Then promote manually in Play Console to alpha/beta
```

### For Production Releases:
```bash
git tag v1.0.0
git push origin v1.0.0  
# Will auto-deploy to internal track
# Then promote manually in Play Console to production
```

---

## ⚠️ Important Notes

1. **This is a NEW app**: Google Play will treat `com.tinkerplexlabs.puzzlebazaar` as completely separate from the old app
2. **Fresh start**: No migration of users, reviews, or download counts
3. **Service account scope**: Make sure the new service account has access ONLY to the new app package
4. **Keystore backup**: Keep your new P12 keystore backed up securely
5. **Testing first**: Always test with internal track before promoting to production

---

## 🐛 Troubleshooting

### "Package not found" error:
- Verify Google Play Console app is created with correct package name
- Ensure service account has access to the new app

### "Invalid keystore" error:
- Check that GitHub secret `KEYSTORE_BASE64` contains the P12 keystore (not JKS)
- Verify passwords in GitHub secrets match keystore generation

### "Insufficient permissions" error:
- Verify service account has `Release manager` permissions
- Check that service account is linked to correct Google Play Console account

### "Build signature mismatch" error:
- This indicates you're using wrong keystore
- Ensure you're using the NEW P12 keystore, not the old JKS one

---

*This setup will enable fully automated releases for Puzzle Bazaar under the TinkerPlex Labs brand.*
