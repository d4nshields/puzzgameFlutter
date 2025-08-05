import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/configuration/build_config.dart';

/// Navigation service that respects feature flags and manages the app workflow
/// 
/// This service encapsulates the main user journey:
/// 1. Game launch
/// 2. Play sample puzzle (can be skipped with feature flag)
/// 3. Sign up with Google for early access
/// 4. Share the game with friends to earn badges
/// 
/// Architecture Decision: Centralized navigation logic makes it easier to
/// modify the user flow and ensures feature flags are consistently applied.
class FeatureAwareNavigationService {
  /// Navigate to the appropriate screen based on current feature flags
  /// and user state
  static void navigateToAppropriateScreen(BuildContext context) {
    // Use navigation configuration to determine initial route
    final initialRoute = Navigation.initialRoute;
    
    switch (initialRoute) {
      case 'sample_puzzle':
        _navigateToSamplePuzzle(context);
        break;
      case 'early_access_registration':
        _navigateToEarlyAccessRegistration(context);
        break;
      default:
        // Fallback to early access if route not recognized
        _navigateToEarlyAccessRegistration(context);
    }
  }
  
  /// Navigate directly to early access registration
  static void _navigateToEarlyAccessRegistration(BuildContext context) {
    if (Features.earlyAccessRegistration) {
      Navigator.of(context).pushReplacementNamed('/early-access');
    } else {
      // Fallback to game screen if early access is disabled
      Navigator.of(context).pushReplacementNamed('/game');
    }
  }
  
  /// Navigate to sample puzzle (when enabled)
  static void _navigateToSamplePuzzle(BuildContext context) {
    if (Features.samplePuzzle) {
      Navigator.of(context).pushReplacementNamed('/game');
    } else {
      // If sample puzzle is disabled, fall back to early access
      _navigateToEarlyAccessRegistration(context);
    }
  }
  
  /// Handle post-game navigation based on feature flags and navigation config
  static void handlePostGameNavigation(BuildContext context) {
    final postGameRoute = Navigation.postGameRoute;
    
    switch (postGameRoute) {
      case 'early_access_registration':
        if (Features.earlyAccessRegistration) {
          Navigator.of(context).pushNamed('/early-access');
        } else {
          _fallbackToSharingOrRestart(context);
        }
        break;
      case 'sharing_flow':
        if (Features.sharingFlow) {
          Navigator.of(context).pushNamed('/sharing-encouragement');
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/game', (route) => false);
        }
        break;
      default:
        _fallbackToSharingOrRestart(context);
    }
  }
  
  /// Fallback navigation when primary route is unavailable
  static void _fallbackToSharingOrRestart(BuildContext context) {
    if (Features.sharingFlow) {
      Navigator.of(context).pushNamed('/sharing-encouragement');
    } else {
      // Ultimate fallback: restart game
      Navigator.of(context).pushNamedAndRemoveUntil('/game', (route) => false);
    }
  }
  
  /// Handle post-registration navigation based on navigation config
  static void handlePostRegistrationNavigation(BuildContext context) {
    final postRegistrationRoute = Navigation.postRegistrationRoute;
    
    switch (postRegistrationRoute) {
      case 'sharing_flow':
        if (Features.sharingFlow) {
          Navigator.of(context).pushReplacementNamed('/sharing-encouragement');
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/game', (route) => false);
        }
        break;
      default:
        // Default fallback
        if (Features.sharingFlow) {
          Navigator.of(context).pushReplacementNamed('/sharing-encouragement');
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/game', (route) => false);
        }
    }
  }
  
  /// Navigate to sign-in screen if Google Sign-In is enabled
  static void navigateToSignIn(BuildContext context) {
    if (Features.googleSignIn) {
      Navigator.of(context).pushNamed('/sign-in');
    } else {
      // Show a message that sign-in is not available in this version
      _showFeatureNotAvailableDialog(context, 'Sign In');
    }
  }
  
  /// Show debug options if debug tools are enabled
  static void showDebugOptions(BuildContext context) {
    if (Features.debugTools) {
      // Show debug menu or navigate to debug screen
      showDialog(
        context: context,
        builder: (context) => const DebugOptionsDialog(),
      );
    }
  }
  
  /// Show a dialog when a feature is not available in the current build
  static void _showFeatureNotAvailableDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Feature Not Available'),
        content: Text('$featureName is not available in this version of the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Debug options dialog for internal builds
class DebugOptionsDialog extends StatelessWidget {
  const DebugOptionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Features.debugTools) {
      return const SizedBox.shrink();
    }

    return AlertDialog(
      title: const Text('Debug Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Current Build'),
            subtitle: Text(BuildConfig.isInternal ? 'Internal' : 'External'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Sample Puzzle'),
            trailing: Icon(
              Features.samplePuzzle ? Icons.check : Icons.close,
              color: Features.samplePuzzle ? Colors.green : Colors.red,
            ),
          ),
          ListTile(
            title: const Text('Early Access Registration'),
            trailing: Icon(
              Features.earlyAccessRegistration ? Icons.check : Icons.close,
              color: Features.earlyAccessRegistration ? Colors.green : Colors.red,
            ),
          ),
          ListTile(
            title: const Text('Sharing Flow'),
            trailing: Icon(
              Features.sharingFlow ? Icons.check : Icons.close,
              color: Features.sharingFlow ? Colors.green : Colors.red,
            ),
          ),
          ListTile(
            title: const Text('Google Sign-In'),
            trailing: Icon(
              Features.googleSignIn ? Icons.check : Icons.close,
              color: Features.googleSignIn ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (Features.experimentalFeatures)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/lottie-test');
            },
            child: const Text('Test Screen'),
          ),
      ],
    );
  }
}

/// Widget that conditionally renders its child based on feature flags
class FeatureGate extends StatelessWidget {
  /// The feature flag to check
  final bool feature;
  
  /// Widget to show when feature is enabled
  final Widget child;
  
  /// Optional widget to show when feature is disabled
  final Widget? fallback;
  
  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (feature) {
      return child;
    } else if (fallback != null) {
      return fallback!;
    } else {
      return const SizedBox.shrink();
    }
  }
}

/// Widget that only renders in debug/internal builds
class DebugOnly extends StatelessWidget {
  final Widget child;
  
  const DebugOnly({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: Features.debugTools,
      child: child,
    );
  }
}
