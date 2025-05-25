import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:puzzgame_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation Test', () {
    testWidgets('Can navigate to game screen and back', (WidgetTester tester) async {
      // Load the app
      app.main();
      await tester.pumpAndSettle();

      // Verify we're on the home screen
      expect(find.text('Welcome to Nook!'), findsOneWidget);
      
      // Tap on the start game button
      await tester.tap(find.text('Start New Game'));
      await tester.pumpAndSettle();
      
      // Verify we're on the game screen (looking for "Game in Progress")
      expect(find.text('Game in Progress'), findsOneWidget);
      
      // End the game
      await tester.tap(find.text('End Game'));
      await tester.pumpAndSettle();
      
      // Verify we're back on the home screen
      expect(find.text('Welcome to Nook!'), findsOneWidget);
    });
    
    testWidgets('Can navigate to settings screen and back', (WidgetTester tester) async {
      // Load the app
      app.main();
      await tester.pumpAndSettle();
      
      // Tap on the settings button
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      
      // Verify we're on the settings screen
      expect(find.text('Game Settings'), findsOneWidget);
      
      // Change difficulty to Hard
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();
      
      // Save settings
      await tester.tap(find.text('Save Settings'));
      await tester.pumpAndSettle();
      
      // Verify we're back on the home screen
      expect(find.text('Welcome to Nook!'), findsOneWidget);
    });
  });
}
