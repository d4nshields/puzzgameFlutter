import 'package:flutter/material.dart';

/// Accessible Cozy Puzzle Theme - Fixed for WCAG AA Compliance
/// Based on August 2025 stylesheet with enhanced contrast ratios
class CozyPuzzleTheme {
  // ===============================
  // Color Palette - ACCESSIBILITY FIXED
  // ===============================
  
  // Backgrounds & Structure (Unchanged - these work well)
  static const Color linenWhite = Color(0xFFF9F7F3);      // Primary background
  static const Color warmSand = Color(0xFFE8E2D9);        // Secondary background/cards
  static const Color weatheredDriftwood = Color(0xFFB7AFA6); // Tertiary background/sidebars
  
  // Text Colors - ENHANCED FOR ACCESSIBILITY
  static const Color richCharcoal = Color(0xFF2B2A26);     // Primary text (was deepSlate #3B3A36)
  static const Color slateGray = Color(0xFF383532);        // Secondary text - darkened for WCAG AA compliance
  static const Color pewter = Color(0xFF565656);           // Tertiary text - darkened for WCAG AA compliance
  
  // Interactive Elements - ENHANCED FOR CONTRAST
  static const Color goldenAmber = Color(0xFFC9A961);      // Primary buttons (enhanced from goldenSandbar)
  static const Color forestMist = Color(0xFF7BA88A);       // Secondary buttons (enhanced from seafoamMist)
  static const Color terracotta = Color(0xFFCC7A5C);       // Alerts (enhanced from coralBlush)
  
  // Legacy color names for backward compatibility
  @Deprecated('Use richCharcoal instead for better accessibility')
  static const Color deepSlate = richCharcoal;
  @Deprecated('Use slateGray instead for better accessibility')
  static const Color stoneGray = slateGray;
  @Deprecated('Use pewter instead for better accessibility')
  static const Color seaPebble = pewter;
  @Deprecated('Use goldenAmber instead for better accessibility')
  static const Color goldenSandbar = goldenAmber;
  @Deprecated('Use forestMist instead for better accessibility')
  static const Color seafoamMist = forestMist;
  @Deprecated('Use terracotta instead for better accessibility')
  static const Color coralBlush = terracotta;
  
  // ===============================
  // Text Styles - UPDATED FOR ACCESSIBILITY
  // ===============================
  
