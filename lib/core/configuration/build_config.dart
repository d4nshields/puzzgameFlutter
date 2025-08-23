/// Build-time configuration for feature flags with CORRECTED behavior
/// 
/// This system provides compile-time feature flag management with clear naming
/// and correct sample puzzle behavior (disabled for external builds).
/// 
/// Architecture Decision: Using compile-time constants ensures zero runtime 
/// overhead and enables tree-shaking of unused features.

// =============================================================================
// BUILD VARIANT SELECTION - CHANGE THIS TO SWITCH BUILDS
// =============================================================================

/// The active build variant - change this line to switch builds
/// 
/// CHANGE THIS LINE to switch between build variants:
/// - Use 'internal' for development/testing builds
/// - Use 'external' for production builds
const String _activeBuildVariant = 'internal';

// =============================================================================
// FEATURE FLAGS - CLEAR NAMING WITH CORRECTED BEHAVIOR
// =============================================================================

/// Feature flags with clear, descriptive names
/// 
/// CORRECTED BEHAVIOR: Sample puzzle is DISABLED in external builds
/// (not ready for users) and ENABLED in internal builds (for development)
class Features {
  Features._(); // Private constructor to prevent instantiation
  
  /// Enable sample puzzle (under active development)
  /// Internal: true (ENABLED for development and testing)
  /// External: false (DISABLED - not ready for users)
  static const bool samplePuzzle = _activeBuildVariant == 'internal';
  
  /// Enable Google Sign-In integration
  /// Internal: true (for testing)
  /// External: true (approved feature)
  static const bool googleSignIn = true;
  
  /// Enable early access registration flow
  /// Internal: true (for testing)
  /// External: true (approved feature)
  static const bool earlyAccessRegistration = true;
  
  /// Enable sharing and badges system
  /// Internal: true (for testing complete flow)
  /// External: true (approved feature)
  static const bool sharingFlow = true;
  
  /// Enable puzzle library teaser
  /// Internal: true (for testing)
  /// External: true (marketing teaser to encourage registration)
  static const bool puzzleLibraryTeaser = true;
  
  /// Enable debug tools and overlays
  /// Internal: true (for development)
  /// External: false (clean user experience)
  static const bool debugTools = _activeBuildVariant == 'internal';
  
  /// Enable experimental features under development
  /// Internal: true (for testing)
  /// External: false (stability)
  static const bool experimentalFeatures = _activeBuildVariant == 'internal';
  
  /// Enable detailed analytics and logging
  /// Internal: true (for development insights)
  /// External: false (user privacy)
  static const bool detailedAnalytics = _activeBuildVariant == 'internal';
  
  /// Enable performance monitoring overlays
  /// Internal: true (for optimization)
  /// External: false (clean experience)
  static const bool performanceMonitoring = _activeBuildVariant == 'internal';
}

/// Debug configuration
class Debug {
  Debug._(); // Private constructor to prevent instantiation
  
  /// Whether debug mode is enabled overall
  static const bool enabled = _activeBuildVariant == 'internal';
  
  /// Enable verbose logging
  static const bool verboseLogging = _activeBuildVariant == 'internal';
  
  /// Show performance overlay (can be toggled via settings)
  static const bool performanceOverlay = false; // Default off, can be enabled via settings
  
  /// Show widget inspector (can be toggled via settings)
  static const bool widgetInspector = false; // Default off, can be enabled via settings
}

/// Navigation configuration based on feature availability
class Navigation {
  Navigation._(); // Private constructor to prevent instantiation
  
  /// Initial route when app starts
  /// Internal: sample_puzzle (test the puzzle under development)
  /// External: early_access_registration (skip puzzle, not ready for users)
  static const String initialRoute = Features.samplePuzzle 
      ? 'sample_puzzle' 
      : 'early_access_registration';
  
  /// Route to navigate to after game completion
  static const String postGameRoute = 'early_access_registration';
  
  /// Route to navigate to after registration
  static const String postRegistrationRoute = 'sharing_flow';
}

// =============================================================================
// BUILD CONFIGURATION (for compatibility and information)
// =============================================================================

