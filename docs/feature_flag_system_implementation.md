# Feature Flag System Implementation

## Overview

This document describes the implementation of a comprehensive feature flag system for the Puzzle Nook Flutter game. The system provides build-time feature control, enabling different build variants (internal vs external) while maintaining production stability and optimal performance.

## Architecture Decision Record

**Decision**: Implement a compile-time feature flag system using const constructors and build variants

**Context**: 
- Need to create internal builds that skip sample puzzle flow for faster development testing
- Require external builds with only approved features for production release
- Must maintain zero runtime overhead and enable tree-shaking of unused features
- Need clear separation between development and production feature sets

**Consequences**:
- ✅ Zero runtime performance impact (compile-time constants)
- ✅ Tree-shaking removes unused feature code
- ✅ Type-safe feature flag access
- ✅ Clear build variant separation
- ✅ Easy build automation via scripts
- ❌ Requires rebuild when switching variants (acceptable trade-off)

## Implementation Components

### 1. Build Configuration (`lib/core/configuration/build_config.dart`)

**Core Classes**:
- `BuildConfig`: Main configuration container with variant, features, and debug settings
- `FeatureFlags`: Individual feature toggles with clear documentation
- `DebugConfig`: Debug-specific settings for development builds
- `Features`: Convenient static access to feature flags
- `Debug`: Convenient static access to debug settings

**Build Variants**:
- **Internal**: All features enabled, debug tools available, sample puzzle skipped
- **External**: Only approved features, production UX, complete user flow

**Key Features Controlled**:
- `skipSamplePuzzle`: Skip sample puzzle and go directly to sign-up (Internal: true, External: false)
- `enableDebugTools`: Show debug overlays and tools (Internal: true, External: false)
- `enableExperimentalFeatures`: Include experimental features (Internal: true, External: false)
- `enableDetailedAnalytics`: Detailed logging and analytics (Internal: true, External: false)
- `enableSharingFlow`: User sharing and badges system (Internal: true, External: true)
- `enableEarlyAccessRegistration`: Early access sign-up flow (Internal: true, External: true)
- `enableGoogleSignIn`: Google authentication integration (Internal: true, External: true)

### 2. Feature-Aware Navigation (`lib/core/configuration/feature_aware_navigation.dart`)

**Key Components**:
- `FeatureAwareNavigationService`: Centralized navigation logic respecting feature flags
- `FeatureGate`: Widget that conditionally renders based on feature flags
- `DebugOnly`: Widget that only renders in debug/internal builds
- `DebugOptionsDialog`: Development tools dialog for internal builds

**Navigation Flow**:
```
App Launch → FeatureAwareHomeScreen → Check skipSamplePuzzle flag
├─ Internal Build: Navigate directly to early access registration
└─ External Build: Navigate to sample puzzle game
```

**Post-Game Flow**:
```
Game Completion → Check feature flags → Navigate appropriately
├─ Early Access enabled: Go to registration
├─ Sharing Flow enabled: Go to sharing encouragement
└─ Fallback: Restart game
```

### 3. Updated Main Application (`lib/main.dart`)

**Enhancements**:
- Feature-aware route handling with fallback screens
- Debug configuration integration (debug banner, performance overlay)
- `FeatureAwareHomeScreen` for initial navigation logic
- `FeatureDisabledScreen` for graceful feature unavailability handling

**Route Protection**:
All feature-specific routes are protected by feature flags:
```dart
'/early-access': (context) => Features.earlyAccess 
    ? const EarlyAccessRegistrationScreen() 
    : const FeatureDisabledScreen(featureName: 'Early Access Registration'),
```

### 4. Build Automation Scripts

**`build.sh`**: Comprehensive build script with feature flag switching
- Supports internal/external variants
- Supports debug/release modes  
- Supports APK/AAB output formats
- Automatic configuration switching with backup/restore
- Detailed build information generation
- File size reporting and next steps guidance

**`switch_config.sh`**: Quick configuration switcher for development
- Fast switching between internal/external configurations
- Current configuration display
- Hot reload compatible

## Usage Instructions

### Development Workflow

1. **Switch to Internal Configuration** (for development/testing):
   ```bash
   ./switch_config.sh internal
   flutter hot reload
   ```

2. **Switch to External Configuration** (for production testing):
   ```bash
   ./switch_config.sh external
   flutter hot reload
   ```

3. **Check Current Configuration**:
   ```bash
   ./switch_config.sh
   ```

### Building Different Variants

1. **Internal Debug Build** (development testing):
   ```bash
   ./build.sh internal debug apk
   ```

2. **External Release Build** (production APK):
   ```bash
   ./build.sh external release apk
   ```

3. **External Release Bundle** (Play Store upload):
   ```bash
   ./build.sh external release aab
   ```

