// Fast Puzzle Selection Widget
// File: lib/game_module/widgets/puzzle_selection_widget.dart

import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module/services/puzzle_asset_manager.dart';
import 'dart:ui' as ui;

/// High-performance puzzle selection widget for browsing and selecting puzzles and grid sizes
class PuzzleSelectionWidget extends StatefulWidget {
  final PuzzleAssetManager assetManager;
  final Function(String puzzleId, String gridSize) onPuzzleSelected;
  final String? selectedPuzzleId;
  final String? selectedGridSize;

  const PuzzleSelectionWidget({
    super.key,
    required this.assetManager,
    required this.onPuzzleSelected,
    this.selectedPuzzleId,
    this.selectedGridSize,
  });

  @override
  State<PuzzleSelectionWidget> createState() => _PuzzleSelectionWidgetState();
}

class _PuzzleSelectionWidgetState extends State<PuzzleSelectionWidget> {
  List<PuzzleMetadata>? _puzzles;
  String? _selectedPuzzleId;
  String? _selectedGridSize;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedPuzzleId = widget.selectedPuzzleId;
    _selectedGridSize = widget.selectedGridSize;
    _loadPuzzles();
  }

  Future<void> _loadPuzzles() async {
    try {
      final puzzles = await widget.assetManager.getAvailablePuzzles();
      setState(() {
        _puzzles = puzzles;
        // Auto-select first puzzle if none selected
        if (_selectedPuzzleId == null && puzzles.isNotEmpty) {
          _selectedPuzzleId = puzzles.first.id;
          _selectedGridSize = puzzles.first.availableGridSizes.first;
        }
      });
    } catch (e) {
      debugPrint('Failed to load puzzles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_puzzles == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_puzzles!.isEmpty) {
      return const Center(
        child: Text('No puzzles available'),
      );
    }

    return Column(
      children: [
        // Puzzle selection tabs
        _buildPuzzleTabs(),
        
        const SizedBox(height: 16),
        
        // Grid size selection and preview
        Expanded(
          child: _buildGridSizeSelection(),
        ),
        
        const SizedBox(height: 16),
        
        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildPuzzleTabs() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _puzzles!.length,
              itemBuilder: (context, index) {
                final puzzle = _puzzles![index];
                final isSelected = puzzle.id == _selectedPuzzleId;
                
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    label: Text(puzzle.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedPuzzleId = puzzle.id;
                          _selectedGridSize = puzzle.availableGridSizes.first;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSizeSelection() {
    final selectedPuzzle = _puzzles!.firstWhere(
      (p) => p.id == _selectedPuzzleId,
      orElse: () => _puzzles!.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid size selector
        Text(
          'Select Grid Size for ${selectedPuzzle.name}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Grid size options with previews
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: selectedPuzzle.availableGridSizes.length,
            itemBuilder: (context, index) {
              final gridSize = selectedPuzzle.availableGridSizes[index];
              final isSelected = gridSize == _selectedGridSize;
              
              return _buildGridSizeCard(selectedPuzzle, gridSize, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridSizeCard(PuzzleMetadata puzzle, String gridSize, bool isSelected) {
    final dimensions = gridSize.split('x');
    final size = int.parse(dimensions[0]);
    final pieceCount = size * size;
    
    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Colors.blue[50] : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGridSize = gridSize;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: isSelected 
                ? Border.all(color: Colors.blue, width: 2)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Preview image (if available)
              if (puzzle.previewImage != null)
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CustomPaint(
                        painter: _PreviewImagePainter(puzzle.previewImage!),
                        child: Container(),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Icon(Icons.image, size: 48, color: Colors.grey),
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Grid size info
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      gridSize,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.blue : null,
                      ),
                    ),
                    Text(
                      '$pieceCount pieces',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _getDifficultyText(size),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getDifficultyColor(size),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final canSelect = _selectedPuzzleId != null && _selectedGridSize != null;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
          ),
        ),
        
        ElevatedButton.icon(
          onPressed: (_isLoading || !canSelect) ? null : _loadAndSelectPuzzle,
          icon: _isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(_isLoading ? 'Loading...' : 'Start Puzzle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _loadAndSelectPuzzle() async {
    if (_selectedPuzzleId == null || _selectedGridSize == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Preload the selected puzzle and grid size
      await widget.assetManager.loadPuzzleGridSize(
        _selectedPuzzleId!,
        _selectedGridSize!,
      );
      
      // Notify parent with selection
      widget.onPuzzleSelected(_selectedPuzzleId!, _selectedGridSize!);
      
      // Close the selection dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load puzzle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getDifficultyText(int gridSize) {
    if (gridSize <= 8) return 'Easy';
    if (gridSize <= 12) return 'Medium';
    return 'Hard';
  }

  Color _getDifficultyColor(int gridSize) {
    if (gridSize <= 8) return Colors.green;
    if (gridSize <= 12) return Colors.orange;
    return Colors.red;
  }
}

/// Custom painter for high-performance preview image rendering
class _PreviewImagePainter extends CustomPainter {
  final ui.Image image;

  _PreviewImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(
      0, 
      0, 
      image.width.toDouble(), 
      image.height.toDouble(),
    );
    
    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    canvas.drawImageRect(image, srcRect, destRect, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dialog wrapper for puzzle selection
class PuzzleSelectionDialog extends StatelessWidget {
  final PuzzleAssetManager assetManager;
  final Function(String puzzleId, String gridSize) onPuzzleSelected;
  final String? currentPuzzleId;
  final String? currentGridSize;

  const PuzzleSelectionDialog({
    super.key,
    required this.assetManager,
    required this.onPuzzleSelected,
    this.currentPuzzleId,
    this.currentGridSize,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Select Puzzle',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const Divider(),
            
            // Puzzle selection widget
            Expanded(
              child: PuzzleSelectionWidget(
                assetManager: assetManager,
                onPuzzleSelected: onPuzzleSelected,
                selectedPuzzleId: currentPuzzleId,
                selectedGridSize: currentGridSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the puzzle selection dialog
  static Future<void> show(
    BuildContext context,
    PuzzleAssetManager assetManager,
    Function(String puzzleId, String gridSize) onPuzzleSelected, {
    String? currentPuzzleId,
    String? currentGridSize,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PuzzleSelectionDialog(
        assetManager: assetManager,
        onPuzzleSelected: onPuzzleSelected,
        currentPuzzleId: currentPuzzleId,
        currentGridSize: currentGridSize,
      ),
    );
  }
}
