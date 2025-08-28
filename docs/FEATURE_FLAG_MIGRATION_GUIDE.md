# Feature Flag System Migration Guide

## Overview

We are migrating from a compile-time feature flag system to a database-driven, multi-tenant system that supports all Tinkerplex products.

## Key Improvements

### Multi-Tenant Support
- Each Tinkerplex product has its own set of feature flags
- Shared environments across all products
- Centralized management through Supabase

### Database-Driven
- No rebuild required for flag changes
- Real-time updates via Supabase subscriptions
- Audit trail for all changes

### Graceful Degradation
- **Priority Order**: Database → Cache → YAML defaults
- Works offline with cached values
- Falls back to YAML configuration when database unavailable

## Migration Steps

### Phase 1: Parallel Systems (Current State)
Both systems run in parallel during transition:
- **Old System** (`lib/core/configuration/build_config.dart`) - Compile-time flags
- **New System** (`lib/game_module2/infrastructure/feature_flags.dart`) - Database-driven

### Phase 2: Code Migration

#### Old Usage Pattern
```dart
// Old compile-time check
import 'package:puzzgame_flutter/core/configuration/build_config.dart';

if (Features.magneticGestures) {
  // Feature code
}
```

#### New Usage Pattern
```dart
// New runtime check
import 'package:puzzgame_flutter/game_module2/infrastructure/feature_flags.dart';

// Option 1: Direct check
if (FeatureFlagService.instance.isEnabled('magnetic_gestures')) {
  // Feature code
}

// Option 2: Widget-based
FeatureGate(
  feature: 'magnetic_gestures',
  child: MagneticGestureWidget(),
  fallback: StandardGestureWidget(),
)

// Option 3: BuildContext extension
if (context.isFeatureEnabled('magnetic_gestures')) {
  // Feature code
}
```

### Phase 3: Initialization

Add to your app initialization:

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );
  
  // Initialize feature flags
  final featureFlags = FeatureFlagService(
    productKey: 'puzzle_nook',
    environment: const String.fromEnvironment('ENVIRONMENT', 
      defaultValue: 'development'),
    supabase: Supabase.instance.client,
  );
  
  await featureFlags.initialize();
  
  runApp(MyApp(featureFlags: featureFlags));
}
```

## Environment Configuration

### Setting Environment

#### For Development
```bash
flutter run --dart-define=ENVIRONMENT=development
```

#### For QA Testing
```bash
flutter run --dart-define=ENVIRONMENT=qa
```

#### For Alpha Testing
```bash
flutter run --dart-define=ENVIRONMENT=alpha
```

#### For Production
```bash
flutter build apk --dart-define=ENVIRONMENT=production
```

## Database Management

### View Current Flags
```sql
SELECT * FROM get_feature_flags('puzzle_nook', 'development');
```

### Update Flag for Environment
```sql
UPDATE environment_flag_overrides 
SET enabled = true
WHERE feature_flag_id = (
  SELECT id FROM feature_flags 
  WHERE product_id = (SELECT id FROM products WHERE key = 'puzzle_nook')
  AND key = 'magnetic_gestures'
)
AND environment_id = (
  SELECT id FROM environments WHERE key = 'qa'
);
```

### Add User Override for Testing
```sql
INSERT INTO user_flag_overrides (product_id, user_id, feature_flag_id, enabled)
VALUES (
  (SELECT id FROM products WHERE key = 'puzzle_nook'),
  'test_user_123',
  (SELECT id FROM feature_flags WHERE key = 'magnetic_gestures' 
   AND product_id = (SELECT id FROM products WHERE key = 'puzzle_nook')),
  true
);
```

## Feature Flag Naming Convention

### Old Names → New Names
- `Features.samplePuzzle` → `'sample_puzzle'`
- `Features.magneticGestures` → `'magnetic_gestures'`
- `Features.debugTools` → `'debug_tools'`
- `Features.enhancedFeedback` → `'enhanced_feedback'`
- `Features.smoothAnimations` → `'smooth_animations'`
- `Features.performanceMonitoring` → `'performance_monitoring'`

## Testing

### Unit Tests
```dart
test('Feature flag service works offline', () async {
  final service = FeatureFlagService(
    productKey: 'puzzle_nook',
    environment: 'development',
    supabase: null, // Force offline mode
  );
  
  await service.initialize();
  
  // Should use YAML defaults
  expect(service.currentSource, FlagSource.yamlDefaults);
  expect(service.isEnabled('smooth_animations'), isTrue);
});
```

### Integration Tests
```dart
test('Feature flag updates from database', () async {
  final service = FeatureFlagService(
    productKey: 'puzzle_nook',
    environment: 'qa',
    supabase: Supabase.instance.client,
  );
  
  await service.initialize();
  
  // Wait for database fetch
  await Future.delayed(Duration(seconds: 1));
  
  expect(service.currentSource, FlagSource.database);
  expect(service.isEnabled('magnetic_gestures'), isTrue); // QA has it enabled
});
```

## Monitoring

### Debug Information
```dart
// Get current flag status
final debugInfo = FeatureFlagService.instance.getDebugInfo();
print(debugInfo);

// Check source
if (!FeatureFlagService.instance.isUsingLiveData) {
  print('Warning: Using cached or default flags');
}
```

### Admin Dashboard
A Supabase dashboard view can be created to:
- View all flags across products and environments
- Toggle flags without database access
- View audit history
- Monitor rollout percentages

## Rollback Plan

If issues occur, you can:

1. **Immediate**: Force YAML defaults by setting `supabase: null`
2. **Quick**: Clear cache to force refresh: `service.clearCache()`
3. **Full**: Revert to old system by using `BuildConfig` classes

## Timeline

- **Week 1**: Deploy new system alongside old
- **Week 2**: Migrate game_module2 to new system
- **Week 3**: Migrate remaining features
- **Week 4**: Remove old BuildConfig system

## Support for Other Tinkerplex Products

To add a new product:

1. Insert product in database:
```sql
INSERT INTO products (key, name, description) 
VALUES ('new_game', 'New Game', 'Description');
```

2. Add feature flags for the product
3. Create YAML defaults: `assets/config/feature_flags_new_game.yaml`
4. Initialize with `productKey: 'new_game'`

## FAQ

### Q: What happens if the database is down?
A: The system falls back to cache (if available) then YAML defaults. The app continues to work.

### Q: How quickly do flag changes propagate?
A: Database changes are fetched every 5 minutes while the app is active, or immediately on app resume.

### Q: Can I test flags for specific users?
A: Yes, use user_flag_overrides table or pass userId to FeatureFlagService.

### Q: How do percentage rollouts work?
A: Based on consistent hashing of userId + flagKey, ensuring users get consistent experience.

### Q: Can I use this for A/B testing?
A: Yes, use the 'variant' flag type with `getVariant()` method.
