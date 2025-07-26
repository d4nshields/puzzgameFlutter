// Theme-related tests for Puzzle Nook

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/presentation/theme/puzzle_bazaar_theme.dart';

void main() {
  group('PuzzleBazaarTheme Tests', () {
    test('theme colors are properly defined', () {
      // Test that all theme colors are valid
      expect(PuzzleBazaarTheme.warmCream, const Color(0xFFF5F1E8));
      expect(PuzzleBazaarTheme.richBrown, const Color(0xFF8B4513));
      expect(PuzzleBazaarTheme.mutedBlue, const Color(0xFF6B8CAE));
      expect(PuzzleBazaarTheme.terracotta, const Color(0xFFCD853F));
      expect(PuzzleBazaarTheme.goldenAmber, const Color(0xFFDAA520));
    });

    test('text styles are properly configured', () {
      // Test that text styles have expected properties
      expect(PuzzleBazaarTheme.headingStyle.fontSize, 32);
      expect(PuzzleBazaarTheme.headingStyle.fontWeight, FontWeight.bold);
      expect(PuzzleBazaarTheme.headingStyle.color, PuzzleBazaarTheme.richBrown);
      
      expect(PuzzleBazaarTheme.bodyStyle.fontSize, 16);
      expect(PuzzleBazaarTheme.bodyStyle.color, PuzzleBazaarTheme.charcoal);
    });

    test('button styles are properly configured', () {
      // Test that button styles are not null
      expect(PuzzleBazaarTheme.primaryButtonStyle, isNotNull);
      expect(PuzzleBazaarTheme.secondaryButtonStyle, isNotNull);
      expect(PuzzleBazaarTheme.textButtonStyle, isNotNull);
    });

    test('gradient and shadows are properly configured', () {
      // Test that gradient and shadows are properly set up
      expect(PuzzleBazaarTheme.warmGradient, isA<LinearGradient>());
      expect(PuzzleBazaarTheme.warmShadow, isA<List<BoxShadow>>());
      expect(PuzzleBazaarTheme.warmShadow.length, greaterThan(0));
    });

    test('card decoration is properly configured', () {
      // Test that card decoration is set up correctly
      final decoration = PuzzleBazaarTheme.cardDecoration;
      expect(decoration, isA<BoxDecoration>());
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, isNotNull);
      expect(decoration.boxShadow, isNotNull);
    });

    testWidgets('progress indicator can be created', (WidgetTester tester) async {
      // Test that the progress indicator can be created without errors
      final progressIndicator = PuzzleBazaarTheme.createProgressIndicator();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: progressIndicator,
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
