# GitHub Actions CI/CD Setup for Nook

This guide explains how to set up automated building and publishing to Google Play Store using GitHub Actions.

## Prerequisites

1. **Google Play Service Account** (see `google_play_service_account_setup.md`)
2. **Upload keystore** (your existing PKCS12 keystore)
3. **GitHub repository** with your Flutter project

## GitHub Secrets Setup

You need to add these secrets to your GitHub repository:

### 1. Go to GitHub Repository Settings
- Navigate to your repository: https://github.com/d4nshields/puzzgameFlutter
- Click "Settings" tab
- Click "Secrets and variables" > "Actions"

### 2. Add Required Secrets

Click "New repository secret" for each of these:

**KEYSTORE_BASE64**
```bash
# Convert your keystore to base64
base64 -i ~/upload-keystore.p12 | pbcopy  # macOS
# or
base64 -w 0 ~/upload-keystore.p12        # Linux
```
Copy the output and paste as the secret value.

**KEYSTORE_PASSWORD**
Your keystore password (same as when you created the keystore)

**KEY_PASSWORD** 
Your key password (same as when you created the keystore)

**KEY_ALIAS**
```
upload
```

**GOOGLE_PLAY_SERVICE_ACCOUNT_JSON**
Copy the entire contents of your service account JSON file and paste as the secret value.

## How the Workflow Works

### Automatic Deployment (Release-based)
1. Push your code to the repository
2. Create a new release on GitHub with a tag like `v0.1.2`
3. The workflow automatically:
   - Runs tests
   - Builds the app bundle
   - Uploads to Play Store internal testing track

### Manual Deployment
1. Go to "Actions" tab in your repository
2. Click "Build and Deploy to Play Store"
3. Click "Run workflow"
4. Choose the deployment track (internal/alpha/beta/production)
5. Click "Run workflow"

## Version Management

The workflow automatically:
- Uses the release tag as the version name (e.g., `v0.1.2` becomes `0.1.2`)
- Uses the GitHub run number as the version code
- Updates both `pubspec.yaml` and `build.gradle.kts`

## Release Notes

To customize release notes:
1. Edit files in `distribution/whatsnew/`
2. Create language-specific files like:
   - `whatsnew-en-US` (English)
   - `whatsnew-es-ES` (Spanish)
   - `whatsnew-fr-FR` (French)

## Deployment Tracks

- **internal**: Internal testing (limited testers)
- **alpha**: Alpha testing (larger group)
- **beta**: Beta testing (open beta or closed beta)
- **production**: Live on Play Store

## Testing the Setup

1. **First, test manually**:
   - Go to Actions tab
   - Run "Build and Deploy to Play Store" manually
   - Choose "internal" track
   - Check if it completes successfully

2. **Then test with releases**:
   - Create a new release with tag `v0.1.1`
   - Watch the automatic deployment

## Troubleshooting

### Build Failures
- Check GitHub Actions logs for specific errors
- Ensure all secrets are correctly set
- Verify service account permissions

### Upload Failures
- Check Google Play Console API access
- Verify service account has correct permissions
- Ensure package name matches exactly

### Version Conflicts
- Each upload must have a higher version code
- GitHub run number ensures this automatically

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Rotate service account keys** periodically
3. **Use separate keystores** for different environments if needed
4. **Review action logs** but remember they're visible to repository collaborators

## File Structure

```
.github/
  workflows/
    deploy.yml                 # Main workflow file
distribution/
  whatsnew/
    whatsnew-en-US            # Release notes
android/
  key.properties.example      # Template for local development
```

## Next Steps After Setup

1. Set up branch protection rules
2. Consider adding code quality checks
3. Set up notifications for deployment success/failure
4. Create staging/production environment separation
