import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Test screen to verify Lottie animation is working
class LottieTestScreen extends StatelessWidget {
  const LottieTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lottie Animation Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Test the Lottie animation
            Lottie.asset(
              'assets/animations/loading_puzzle_pieces.json',
              width: 150,
              height: 150,
              repeat: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Testing Lottie Animation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Game'),
            ),
          ],
        ),
      ),
    );
  }
}
