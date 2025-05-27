# Setting Up Google Play Service Account for GitHub Actions

## Step 1: Create a Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Navigate to "IAM & Admin" > "Service Accounts"
4. Click "Create Service Account"
5. Name it something like "github-actions-play-store"
6. Add description: "Service account for automated Play Store publishing"
7. Click "Create and Continue"
8. **Skip the optional permissions step** (click "Continue")
9. Click "Done"

## Step 2: Generate JSON Key

1. In the Service Accounts list, click on your newly created service account
2. Go to "Keys" tab
3. Click "Add Key" > "Create new key"
4. Choose "JSON" format
5. Click "Create"
6. Download the JSON file
7. **Keep this file secure - you'll need it for GitHub secrets**

## Step 3: Enable Google Play Android Developer API

1. In Google Cloud Console, go to "APIs & Services" > "Library"
2. Search for "Google Play Android Developer API"
3. Click on it and click "Enable"

## Step 4: Grant Permissions in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Click "Settings" (gear icon) in the left sidebar
3. Click "Developer account" > "API access"
   
   **Note**: If you don't see "API access", this is normal with Google's updated process. Skip to step 4b.

4a. **If you see API access**:
   - Find your service account and click "Manage Play Console permissions"
   
4b. **Alternative method (if API access is not visible)**:
   - Go to "Settings" > "Developer account" > "Users and permissions"
   - Click "Invite new users"
   - Enter your service account email (found in the JSON file as "client_email")
   - Grant these permissions:
     - View app information and download bulk reports (read-only)
     - Manage production releases
     - Manage testing track releases
     - Release to production, exclude devices, and use Play App Signing

5. Save the permissions

## Step 5: Verify Setup

Your service account should now have:
- ✅ JSON key file downloaded
- ✅ Google Play Android Developer API enabled in Google Cloud
- ✅ Proper permissions in Google Play Console

## Troubleshooting

**If you don't see "API access" in Play Console:**
- This is normal with Google's updated process
- Use the "Users and permissions" method instead
- The service account email is in your JSON file as "client_email"

**If permissions don't seem to work:**
- Wait 10-15 minutes for permissions to propagate
- Verify the service account email matches exactly
- Ensure the Google Play Android Developer API is enabled

## What's Changed

Google has simplified the API setup process:
- No longer need to explicitly "link" your Google Cloud project
- The "API Access" section has been removed from many Play Console accounts
- The key requirements are: enabled API + proper service account permissions
