import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui' as ui;

/// Debug tool to analyze exact positioning coordinates and identify off-by-one errors
class PositioningDebugScreen extends StatefulWidget {
  const PositioningDebugScreen({super.key});

  @override
  State<PositioningDebugScreen> createState() => _PositioningDebugScreenState();
}

class _PositioningDebugScreenState extends State<PositioningDebugScreen> {
  Map<String, dynamic>? _metadata;
  bool _isLoading = true;
  String _selectedPieceId = '';
  List<String> _allPieceIds = [];
  ui.Image? _selectedPieceImage;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final metadataPath = 'assets/puzzles/sample_puzzle_01/layouts/15x15_optimized/optimization_metadata.json';
      final metadataJson = await rootBundle.loadString(metadataPath);
      _metadata = json.decode(metadataJson);
      
      final pieces = _metadata!['pieces'] as Map<String, dynamic>;
      _allPieceIds = pieces.keys.toList()..sort();
      
      if (_allPieceIds.isNotEmpty) {
        _selectedPieceId = _allPieceIds.first;
        await _loadSelectedPiece();
      }
      
      setState(() => _isLoading = false);
      
    } catch (e) {
      print('PositioningDebug: Failed to load metadata: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSelectedPiece() async {
    if (_selectedPieceId.isEmpty) return;
    
    try {
      final imagePath = 'assets/puzzles/sample_puzzle_01/layouts/15x15_optimized/pieces/$_selectedPieceId.png';
      final imageData = await rootBundle.load(imagePath);
      final codec = await ui.instantiateImageCodec(imageData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      
      _selectedPieceImage?.dispose();
      _selectedPieceImage = frame.image;
      
      setState(() {});
      
    } catch (e) {
      print('PositioningDebug: Failed to load piece $_selectedPieceId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Positioning Debug'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPieceSelector(),
                _buildCoordinateAnalysis(),
                Expanded(child: _buildGapAnalysis()),
              ],
            ),
    );
  }

  Widget _buildPieceSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.teal[50],
      child: Row(
        children: [
          const Text('Piece: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedPieceId.isNotEmpty ? _selectedPieceId : null,
              hint: const Text('Select piece'),
              items: _allPieceIds.map((pieceId) => DropdownMenuItem(
                value: pieceId,
                child: Text(pieceId),
              )).toList(),
              onChanged: (value) async {
                if (value != null) {
                  _selectedPieceId = value;
                  await _loadSelectedPiece();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateAnalysis() {
    if (_selectedPieceId.isEmpty || _metadata == null) {
      return const SizedBox.shrink();
    }

    final pieces = _metadata!['pieces'] as Map<String, dynamic>;
    final pieceData = pieces[_selectedPieceId];
    final bounds = pieceData['bounds'];
    
    // Extract metadata values
    final metaLeft = bounds['left'];
    final metaTop = bounds['top'];
    final metaRight = bounds['right'];
    final metaBottom = bounds['bottom'];
    final metaWidth = bounds['width'];
    final metaHeight = bounds['height'];
    
    // Calculate values
    final calculatedWidth = metaRight - metaLeft + 1;  // Inclusive bounds
    final calculatedHeight = metaBottom - metaTop + 1; // Inclusive bounds
    final exclusiveWidth = metaRight - metaLeft;       // Exclusive bounds
    final exclusiveHeight = metaBottom - metaTop;      // Exclusive bounds
    
    // Get actual image dimensions
    final actualWidth = _selectedPieceImage?.width ?? 0;
    final actualHeight = _selectedPieceImage?.height ?? 0;
    
    // Check for mismatches
    final widthMatchesInclusive = metaWidth == calculatedWidth && calculatedWidth == actualWidth;
    final heightMatchesInclusive = metaHeight == calculatedHeight && calculatedHeight == actualWidth;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Piece: $_selectedPieceId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Metadata:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Text('Position: ($metaLeft, $metaTop)'),
                    Text('Size: ${metaWidth}×$metaHeight'),
                    Text('Bounds: L:$metaLeft, T:$metaTop, R:$metaRight, B:$metaBottom'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Calculated:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    Text('Inclusive: ${calculatedWidth}×$calculatedHeight'),
                    Text('Exclusive: ${exclusiveWidth}×$exclusiveHeight'),
                    Text('Actual Image: ${actualWidth}×$actualHeight'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Validation:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Row(
                      children: [
                        Icon(widthMatchesInclusive ? Icons.check : Icons.close, 
                             color: widthMatchesInclusive ? Colors.green : Colors.red, size: 16),
                        const Text(' Width OK'),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(heightMatchesInclusive ? Icons.check : Icons.close, 
                             color: heightMatchesInclusive ? Colors.green : Colors.red, size: 16),
                        const Text(' Height OK'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGapAnalysis() {
    if (_selectedPieceId.isEmpty || _metadata == null) return const SizedBox.shrink();
    
    // Parse piece ID to find adjacent pieces
    final parts = _selectedPieceId.split('_');
    if (parts.length != 2) return const SizedBox.shrink();
    
    final row = int.tryParse(parts[0]);
    final col = int.tryParse(parts[1]);
    if (row == null || col == null) return const SizedBox.shrink();

    final pieces = _metadata!['pieces'] as Map<String, dynamic>;
    final currentBounds = pieces[_selectedPieceId]['bounds'];
    
    // Check right neighbor
    final rightNeighborId = '${row}_${col + 1}';
    final rightNeighbor = pieces[rightNeighborId];
    
    // Check bottom neighbor  
    final bottomNeighborId = '${row + 1}_$col';
    final bottomNeighbor = pieces[bottomNeighborId];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gap Analysis:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 12),
          
          if (rightNeighbor != null) ...[
            _buildGapAnalysisRow('→ Right Neighbor', currentBounds, rightNeighbor['bounds'], 'horizontal'),
            const SizedBox(height: 8),
          ],
          
          if (bottomNeighbor != null) ...[
            _buildGapAnalysisRow('↓ Bottom Neighbor', currentBounds, bottomNeighbor['bounds'], 'vertical'),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),
          const Text('Expected: Negative values indicate proper jigsaw piece overlaps', 
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.green)),
          const Text('Puzzle pieces should overlap where tabs connect to neighboring pieces', 
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue)),
          const Text('Positive gaps would indicate pieces don\'t connect properly', 
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildGapAnalysisRow(String direction, Map<String, dynamic> currentBounds, 
                            Map<String, dynamic> neighborBounds, String orientation) {
    if (orientation == 'horizontal') {
      // Horizontal gap analysis
      final currentRight = currentBounds['right'];
      final neighborLeft = neighborBounds['left'];
      final gap = neighborLeft - currentRight - 1; // -1 because bounds are inclusive
      
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: gap < 0 ? Colors.green[50] : (gap == 0 ? Colors.orange[50] : Colors.red[50]),
          border: Border.all(color: gap < 0 ? Colors.green : (gap == 0 ? Colors.orange : Colors.red)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(direction, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Current piece right edge: $currentRight'),
            Text('Neighbor piece left edge: $neighborLeft'),
            Text('Overlap: ${gap.abs()} pixels', style: TextStyle(
              color: gap < 0 ? Colors.green : (gap == 0 ? Colors.orange : Colors.red),
              fontWeight: FontWeight.bold,
            )),
            Text(
              gap < 0 ? '✓ Pieces properly overlap (jigsaw tabs connect)' 
                     : gap == 0 ? '⚠ Pieces touch exactly (unusual for jigsaw)'
                     : '✗ Gap detected (pieces don\'t connect)',
              style: TextStyle(
                fontSize: 12,
                color: gap < 0 ? Colors.green : (gap == 0 ? Colors.orange : Colors.red),
              ),
            ),
          ],
        ),
      );
    } else {
      // Vertical gap analysis
      final currentBottom = currentBounds['bottom'];
      final neighborTop = neighborBounds['top'];
      final gap = neighborTop - currentBottom - 1; // -1 because bounds are inclusive
      
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: gap < 0 ? Colors.green[50] : (gap == 0 ? Colors.orange[50] : Colors.red[50]),
          border: Border.all(color: gap < 0 ? Colors.green : (gap == 0 ? Colors.orange : Colors.red)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(direction, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Current piece bottom edge: $currentBottom'),
            Text('Neighbor piece top edge: $neighborTop'),
            Text('Overlap: ${gap.abs()} pixels', style: TextStyle(
              color: gap < 0 ? Colors.green : (gap == 0 ? Colors.orange : Colors.red),
              fontWeight: FontWeight.bold,
            )),
            Text(
              gap < 0 ? '✓ Pieces properly overlap (jigsaw tabs connect)' 
                     : gap == 0 ? '⚠ Pieces touch exactly (unusual for jigsaw)'
                     : '✗ Gap detected (pieces don\'t connect)',
              style: TextStyle(
                fontSize: 12,
                color: gap < 0 ? Colors.green : (gap == 0 ? Colors.orange : Colors.red),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _selectedPieceImage?.dispose();
    super.dispose();
  }
}
