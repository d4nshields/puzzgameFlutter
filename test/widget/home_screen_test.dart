import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/presentation/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen has correct widgets', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: HomeScreen(),
      ),
    ));

    // Verify that the welcome text appears
    expect(find.text('Welcome to Puzzle Bazaar!'), findsOneWidget);
    
    // Verify that the app bar title appears
    expect(find.text('Puzzle Bazaar'), findsOneWidget);
    
    // Verify that the buttons appear
    expect(find.text('Start New Game'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    
    // Tap the About button and verify dialog appears
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    
    // Verify the about dialog content
    // Note: "Puzzle Bazaar" now appears twice - once in app bar, once in dialog
    expect(find.text('Puzzle Bazaar'), findsNWidgets(2));
    expect(find.text('1.0.0'), findsOneWidget);
  });
}
