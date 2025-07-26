import 'package:flutter/material.dart';

/// Puzzle Bazaar theme inspired by the cozy, warm aesthetic of the brand image
class PuzzleBazaarTheme {
  // Color palette inspired by the Puzzle Bazaar image
  static const Color warmCream = Color(0xFFF5F1E8);
  static const Color lightCream = Color(0xFFF0EBE3);
  static const Color richBrown = Color(0xFF8B4513);
  static const Color darkBrown = Color(0xFF654321);
  static const Color mutedBlue = Color(0xFF6B8CAE);
  static const Color deepBlue = Color(0xFF5A7A9A);
  static const Color terracotta = Color(0xFFCD853F);
  static const Color rust = Color(0xFFD2691E);
  static const Color charcoal = Color(0xFF2F2F2F);
  static const Color darkCharcoal = Color(0xFF1A1A1A);
  static const Color goldenAmber = Color(0xFFDAA520);
  static const Color warmAmber = Color(0xFFB8860B);
  static const Color softGrey = Color(0xFF8E8E8E);
  static const Color lightGrey = Color(0xFFE8E6E1);

  /// Primary text style matching the Puzzle Bazaar branding
  static const TextStyle headingStyle = TextStyle(
    fontFamily: 'serif', // Georgia-style serif font
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: richBrown,
    letterSpacing: -0.5,
  );

  /// Secondary heading style
  static const TextStyle subheadingStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: darkBrown,
    letterSpacing: -0.2,
  );

  /// Body text style
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: charcoal,
    height: 1.5,
    letterSpacing: 0.2,
  );

  /// Caption text style
  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: softGrey,
    height: 1.4,
  );

  /// Button text style
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Create a gradient background like the cozy scene
  static LinearGradient get warmGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      lightCream,
      warmCream,
    ],
  );

  /// Create a warm shadow for cards
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

  /// Primary button style matching the theme
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

  /// Secondary button style
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

  /// Text button style
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: mutedBlue,
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
  );

  /// Card decoration with warm shadows
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: warmShadow,
    border: Border.all(
      color: lightGrey,
      width: 1,
    ),
  );

  /// Progress indicator theme
  static LinearProgressIndicator createProgressIndicator() {
    return LinearProgressIndicator(
      backgroundColor: lightGrey,
      valueColor: AlwaysStoppedAnimation<Color>(mutedBlue),
      borderRadius: BorderRadius.circular(8),
    );
  }

  /// Icon decoration for feature items
  static BoxDecoration get iconDecoration => BoxDecoration(
    color: warmCream,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: terracotta.withOpacity(0.3),
      width: 1.5,
    ),
  );
}
