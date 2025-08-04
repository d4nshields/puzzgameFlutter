import 'package:flutter/material.dart';

/// @deprecated Use CozyPuzzleTheme instead. This theme will be removed in a future version.
/// 
/// Puzzle Bazaar theme inspired by the cozy, warm aesthetic of the brand image.
/// This theme has been replaced by CozyPuzzleTheme which follows the August 2025 
/// design system specifications.
@Deprecated('Use CozyPuzzleTheme instead. Will be removed in future version.')
class PuzzleBazaarTheme {
  // Color palette inspired by the Puzzle Bazaar image
  @Deprecated('Use CozyPuzzleTheme.warmSand instead')
  static const Color warmCream = Color(0xFFF5F1E8);
  
  @Deprecated('Use CozyPuzzleTheme.linenWhite instead')
  static const Color lightCream = Color(0xFFF0EBE3);
  
  @Deprecated('Use CozyPuzzleTheme.deepSlate instead')
  static const Color richBrown = Color(0xFF8B4513);
  
  @Deprecated('Use CozyPuzzleTheme.deepSlate instead')
  static const Color darkBrown = Color(0xFF654321);
  
  @Deprecated('Use CozyPuzzleTheme.goldenSandbar instead')
  static const Color mutedBlue = Color(0xFF6B8CAE);
  
  @Deprecated('Use CozyPuzzleTheme.goldenSandbar instead')
  static const Color deepBlue = Color(0xFF5A7A9A);
  
  @Deprecated('Use CozyPuzzleTheme.coralBlush instead')
  static const Color terracotta = Color(0xFFCD853F);
  
  @Deprecated('Use CozyPuzzleTheme.coralBlush instead')
  static const Color rust = Color(0xFFD2691E);
  
  @Deprecated('Use CozyPuzzleTheme.deepSlate instead')
  static const Color charcoal = Color(0xFF2F2F2F);
  
  @Deprecated('Use CozyPuzzleTheme.deepSlate instead')
  static const Color darkCharcoal = Color(0xFF1A1A1A);
  
  @Deprecated('Use CozyPuzzleTheme.goldenSandbar instead')
  static const Color goldenAmber = Color(0xFFDAA520);
  
  @Deprecated('Use CozyPuzzleTheme.goldenSandbar instead')
  static const Color warmAmber = Color(0xFFB8860B);
  
  @Deprecated('Use CozyPuzzleTheme.stoneGray instead')
  static const Color softGrey = Color(0xFF8E8E8E);
  
  @Deprecated('Use CozyPuzzleTheme.weatheredDriftwood instead')
  static const Color lightGrey = Color(0xFFE8E6E1);

  /// @deprecated Use CozyPuzzleTheme.headingLarge instead
  @Deprecated('Use CozyPuzzleTheme.headingLarge instead')
  static const TextStyle headingStyle = TextStyle(
    fontFamily: 'serif', // Georgia-style serif font
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: richBrown,
    letterSpacing: -0.5,
  );

  /// @deprecated Use CozyPuzzleTheme.headingMedium instead
  @Deprecated('Use CozyPuzzleTheme.headingMedium instead')
  static const TextStyle subheadingStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: darkBrown,
    letterSpacing: -0.2,
  );

  /// @deprecated Use CozyPuzzleTheme.bodyLarge instead
  @Deprecated('Use CozyPuzzleTheme.bodyLarge instead')
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: charcoal,
    height: 1.5,
    letterSpacing: 0.2,
  );

  /// @deprecated Use CozyPuzzleTheme.bodySmall instead
  @Deprecated('Use CozyPuzzleTheme.bodySmall instead')
  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: softGrey,
    height: 1.4,
  );

  /// @deprecated Use CozyPuzzleTheme.primaryButtonStyle instead
  @Deprecated('Use CozyPuzzleTheme.primaryButtonStyle instead')
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// @deprecated Use CozyPuzzleTheme gradient backgrounds instead
  @Deprecated('Use CozyPuzzleTheme gradient backgrounds instead')
  static LinearGradient get warmGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      lightCream,
      warmCream,
    ],
  );

  /// @deprecated Use CozyPuzzleTheme shadows instead
  @Deprecated('Use CozyPuzzleTheme shadows instead')
  static List<BoxShadow> get warmShadow => [
    BoxShadow(
      color: richBrown.withOpacity(0.1),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 2,
    ),
    BoxShadow(
      color: terracotta.withOpacity(0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// @deprecated Use CozyPuzzleTheme.primaryButtonStyle instead
  @Deprecated('Use CozyPuzzleTheme.primaryButtonStyle instead')
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: mutedBlue,
    foregroundColor: Colors.white,
    elevation: 4,
    shadowColor: mutedBlue.withOpacity(0.3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  );

  /// @deprecated Use CozyPuzzleTheme.secondaryButtonStyle instead
  @Deprecated('Use CozyPuzzleTheme.secondaryButtonStyle instead')
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: terracotta,
    foregroundColor: Colors.white,
    elevation: 3,
    shadowColor: terracotta.withOpacity(0.3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  );

  /// @deprecated Use CozyPuzzleTheme.textButtonStyle instead
  @Deprecated('Use CozyPuzzleTheme.textButtonStyle instead')
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: mutedBlue,
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
  );

  /// @deprecated Use CozyPuzzleTheme.primaryCardDecoration instead
  @Deprecated('Use CozyPuzzleTheme.primaryCardDecoration instead')
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: warmShadow,
    border: Border.all(
      color: lightGrey,
      width: 1,
    ),
  );

  /// @deprecated Use CozyPuzzleTheme.createProgressIndicator instead
  @Deprecated('Use CozyPuzzleTheme.createProgressIndicator instead')
  static LinearProgressIndicator createProgressIndicator() {
    return LinearProgressIndicator(
      backgroundColor: lightGrey,
      valueColor: AlwaysStoppedAnimation<Color>(mutedBlue),
      borderRadius: BorderRadius.circular(8),
    );
  }

  /// @deprecated Use CozyPuzzleTheme decorations instead
  @Deprecated('Use CozyPuzzleTheme decorations instead')
  static BoxDecoration get iconDecoration => BoxDecoration(
    color: warmCream,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: terracotta.withOpacity(0.3),
      width: 1.5,
    ),
  );
}