/// Build configuration information
class BuildConfig {
  /// Current build variant name
  static String get currentVariant => _activeBuildVariant;
  
  /// Whether this is an internal build
  static bool get isInternal => _activeBuildVariant == 'internal';
  
  /// Whether this is an external build
  static bool get isExternal => _activeBuildVariant == 'external';
  
  /// Get a summary of current feature flags (for debugging)
  static Map<String, bool> get featureSummary => {
    'samplePuzzle': Features.samplePuzzle,
    'googleSignIn': Features.googleSignIn,
    'earlyAccessRegistration': Features.earlyAccessRegistration,
    'sharingFlow': Features.sharingFlow,
    'puzzleLibraryTeaser': Features.puzzleLibraryTeaser,
    'debugTools': Features.debugTools,
    'experimentalFeatures': Features.experimentalFeatures,
    'detailedAnalytics': Features.detailedAnalytics,
    'performanceMonitoring': Features.performanceMonitoring,
  };
  
  /// Get a summary of current debug settings (for debugging)
  static Map<String, bool> get debugSummary => {
    'enabled': Debug.enabled,
    'verboseLogging': Debug.verboseLogging,
    'performanceOverlay': Debug.performanceOverlay,
    'widgetInspector': Debug.widgetInspector,
  };
  
  /// Get navigation configuration summary
  static Map<String, String> get navigationSummary => {
    'initialRoute': Navigation.initialRoute,
    'postGameRoute': Navigation.postGameRoute,
    'postRegistrationRoute': Navigation.postRegistrationRoute,
  };
}

// =============================================================================
// BUILD INFORMATION (for build scripts and debugging)
// =============================================================================

/// Build information for scripts and debugging
class BuildInfo {
  static String get variantName => _activeBuildVariant;
  
  static String get buildSummary {
    final variant = _activeBuildVariant.toUpperCase();
    final features = BuildConfig.featureSummary;
    final debug = BuildConfig.debugSummary;
    final navigation = BuildConfig.navigationSummary;
    
    final buffer = StringBuffer();
    buffer.writeln('Build Variant: $variant');
    buffer.writeln('Features:');
    features.forEach((key, value) {
      buffer.writeln('  $key: ${value ? "ENABLED" : "DISABLED"}');
    });
    buffer.writeln('Debug Settings:');
    debug.forEach((key, value) {
      buffer.writeln('  $key: ${value ? "ENABLED" : "DISABLED"}');
    });
    buffer.writeln('Navigation:');
    navigation.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    
    return buffer.toString();
  }
}

// =============================================================================
// BEHAVIOR VERIFICATION SUMMARY
// =============================================================================

/// Summary of the corrected behavior for verification
/// 
/// CORRECTED BEHAVIOR:
/// - External builds: Sample puzzle DISABLED (not ready for users)
/// - Internal builds: Sample puzzle ENABLED (for development)
/// - Clear feature naming (no confusing "skip" terminology)
/// - Navigation automatically adapts based on feature availability
class BehaviorSummary {
  static String get summary {
    final buffer = StringBuffer();
    buffer.writeln('=== CORRECTED FEATURE FLAG BEHAVIOR ===');
    buffer.writeln('Build Variant: ${_activeBuildVariant.toUpperCase()}');
    buffer.writeln('');
    buffer.writeln('Sample Puzzle:');
    if (Features.samplePuzzle) {
      buffer.writeln('  ✅ ENABLED (for development and testing)');
      buffer.writeln('  ℹ️  Users will see the sample puzzle under development');
    } else {
      buffer.writeln('  ❌ DISABLED (not ready for external users)');
      buffer.writeln('  ℹ️  Users will skip sample puzzle and go to early access');
    }
    buffer.writeln('');
    buffer.writeln('Navigation Flow:');
    buffer.writeln('  Start: ${Navigation.initialRoute}');
    buffer.writeln('  After Game: ${Navigation.postGameRoute}');
    buffer.writeln('  After Registration: ${Navigation.postRegistrationRoute}');
    buffer.writeln('');
    buffer.writeln('This behavior matches the requirement:');
    buffer.writeln('"Sample puzzle under development, not ready for external users"');
    
    return buffer.toString();
  }
}