4. **Quick External Build** (uses defaults):
   ```bash
   ./build.sh external
   ```

### Adding New Features

1. **Add Feature Flag** to `FeatureFlags` class:
   ```dart
   /// Enable new awesome feature
   /// Internal: true (for testing)
   /// External: false (not ready for release)
   final bool enableAwesomeFeature;
   ```

2. **Update Build Configurations**:
   ```dart
   // In _internalBuildConfig
   enableAwesomeFeature: true,
   
   // In _externalBuildConfig  
   enableAwesomeFeature: false,
   ```

3. **Add Convenience Accessor**:
   ```dart
   // In Features class
   static const bool awesomeFeature = _flags.enableAwesomeFeature;
   ```

4. **Use in Code**:
   ```dart
   if (Features.awesomeFeature) {
     // Awesome feature implementation
   }
   
   // Or with widgets
   FeatureGate(
     feature: Features.awesomeFeature,
     child: AwesomeFeatureWidget(),
     fallback: Text('Feature not available'),
   )
   ```

## Best Practices

### Feature Flag Naming
- Use clear, descriptive names: `enableGoogleSignIn` not `googleAuth`
- Include action verb: `skipSamplePuzzle` not `samplePuzzle`
- Document purpose and build variant values

### Code Organization
- Group related features logically
- Use `FeatureGate` widgets for conditional UI
- Centralize navigation logic in `FeatureAwareNavigationService`
- Provide fallback experiences for disabled features

### Testing Strategy
- Test both internal and external builds thoroughly
- Verify feature flags work correctly in both variants
- Ensure disabled features show appropriate fallbacks
- Test build scripts on clean environments

### Documentation
- Document each feature flag's purpose and behavior
- Update this document when adding new features
- Include examples in code comments
- Maintain build variant comparison table

## Production Deployment

### Pre-Release Checklist
1. [ ] Verify external build configuration is active
2. [ ] Test complete user flow (launch → sample puzzle → registration → sharing)
3. [ ] Confirm debug tools are disabled in external build
4. [ ] Validate all feature flags are set correctly for production
5. [ ] Test fallback screens for disabled features
6. [ ] Run automated tests against external build
7. [ ] Perform manual testing on physical devices

### Build Process for Play Store
```bash
# 1. Clean environment
flutter clean
flutter pub get

# 2. Build external release bundle
./build.sh external release aab

# 3. Verify build output
# Check distribution/ folder for generated .aab file and build info

# 4. Upload to Play Console
# Use generated .aab file in distribution/ folder
```

## Monitoring and Analytics

### Internal Builds
- Detailed analytics enabled for development insights
- Verbose logging for debugging
- Performance overlays available
- Debug tools and experimental features accessible

### External Builds
- Minimal logging for user privacy
- Analytics respect user consent preferences
- Clean production UX without debug elements
- Only stable, approved features enabled

## Future Enhancements

### Potential Improvements
1. **CI/CD Integration**: Automate variant selection in build pipeline
2. **Remote Feature Flags**: Runtime toggles for approved features (with caching)
3. **A/B Testing**: Percentage-based feature rollouts
4. **Feature Flag Analytics**: Track feature usage and effectiveness
5. **Gradual Rollouts**: Progressive feature enabling based on user segments

### Migration Path
The current compile-time system provides a solid foundation that can be enhanced with runtime capabilities while maintaining the performance and safety benefits of build-time configuration.

## Troubleshooting

### Common Issues

**Build fails after switching variants**:
- Run `flutter clean && flutter pub get`
- Verify configuration file syntax is correct
- Check that all imports are available

**Feature not appearing in build**:
- Verify feature flag is enabled in current variant
- Check that widget uses correct `Features.flagName`
- Ensure proper `FeatureGate` usage

**Navigation not working as expected**:
- Verify `FeatureAwareNavigationService` is used correctly
- Check that all required features are enabled
- Test fallback navigation paths

**Script permission denied**:
```bash
chmod +x build.sh switch_config.sh
```

## Configuration Reference

### Feature Flag Matrix

| Feature | Internal | External | Purpose |
|---------|----------|----------|---------|
| skipSamplePuzzle | ✅ true | ❌ false | Skip tutorial for faster dev testing |
| enableDebugTools | ✅ true | ❌ false | Development and debugging tools |
| enableExperimentalFeatures | ✅ true | ❌ false | Unstable features under development |
| enableDetailedAnalytics | ✅ true | ❌ false | Development insights and logging |
| enableSharingFlow | ✅ true | ✅ true | User sharing and social features |
| enableEarlyAccessRegistration | ✅ true | ✅ true | Early access user registration |
| enableGoogleSignIn | ✅ true | ✅ true | Google authentication integration |

This system provides a robust foundation for managing features across development and production builds while maintaining excellent performance and user experience.