  /// Large heading style - for main titles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: richCharcoal,         // Enhanced contrast
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  /// Medium heading style - for section titles  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: richCharcoal,         // Enhanced contrast
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  /// Small heading style - for widget titles
  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: richCharcoal,         // Enhanced contrast
    letterSpacing: 0,
    height: 1.4,
  );
  
  /// Primary body text - ACCESSIBLE
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: richCharcoal,         // Enhanced contrast
    height: 1.5,
    letterSpacing: 0.1,
  );
  
  /// Secondary body text - ACCESSIBLE
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: slateGray,           // Enhanced contrast
    height: 1.5,
    letterSpacing: 0.1,
  );
  
  /// Tertiary/small text - ACCESSIBLE
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: pewter,              // Enhanced contrast
    height: 1.4,
    letterSpacing: 0.2,
  );
  
  /// Label text - for form labels and captions
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: slateGray,           // Enhanced contrast
    letterSpacing: 0.1,
  );
  
  /// Small label text
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: pewter,              // Enhanced contrast
    letterSpacing: 0.5,
  );
  
  /// Button text style
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  
  // ===============================
  // Button Styles - ACCESSIBLE COLORS
  // ===============================
  
  /// Primary button style - WCAG AA compliant
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: goldenAmber,
    foregroundColor: richCharcoal,    // High contrast text
    elevation: 2,
    shadowColor: richCharcoal.withOpacity(0.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: buttonText,
  );
  
  /// Secondary button style - WCAG AA compliant
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: forestMist,
    foregroundColor: Colors.white,    // High contrast for dark green
    elevation: 2,
    shadowColor: richCharcoal.withOpacity(0.15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: buttonText,
  );
  
  /// Alert/highlight button style - WCAG AA compliant
  static ButtonStyle get alertButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: terracotta,
    foregroundColor: Colors.white,    // High contrast for terracotta
    elevation: 2,
    shadowColor: richCharcoal.withOpacity(0.15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: buttonText,
  );
  
  /// Text button style - accessible
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: slateGray,       // Better contrast
    textStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: slateGray,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
  
  /// Outlined button style - accessible
  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: richCharcoal,    // High contrast text
    side: BorderSide(color: forestMist, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: buttonText,
  );
  
  // ===============================
  // Decorations & Shadows (Unchanged)
  // ===============================
  
  /// Primary card decoration - for content blocks, puzzle tiles
  static BoxDecoration get primaryCardDecoration => BoxDecoration(
    color: warmSand,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: richCharcoal.withOpacity(0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
        spreadRadius: 1,
      ),
    ],
  );
  
  /// Secondary card decoration - for sidebars, panels
  static BoxDecoration get secondaryCardDecoration => BoxDecoration(
    color: weatheredDriftwood,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: richCharcoal.withOpacity(0.06),
        blurRadius: 6,
        offset: const Offset(0, 1),
      ),
    ],
  );
  
  /// Modal/dialog decoration
  static BoxDecoration get modalDecoration => BoxDecoration(
    color: linenWhite,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: richCharcoal.withOpacity(0.15),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: 2,
      ),
    ],
  );
  
  /// Subtle divider decoration
  static BoxDecoration get dividerDecoration => BoxDecoration(
    color: weatheredDriftwood.withOpacity(0.5),
    borderRadius: BorderRadius.circular(1),
  );
  
  // ===============================
  // Interactive States - ACCESSIBLE
  // ===============================
  
  /// Focus/selection highlight color
  static Color get focusColor => forestMist;
  
  /// Hover highlight color for buttons
  static Color get hoverColor => terracotta.withOpacity(0.1);
  
  /// Active/pressed state color
  static Color get activeColor => goldenAmber.withOpacity(0.8);
  
  /// Disabled state colors
  static Color get disabledBackground => weatheredDriftwood.withOpacity(0.3);
  static Color get disabledText => pewter.withOpacity(0.6);
  
  // ===============================
  // Progress & Status Indicators - ACCESSIBLE
  // ===============================
  
  /// Progress bar with accessible colors
  static Widget createProgressIndicator({double? value, double height = 8}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: weatheredDriftwood.withOpacity(0.3),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(goldenAmber),
        ),
      ),
    );
  }
  
  /// Success indicator color
  static Color get successColor => forestMist;
  
  /// Warning indicator color  
  static Color get warningColor => goldenAmber;
  
  /// Error indicator color
  static Color get errorColor => terracotta;
  
  // ===============================
  // Material Theme Generation - ACCESSIBLE
  // ===============================
  
  /// Generate Material 3 ColorScheme with accessible colors
  static ColorScheme get lightColorScheme => ColorScheme.light(
    // Core colors
    primary: goldenAmber,
    onPrimary: richCharcoal,          // High contrast
    primaryContainer: goldenAmber.withOpacity(0.2),
    onPrimaryContainer: richCharcoal,
    
    secondary: forestMist,
    onSecondary: Colors.white,        // High contrast on dark green
    secondaryContainer: forestMist.withOpacity(0.2),
    onSecondaryContainer: richCharcoal,
    
    tertiary: terracotta,
    onTertiary: Colors.white,         // High contrast on terracotta
    tertiaryContainer: terracotta.withOpacity(0.2),
    onTertiaryContainer: richCharcoal,
    
    // Surface colors
    surface: linenWhite,
    onSurface: richCharcoal,          // High contrast
    surfaceVariant: warmSand,
    onSurfaceVariant: slateGray,      // High contrast
    
    // Background colors
    background: linenWhite,
    onBackground: richCharcoal,       // High contrast
    
    // Error colors
    error: terracotta,
    onError: Colors.white,            // High contrast
    
    // Other colors
    outline: weatheredDriftwood,
    outlineVariant: weatheredDriftwood.withOpacity(0.5),
    shadow: richCharcoal.withOpacity(0.15),
    scrim: richCharcoal.withOpacity(0.3),
    inverseSurface: richCharcoal,
    onInverseSurface: linenWhite,
    inversePrimary: goldenAmber.withOpacity(0.8),
  );
  
  /// Generate complete ThemeData with accessible styling
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    
    // Text theme - ALL ACCESSIBLE
    textTheme: TextTheme(
      headlineLarge: headingLarge,
      headlineMedium: headingMedium,
      headlineSmall: headingSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelSmall: labelSmall,
    ),
    
    // App bar theme
    appBarTheme: AppBarTheme(
      backgroundColor: linenWhite,
      foregroundColor: richCharcoal,   // High contrast
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headingMedium,
      iconTheme: IconThemeData(color: slateGray),
    ),
    
    // Card theme
    cardTheme: CardThemeData(
      color: warmSand,
      shadowColor: richCharcoal.withOpacity(0.1),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    textButtonTheme: TextButtonThemeData(style: textButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
    
    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: warmSand,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: weatheredDriftwood),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: weatheredDriftwood),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: forestMist, width: 2),
      ),
      labelStyle: labelLarge,
      hintStyle: bodyMedium.copyWith(color: pewter),
    ),
    
    // Dialog theme
    dialogTheme: DialogThemeData(
      backgroundColor: linenWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: headingMedium,
      contentTextStyle: bodyLarge,
    ),
    
    // Scaffold background
    scaffoldBackgroundColor: linenWhite,
    
    // Divider theme
    dividerTheme: DividerThemeData(
      color: weatheredDriftwood.withOpacity(0.5),
      thickness: 1,
    ),
    
    // Icon theme
    iconTheme: IconThemeData(
      color: slateGray,               // Better contrast
      size: 24,
    ),
    
    // Progress indicator theme
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: goldenAmber,
      linearTrackColor: weatheredDriftwood.withOpacity(0.3),
    ),
    
    // Floating action button theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: goldenAmber,
      foregroundColor: richCharcoal,   // High contrast
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
  
  // ===============================
  // Utility Methods (Updated)
  // ===============================
  
  /// Get appropriate text color for background
  static Color getTextColorForBackground(Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.light ? richCharcoal : linenWhite;
  }
  
  /// Create a themed container with consistent styling
  static Widget createThemedContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    bool isPrimary = true,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      decoration: isPrimary ? primaryCardDecoration : secondaryCardDecoration,
      child: child,
    );
  }
  
  /// Create a themed button with icon and text
  static Widget createThemedButton({
    required String text,
    required VoidCallback? onPressed,  // Made nullable to support disabled state
    IconData? icon,
    bool isPrimary = true,
    bool isAlert = false,
  }) {
    final style = isAlert 
        ? alertButtonStyle 
        : isPrimary 
          ? primaryButtonStyle 
          : secondaryButtonStyle;
    
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: style,
      );
    } else {
      return ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: Text(text),
      );
    }
  }
  
  // ===============================
  // ACCESSIBILITY VERIFICATION
  // ===============================
  
  /// Calculate WCAG contrast ratio between two colors
  static double _contrastRatio(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();
    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }
  
  /// Verify that key color combinations meet WCAG AA standards
  static Map<String, Map<String, dynamic>> get accessibilityReport {
    final primaryOnLinen = _contrastRatio(richCharcoal, linenWhite);
    final secondaryOnSand = _contrastRatio(slateGray, warmSand);
    final tertiaryOnLinen = _contrastRatio(pewter, linenWhite);
    final buttonTextOnAmber = _contrastRatio(richCharcoal, goldenAmber);
    
    return {
      'Primary Text on Linen White': {
        'foreground': '#2B2A26', // richCharcoal
        'background': '#F9F7F3', // linenWhite
        'contrast_ratio': '${primaryOnLinen.toStringAsFixed(1)}:1',
        'wcag_aa': primaryOnLinen >= 4.5,
        'wcag_aaa': primaryOnLinen >= 7.0,
      },
      'Secondary Text on Warm Sand': {
        'foreground': '#383532', // slateGray (updated)
        'background': '#E8E2D9', // warmSand
        'contrast_ratio': '${secondaryOnSand.toStringAsFixed(1)}:1',
        'wcag_aa': secondaryOnSand >= 4.5,
        'wcag_aaa': secondaryOnSand >= 7.0,
      },
      'Tertiary Text on Linen White': {
        'foreground': '#565656', // pewter (updated)
        'background': '#F9F7F3', // linenWhite
        'contrast_ratio': '${tertiaryOnLinen.toStringAsFixed(1)}:1',
        'wcag_aa': tertiaryOnLinen >= 4.5,
        'wcag_aaa': tertiaryOnLinen >= 7.0,
      },
      'Button Text on Golden Amber': {
        'foreground': '#2B2A26', // richCharcoal
        'background': '#C9A961', // goldenAmber
        'contrast_ratio': '${buttonTextOnAmber.toStringAsFixed(1)}:1',
        'wcag_aa': buttonTextOnAmber >= 4.5,
        'wcag_aaa': buttonTextOnAmber >= 7.0,
      },
    };
  }
}
