import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/game_module2.dart';

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
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeGame();
  }
  
  Future<void> _initializeGame() async {
    try {
      // Check if game module is initialized
      final gameModule = PuzzleGameModule2.instance;
      
      // Start the game with specified parameters
      await gameModule.startGame(
        difficulty: widget.difficulty,
        puzzleId: widget.puzzleId ?? 'sample_puzzle_01',
        forceNewGame: true,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing game: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
    
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5DC),
        appBar: AppBar(
          title: const Text('Puzzle Nook'),
          backgroundColor: const Color(0xFF8B4513),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                'Failed to load puzzle',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/menu');
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Menu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Get the workspace widget from the game module
    final workspaceWidget = PuzzleGameModule2.instance.getWorkspaceWidget();
    
    if (workspaceWidget == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5DC),
        appBar: AppBar(
          title: const Text('Puzzle Nook'),
          backgroundColor: const Color(0xFF8B4513),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No active game'),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('Puzzle Nook'),
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _showExitConfirmation(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _showRestartConfirmation(context);
            },
            tooltip: 'Restart Puzzle',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog(context);
            },
            tooltip: 'Help',
          ),
        ],
      ),
      body: workspaceWidget,
    );
  }
  
  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Puzzle?'),
        content: const Text('Your progress will be lost. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.pushReplacementNamed(context, '/menu');
            },
            child: const Text(
              'Exit',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showRestartConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Puzzle?'),
        content: const Text('This will shuffle all pieces. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              setState(() => _isLoading = true);
              await _initializeGame();
            },
            child: const Text(
              'Restart',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Drag pieces from the tray to the workspace'),
              SizedBox(height: 8),
              Text('• Pieces will snap into place when positioned correctly'),
              SizedBox(height: 8),
              Text('• Double-tap to rotate pieces (if enabled)'),
              SizedBox(height: 8),
              Text('• Pinch to zoom in/out on the workspace'),
              SizedBox(height: 8),
              Text('• Complete the puzzle by placing all pieces correctly'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    // Don't dispose the game module here as it's a singleton
    // Just let it know the screen is closing
    super.dispose();
  }
}