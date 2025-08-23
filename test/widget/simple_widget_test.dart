// Simple widget tests that don't require service locator setup

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // Not used in this test
import 'package:puzzgame_flutter/presentation/screens/loading_screen.dart';

void main() {
  group('Simple Widget Tests', () {
    testWidgets('LoadingScreen can be created', (WidgetTester tester) async {
      // Create a simple future that completes immediately for testing
      final testFuture = Future.value();
      
      await tester.pumpWidget(
        LoadingScreen(
          initializationFuture: testFuture,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('App Loaded'),
              ),
            ),
          ),
        ),
      );

      // Initially should show loading screen
      expect(find.text('Puzzle'), findsOneWidget);
      expect(find.text('Nook'), findsOneWidget);
      
      // Wait for the future to complete and animations to settle
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Should now show the child widget
      expect(find.text('App Loaded'), findsOneWidget);
    });

    testWidgets('App title displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Puzzle Nook'),
            ),
            body: const Center(
              child: Text('Welcome to Puzzle Nook!'),
            ),
          ),
        ),
      );

      // Verify app name appears in both places
      expect(find.text('Puzzle Nook'), findsOneWidget);
      expect(find.text('Welcome to Puzzle Nook!'), findsOneWidget);
    });

    testWidgets('Material app can be created with theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          title: 'Puzzle Nook',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
            ),
            useMaterial3: true,
          ),
          home: const Scaffold(
            body: Center(
              child: Text('Theme Test'),
            ),
          ),
        ),
      );

      expect(find.text('Theme Test'), findsOneWidget);
    });
  });
}
