# Game Module Migration Plan: Feature Flag-Based Switching

## Current Situation
- **Active Module**: `game_module2` (with magnetic gestures built-in)
- **UI Widget**: `PuzzleWorkspaceWidget` 
- **Magnetic Features**: Already implemented but not explicitly activated

## Migration Strategy

### Phase 1: Add Feature Flag for Module Selection
Add a new feature flag to control which game module is used:

```sql
-- Add to Supabase
INSERT INTO feature_flags (product_id, name, description, default_value) 
VALUES (
  (SELECT id FROM products WHERE name = 'puzzle_nook'),
  'use_magnetic_module',
  'Enable advanced magnetic gesture system',
  'false'::jsonb
);
```

### Phase 2: Modify Service Locator
Update `/lib/core/infrastructure/service_locator.dart`:

```dart
import 'package:puzzgame_flutter/game_module/puzzle_game_module.dart';
import 'package:puzzgame_flutter/game_module2/puzzle_game_module2.dart';
import 'package:puzzgame_flutter/game_module2/infrastructure/feature_flags.dart';

void setupDependencies() async {
  // ... existing setup ...
  
  // Register Game Module based on feature flag
  final featureFlags = FeatureFlagService.instance;
  final useMagneticModule = await featureFlags.isEnabled('use_magnetic_module');
  
  if (useMagneticModule) {
    print('Using magnetic game module (game_module2)');
    serviceLocator.registerSingleton<GameModule>(PuzzleGameModule2());
  } else {
    print('Using classic game module (game_module)');
    serviceLocator.registerSingleton<GameModule>(PuzzleGameModule());
  }
  
  // ... rest of setup ...
}
```

### Phase 3: Ensure GameScreen Handles Both Types
The `GameScreen` already handles both module types correctly:
- Checks if session is `PuzzleGameSession2` → uses `PuzzleWorkspaceWidget`
- Checks if session is `PuzzleGameSession` → uses `EnhancedPuzzleGameWidget`

### Phase 4: Enable Magnetic Features Within Module2
The magnetic features are already built but need activation via existing flags:

```dart
// In PuzzleGameModule2.initialize()
final magneticGestures = await _featureFlags.isEnabled('magnetic_gestures');
final enhancedFeedback = await _featureFlags.isEnabled('enhanced_feedback');
final smoothAnimations = await _featureFlags.isEnabled('smooth_animations');

_interactionIntegration = InteractionIntegration(
  controller: _controller!,
  enableMagneticGestures: magneticGestures,  // Currently controlled by flag
  enableEnhancedFeedback: enhancedFeedback,
  enableSmoothAnimations: smoothAnimations,
);
```

## Recommended Approach

### Option 1: Single Master Flag (Simplest)
Use one flag `use_magnetic_module` to switch between entire implementations:
- `false` → Use old game_module (classic experience)
- `true` → Use game_module2 (magnetic experience)

### Option 2: Gradual Feature Rollout (Current Setup)
Keep using game_module2 but control features individually:
- `magnetic_gestures` → Enable/disable magnetic snap
- `enhanced_feedback` → Enable/disable haptic feedback
- `smooth_animations` → Enable/disable smooth transitions

### Option 3: Rename and Consolidate (Recommended)
1. Copy game_module2 to `game_module_magnetic/`
2. Keep original game_module as `game_module_classic/`
3. Use feature flag to switch between them
4. Eventually deprecate classic when magnetic is stable

## Implementation Steps

### Step 1: Add Database Flag
```sql
-- In Supabase
UPDATE feature_flags 
SET default_value = 'true'::jsonb 
WHERE name = 'magnetic_gestures';

-- Or add new master flag
INSERT INTO feature_flags (product_id, name, description, default_value)
VALUES (
  (SELECT id FROM products WHERE name = 'puzzle_nook'),
  'game_module_version',
  'Game module version: classic or magnetic',
  '"magnetic"'::jsonb
);
```

### Step 2: Update Service Locator
Make the service locator async and check flags during initialization.

### Step 3: Test Both Paths
- Toggle flag in database
- Restart app
- Verify correct module loads
- Test gameplay in both modes

## Benefits of This Approach

1. **Zero Code Changes for Testing**: Just flip database flag
2. **Instant Rollback**: If issues arise, flip flag back
3. **A/B Testing Ready**: Can assign different modules to different users
4. **Gradual Rollout**: Start with internal testing, expand to beta users
5. **Clean Deprecation Path**: Eventually remove old module when ready

## Current Feature Flag Status

Based on the code, these flags already exist and control game_module2 features:
- `sample_puzzle`: Controls if sample puzzle shows (working)
- `magnetic_gestures`: Controls magnetic snap behavior (built, not fully wired)
- `enhanced_feedback`: Controls haptic feedback (built, not fully wired)
- `smooth_animations`: Controls animation system (built, not fully wired)

## Quick Test Commands

```bash
# Test with magnetic features ON
adb shell am start -n com.tinkerplexlabs.puzzlenook/.MainActivity

# Monitor logs
adb logcat -s flutter | grep -E "game_module|magnetic|gesture"

# Update flag via Supabase
# Then restart app to load new module
```

## Deprecation Timeline

1. **Week 1**: Test magnetic module internally
2. **Week 2**: Enable for beta users (10%)
3. **Week 3**: Expand to 50% users
4. **Week 4**: Full rollout if metrics are good
5. **Week 5**: Deprecate old module, clean up code

## Code Cleanup Tasks

Once migration is complete:
1. Delete `/lib/game_module/` directory
2. Remove `EnhancedPuzzleGameWidget` 
3. Rename `game_module2` to `game_module`
4. Update all imports
5. Remove feature flag checks
6. Archive old implementation for reference
