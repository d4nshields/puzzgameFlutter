import 'package:flutter/material.dart';

/// Cozy Puzzle Theme based on August 2025 stylesheet from digital art department
/// Implements the new color palette with warm, cozy aesthetics
class CozyPuzzleTheme {
  // ===============================
  // Color Palette - August 2025
  // ===============================
  
  // Backgrounds & Structure
  static const Color linenWhite = Color(0xFFF9F7F3);      // Primary background
  static const Color warmSand = Color(0xFFE8E2D9);        // Secondary background/cards
  static const Color weatheredDriftwood = Color(0xFFB7AFA6); // Tertiary background/sidebars
  
  // Text & Subtext
  static const Color deepSlate = Color(0xFF3B3A36);        // Primary text
  static const Color stoneGray = Color(0xFF6C6862);        // Secondary text
  static const Color seaPebble = Color(0xFF9DA6A0);        // Tertiary text/status
  
  // Interactive Elements & Highlights
  static const Color goldenSandbar = Color(0xFFDDBF7A);    // Primary buttons/highlights
  static const Color seafoamMist = Color(0xFFA9C8BC);      // Secondary buttons/positive
  static const Color coralBlush = Color(0xFFE79D83);       // Alerts/friendly highlights
  
  // ===============================
  // Text Styles
  // ===============================
  
  /// Large heading style - for main titles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: deepSlate,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  /// Medium heading style - for section titles
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: deepSlate,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  /// Small heading style - for widget titles
  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: deepSlate,
    letterSpacing: 0,
    height: 1.4,
  );
  
  /// Primary body text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: deepSlate,
    height: 1.5,
    letterSpacing: 0.1,
  );
  
  /// Secondary body text
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: stoneGray,
    height: 1.5,
    letterSpacing: 0.1,
  );
  
  /// Tertiary/small text
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: seaPebble,
    height: 1.4,
    letterSpacing: 0.2,
  );
  
  /// Label text - for form labels and captions
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: stoneGray,
    letterSpacing: 0.1,
  );
  
  /// Small label text
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: seaPebble,
    letterSpacing: 0.5,
  );
  
  /// Button text style
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  
  // ===============================
  // Button Styles
  // ===============================
  
  /// Primary button style - for main actions like "Start Puzzle", "Next"
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: goldenSandbar,
    foregroundColor: deepSlate,
    elevation: 2,
    shadowColor: deepSlate.withOpacity(0.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: buttonText,
  );
  
  /// Secondary button style - for "Save", "Relax Mode", positive actions
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: seafoamMist,
    foregroundColor: deepSlate,
    elevation: 2,
    shadowColor: deepSlate.withOpacity(0.15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: buttonText,
  );
  
  /// Alert/highlight button style - for "New Puzzle", notifications
  static ButtonStyle get alertButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: coralBlush,
    foregroundColor: deepSlate,
    elevation: 2,
    shadowColor: deepSlate.withOpacity(0.15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: buttonText,
  );
  
  /// Text button style - for less prominent actions
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: stoneGray,
    textStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: stoneGray,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
  
  /// Outlined button style - for secondary actions
  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: deepSlate,
    side: BorderSide(color: seafoamMist, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: buttonText,
  );
  
  // ===============================
  // Decorations & Shadows
  // ===============================
  
  /// Primary card decoration - for content blocks, puzzle tiles
  static BoxDecoration get primaryCardDecoration => BoxDecoration(
    color: warmSand,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: deepSlate.withOpacity(0.08),
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
        color: deepSlate.withOpacity(0.06),
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
        color: deepSlate.withOpacity(0.15),
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
  // Interactive States
  // ===============================
  
  /// Focus/selection highlight color
  static Color get focusColor => seafoamMist;
  
  /// Hover highlight color for buttons
  static Color get hoverColor => coralBlush.withOpacity(0.1);
  
  /// Active/pressed state color
  static Color get activeColor => goldenSandbar.withOpacity(0.8);
  
  /// Disabled state colors
  static Color get disabledBackground => weatheredDriftwood.withOpacity(0.3);
  static Color get disabledText => seaPebble.withOpacity(0.6);
  
  // ===============================
  // Progress & Status Indicators
  // ===============================
  
  /// Progress bar with theme colors
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
          valueColor: AlwaysStoppedAnimation<Color>(goldenSandbar),
        ),
      ),
    );
  }
  
  /// Success indicator color
  static Color get successColor => seafoamMist;
  
  /// Warning indicator color  
  static Color get warningColor => goldenSandbar;
  
  /// Error indicator color
  static Color get errorColor => coralBlush;
  
  // ===============================
  // Material Theme Generation
  // ===============================
  
  /// Generate Material 3 ColorScheme from our cozy palette
  static ColorScheme get lightColorScheme => ColorScheme.light(
    // Core colors
    primary: goldenSandbar,
    onPrimary: deepSlate,
    primaryContainer: goldenSandbar.withOpacity(0.2),
    onPrimaryContainer: deepSlate,
    
    secondary: seafoamMist,
    onSecondary: deepSlate,
    secondaryContainer: seafoamMist.withOpacity(0.2),
    onSecondaryContainer: deepSlate,
    
    tertiary: coralBlush,
    onTertiary: deepSlate,
    tertiaryContainer: coralBlush.withOpacity(0.2),
    onTertiaryContainer: deepSlate,
    
    // Surface colors
    surface: linenWhite,
    onSurface: deepSlate,
    surfaceVariant: warmSand,
    onSurfaceVariant: stoneGray,
    
    // Background colors
    background: linenWhite,
    onBackground: deepSlate,
    
    // Error colors
    error: coralBlush,
    onError: linenWhite,
    
    // Other colors
    outline: weatheredDriftwood,
    outlineVariant: weatheredDriftwood.withOpacity(0.5),
    shadow: deepSlate.withOpacity(0.15),
    scrim: deepSlate.withOpacity(0.3),
    inverseSurface: deepSlate,
    onInverseSurface: linenWhite,
    inversePrimary: goldenSandbar.withOpacity(0.8),
  );
  
  /// Generate complete ThemeData with our cozy styling
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    
    // Text theme
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
      foregroundColor: deepSlate,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headingMedium,
      iconTheme: IconThemeData(color: stoneGray),
    ),
    
    // Card theme
    cardTheme: CardThemeData(
      color: warmSand,
      shadowColor: deepSlate.withOpacity(0.1),
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
        borderSide: BorderSide(color: seafoamMist, width: 2),
      ),
      labelStyle: labelLarge,
      hintStyle: bodyMedium.copyWith(color: seaPebble),
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
      color: stoneGray,
      size: 24,
    ),
    
    // Progress indicator theme
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: goldenSandbar,
      linearTrackColor: weatheredDriftwood.withOpacity(0.3),
    ),
    
    // Floating action button theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: goldenSandbar,
      foregroundColor: deepSlate,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
  
  // ===============================
  // Utility Methods
  // ===============================
  
  /// Get appropriate text color for background
  static Color getTextColorForBackground(Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.light ? deepSlate : linenWhite;
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
    required VoidCallback onPressed,
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
}
