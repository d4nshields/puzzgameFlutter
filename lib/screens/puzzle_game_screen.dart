import 'package:flutter/material.dart';

class PuzzleGameScreen extends StatefulWidget {
  final String? puzzleId;
  final int difficulty;
  
  const PuzzleGameScreen({
    Key? key,
    this.puzzleId,
    this.difficulty = 1,
  }) : super(key: key);
  
  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen> {
  @override
  void initState() {
    super.initState();
    // The actual game is handled by GameScreen widget
    // This is just a placeholder that redirects to the proper game screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/game');
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Beige
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Loading puzzle...',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
      ),
    );
  }
}