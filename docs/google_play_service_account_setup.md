# Setting Up Google Play Service Account for GitHub Actions

## Step 1: Create a Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Navigate to "IAM & Admin" > "Service Accounts"
4. Click "Create Service Account"
5. Name it something like "github-actions-play-store"
6. Add description: "Service account for automated Play Store publishing"
7. Click "Create and Continue"

## Step 2: Grant Permissions

1. In the Google Play Console, go to "Setup" > "API access"
2. Link your Google Cloud project if not already linked
3. Find your service account and click "Manage Play Console permissions"
4. Grant these permissions:
   - View app information and download bulk reports (read-only)
   - Manage production releases
   - Manage testing track releases
   - Release to production, exclude devices, and use Play App Signing

## Step 3: Generate JSON Key

1. Back in Google Cloud Console > Service Accounts
2. Click on your service account
3. Go to "Keys" tab
4. Click "Add Key" > "Create new key"
5. Choose "JSON" format
6. Download the JSON file
7. **Keep this file secure - you'll need it for GitHub secrets**

## Step 4: Enable Google Play Android Developer API

1. In Google Cloud Console, go to "APIs & Services" > "Library"
2. Search for "Google Play Android Developer API"
3. Click on it and enable it
