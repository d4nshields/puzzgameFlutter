# Sentry Setup Instructions for Puzzle Bazaar

This guide will help you configure Sentry error reporting for the Puzzle Bazaar Flutter app.

## Prerequisites

- Sentry account (free at https://sentry.io)
- Flutter development environment set up
- Access to modify the codebase

## Step 1: Create Sentry Project

1. **Sign up for Sentry**
   - Go to https://sentry.io
   - Create a free account
   - Choose "Flutter" as your platform

2. **Create a new project**
   - Click "Create Project"
   - Select "Flutter" from the platform list
   - Name your project "puzzle-bazaar" or similar
   - Choose your team/organization

3. **Get your DSN**
   - After project creation, you'll see a DSN (Data Source Name)
   - It looks like: `https://abc123@o123456.ingest.sentry.io/7890123`
   - Copy this DSN - you'll need it in the next step

## Step 2: Configure the Application

1. **Update the DSN in the code**
   - Open `lib/core/infrastructure/sentry_error_reporting_service.dart`
   - Find the `_getDsn()` method
   - Replace the placeholder DSN with your actual DSN:

```dart
String _getDsn() {
  // Replace with your actual Sentry DSN
  const dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: 'https://your-actual-dsn@sentry.io/your-project-id',
  );
  
  return dsn;
}
```

2. **Update the release version**
   - In the same file, find the `_getRelease()` method
   - Update it to match your current app version:

```dart
String _getRelease() {
  return 'puzzgame_flutter@0.1.11+12'; // Match your pubspec.yaml version
}
```

## Step 3: Install Dependencies

1. **Install Sentry Flutter package**
   ```bash
   cd /path/to/your/puzzle/game/project
   flutter pub get
   ```

2. **Verify installation**
   - Check that `sentry_flutter: ^7.18.0` appears in your `pubspec.yaml`
   - Run `flutter pub deps` to verify dependencies are resolved

## Step 4: Test the Integration

1. **Build and run the app**
   ```bash
   flutter run
   ```

2. **Verify initialization**
   - Check the console logs for:
     ```
     Error reporting service initialized successfully
     SentryErrorReportingService: Initialized successfully
     ```

3. **Test error reporting (optional)**
   - Add a test error in development:
   ```dart
   // In initState() of any widget for testing
   if (kDebugMode) {
     _errorReporting.reportMessage(
       'Test Sentry integration',
       level: 'info',
       tags: {'test': 'true'},
     );
   }
   ```

## Step 5: Environment Configuration (Optional)

For better security, configure DSN via environment variables:

1. **Create dart-define configuration**
   ```bash
   flutter run --dart-define=SENTRY_DSN=https://your-actual-dsn@sentry.io/your-project-id
   ```

2. **For VS Code launch configuration**
   - Add to `.vscode/launch.json`:
   ```json
   {
     "configurations": [
       {
         "name": "Flutter (Debug)",
         "type": "dart",
         "request": "launch",
         "program": "lib/main.dart",
         "args": [
           "--dart-define=SENTRY_DSN=https://your-actual-dsn@sentry.io/your-project-id"
         ]
       }
     ]
   }
   ```

3. **For release builds**
   ```bash
   flutter build apk --release --dart-define=SENTRY_DSN=https://your-actual-dsn@sentry.io/your-project-id
   ```

## Step 6: Configure Sentry Dashboard

1. **Set up alerts**
   - Go to your Sentry project dashboard
   - Navigate to "Alerts" → "Create Alert"
   - Configure alerts for:
     - New issues (immediate)
     - Issue frequency spikes (hourly)
     - Performance degradation (daily)

2. **Configure integrations**
   - **Slack**: Get notifications in your team channel
   - **Email**: Personal notifications for critical issues
   - **GitHub**: Link issues to your repository

3. **Set up releases**
   - Navigate to "Releases"
   - Enable release tracking to correlate issues with app versions

## Step 7: Verify Production Setup

1. **Build release version**
   ```bash
   flutter build apk --release
   ```

2. **Install on test device**
   ```bash
   flutter install --release
   ```

3. **Check Sentry dashboard**
   - Navigate to your Sentry project
   - Look for "Application started" breadcrumb in Issues
   - Verify events are being received

## Free Tier Limits

- **Errors**: 5,000 errors per month
- **Performance**: 10,000 transactions per month
- **Retention**: 90 days
- **Team members**: Unlimited
- **Projects**: Unlimited

For most indie apps, the free tier is sufficient. Monitor usage in Sentry dashboard.

## Troubleshooting

### No events appearing in Sentry

1. **Check DSN configuration**
   ```dart
   print('Sentry DSN: ${_getDsn()}'); // Should not contain 'your-dsn'
   ```

2. **Verify network connectivity**
   - Ensure device/emulator has internet access
   - Check if corporate firewall blocks sentry.io

3. **Check console logs**
   ```
   SentryErrorReportingService: Failed to initialize: [error]
   ```

### Events not filtered correctly

1. **Review filter configuration**
   - Check `_filterEvent()` method in `SentryErrorReportingService`
   - Adjust filtering rules as needed

2. **Check sampling rates**
   ```dart
   options.tracesSampleRate = 0.1; // 10% of performance events
   ```

### Too many events (approaching limits)

1. **Increase filtering**
   - Add more specific filters in `_filterEvent()`
   - Reduce sampling rates

2. **Upgrade Sentry plan**
   - Consider paid plan if app has high usage
   - Monitor usage trends in dashboard

## Privacy Compliance

1. **Update privacy policy**
   - The provided privacy policy template includes Sentry disclosure
   - Customize it for your specific needs
   - Update app store listings

2. **GDPR compliance**
   - Sentry is GDPR compliant
   - No personal data is collected by our configuration
   - Users can request data deletion via Sentry support

3. **User consent**
   - Current implementation doesn't require explicit consent (technical data only)
   - Consider opt-in mechanism if collecting additional data

## Monitoring and Maintenance

### Daily
- Check Sentry dashboard for critical issues
- Review new error patterns

### Weekly
- Analyze error trends
- Update filtering rules if needed
- Review performance metrics

### Monthly
- Check usage against free tier limits
- Update error reporting configuration
- Review and close resolved issues

### Per Release
- Update release version in code
- Monitor for new issues after deployment
- Compare error rates between versions

## Advanced Configuration

### Custom Error Context

```dart
// Add custom context to errors
await _errorReporting.reportException(
  error,
  context: 'puzzle_loading',
  extra: {
    'puzzle_id': puzzleId,
    'user_level': userLevel,
    'device_memory': deviceMemory,
  },
  tags: {
    'feature': 'puzzle_game',
    'difficulty': difficulty.toString(),
  },
);
```

### Performance Monitoring

```dart
// Track performance of critical operations
final transaction = await _errorReporting.startTransaction(
  'puzzle_initialization',
  'asset_loading',
);

try {
  await loadPuzzleAssets();
  transaction?.setData('assets_loaded', assetCount);
} finally {
  await transaction?.finish();
}
```

### Custom Breadcrumbs

```dart
// Add breadcrumbs for user journey tracking
await _errorReporting.addBreadcrumb(
  'User completed tutorial',
  category: 'user_action',
  data: {
    'tutorial_step': 'final',
    'time_spent_seconds': timeSpent,
  },
);
```

## Support

If you encounter issues:

1. **Check Sentry documentation**: https://docs.sentry.io/platforms/flutter/
2. **Review our implementation**: See `docs/sentry_integration_architecture.md`
3. **Flutter community**: https://flutter.dev/community
4. **Sentry support**: Available for paid plans

## Success Indicators

- ✅ No console errors during app startup
- ✅ "Application started" breadcrumb appears in Sentry
- ✅ Test errors are captured and reported
- ✅ Performance transactions are recorded
- ✅ Filtering rules reduce noise effectively
- ✅ Privacy policy updated and compliant

Once these indicators are met, your Sentry integration is ready for production use.
