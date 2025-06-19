import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';

/// Debug tool to validate optimization metadata calculations
class MetadataValidationScreen extends StatefulWidget {
  const MetadataValidationScreen({super.key});

  @override
  State<MetadataValidationScreen> createState() => _MetadataValidationScreenState();
}

class _MetadataValidationScreenState extends State<MetadataValidationScreen> {
  Map<String, dynamic>? _metadata;
  Map<String, ValidationResult> _validationResults = {};
  bool _isLoading = true;
  String _selectedPieceId = '';
  List<String> _allPieceIds = [];

  @override
  void initState() {
    super.initState();
    _loadAndValidateMetadata();
  }

  Future<void> _loadAndValidateMetadata() async {
    try {
      // Load optimization metadata
      final metadataPath = 'assets/puzzles/sample_puzzle_01/layouts/15x15_optimized/optimization_metadata.json';
      final metadataJson = await rootBundle.loadString(metadataPath);
      _metadata = json.decode(metadataJson);
      
      final pieces = _metadata!['pieces'] as Map<String, dynamic>;
      _allPieceIds = pieces.keys.toList()..sort();
      _selectedPieceId = _allPieceIds.isNotEmpty ? _allPieceIds.first : '';
      
      print('MetadataValidation: Loaded metadata for ${pieces.length} pieces');
      
      // Validate each piece's metadata
      await _validateAllPieces();
      
      setState(() => _isLoading = false);
      
    } catch (e) {
      print('MetadataValidation: Failed to load metadata: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load metadata: $e')),
        );
      }
    }
  }

  Future<void> _validateAllPieces() async {
    if (_metadata == null) return;
    
    final pieces = _metadata!['pieces'] as Map<String, dynamic>;
    final canvasSize = _metadata!['canvas_size'];
    final expectedCanvasWidth = canvasSize['width'].toDouble();
    final expectedCanvasHeight = canvasSize['height'].toDouble();
    
    for (final pieceId in _allPieceIds) {
      try {
        final pieceData = pieces[pieceId];
        final bounds = pieceData['bounds'];
        
        // Load the actual optimized piece image
        final imagePath = 'assets/puzzles/sample_puzzle_01/layouts/15x15_optimized/pieces/$pieceId.png';
        final imageData = await rootBundle.load(imagePath);
        final codec = await ui.instantiateImageCodec(imageData.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final image = frame.image;
        
        // Validate metadata against actual image
        final result = ValidationResult(
          pieceId: pieceId,
          metadataWidth: bounds['width'].toDouble(),
          metadataHeight: bounds['height'].toDouble(),
          actualImageWidth: image.width.toDouble(),
          actualImageHeight: image.height.toDouble(),
          metadataLeft: bounds['left'].toDouble(),
          metadataTop: bounds['top'].toDouble(),
          metadataRight: bounds['right'].toDouble(),
          metadataBottom: bounds['bottom'].toDouble(),
          canvasWidth: expectedCanvasWidth,
          canvasHeight: expectedCanvasHeight,
        );
        
        _validationResults[pieceId] = result;
        image.dispose();
        
      } catch (e) {
        print('MetadataValidation: Error validating piece $pieceId: $e');
      }
    }
    
    print('MetadataValidation: Validated ${_validationResults.length} pieces');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metadata Validation'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryPanel(),
                _buildPieceSelector(),
                _buildSelectedPieceDetails(),
                Expanded(child: _buildValidationList()),
              ],
            ),
    );
  }

  Widget _buildSummaryPanel() {
    final totalPieces = _validationResults.length;
    final validPieces = _validationResults.values.where((r) => r.isValid).length;
    final invalidPieces = totalPieces - validPieces;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.indigo[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryItem('Total Pieces', totalPieces.toString(), Colors.blue),
          _buildSummaryItem('Valid', validPieces.toString(), Colors.green),
          _buildSummaryItem('Invalid', invalidPieces.toString(), Colors.red),
          _buildSummaryItem('Canvas Size', 
            _metadata != null ? '${_metadata!['canvas_size']['width']}×${_metadata!['canvas_size']['height']}' : 'Unknown',
            Colors.purple),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPieceSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          const Text('Selected Piece: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedPieceId.isNotEmpty ? _selectedPieceId : null,
              hint: const Text('Select a piece'),
              items: _allPieceIds.map((pieceId) {
                final result = _validationResults[pieceId];
                return DropdownMenuItem(
                  value: pieceId,
                  child: Row(
                    children: [
                      Icon(
                        result?.isValid == true ? Icons.check_circle : Icons.error,
                        color: result?.isValid == true ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(pieceId),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPieceId = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPieceDetails() {
    if (_selectedPieceId.isEmpty) return const SizedBox.shrink();
    
    final result = _validationResults[_selectedPieceId];
    if (result == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: result.isValid ? Colors.green[50] : Colors.red[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Piece: $_selectedPieceId',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetadataColumn(result)),
              const SizedBox(width: 20),
              Expanded(child: _buildValidationColumn(result)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataColumn(ValidationResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Metadata Values:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        Text('Position: (${result.metadataLeft.toInt()}, ${result.metadataTop.toInt()})'),
        Text('Size: ${result.metadataWidth.toInt()}×${result.metadataHeight.toInt()}'),
        Text('Bounds: L:${result.metadataLeft.toInt()}, T:${result.metadataTop.toInt()}, R:${result.metadataRight.toInt()}, B:${result.metadataBottom.toInt()}'),
        Text('Calculated Width: ${result.calculatedWidth.toInt()}'),
        Text('Calculated Height: ${result.calculatedHeight.toInt()}'),
      ],
    );
  }

  Widget _buildValidationColumn(ValidationResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Validation Results:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        Text('Actual Image: ${result.actualImageWidth.toInt()}×${result.actualImageHeight.toInt()}'),
        _buildValidationRow('Width Match', result.widthMatches),
        _buildValidationRow('Height Match', result.heightMatches),
        _buildValidationRow('Bounds Valid', result.boundsValid),
        _buildValidationRow('In Canvas', result.inCanvas),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              result.isValid ? Icons.check_circle : Icons.error,
              color: result.isValid ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              result.isValid ? 'VALID' : 'INVALID',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: result.isValid ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        if (!result.isValid) ...[
          const SizedBox(height: 4),
          ...result.errors.map((error) => Text(
            '• $error',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          )),
        ],
      ],
    );
  }

  Widget _buildValidationRow(String label, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check : Icons.close,
          color: isValid ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildValidationList() {
    final sortedResults = _validationResults.values.toList()
      ..sort((a, b) {
        // Sort invalid pieces first, then by piece ID
        if (a.isValid != b.isValid) {
          return a.isValid ? 1 : -1;
        }
        return a.pieceId.compareTo(b.pieceId);
      });

    return ListView.builder(
      itemCount: sortedResults.length,
      itemBuilder: (context, index) {
        final result = sortedResults[index];
        return ListTile(
          leading: Icon(
            result.isValid ? Icons.check_circle : Icons.error,
            color: result.isValid ? Colors.green : Colors.red,
          ),
          title: Text('Piece ${result.pieceId}'),
          subtitle: result.isValid
              ? Text('✓ Valid - ${result.actualImageWidth.toInt()}×${result.actualImageHeight.toInt()}')
              : Text('✗ ${result.errors.join(', ')}', style: const TextStyle(color: Colors.red)),
          trailing: result.isValid 
              ? const Icon(Icons.check, color: Colors.green)
              : const Icon(Icons.warning, color: Colors.red),
          tileColor: result.isValid ? null : Colors.red[50],
          onTap: () {
            setState(() => _selectedPieceId = result.pieceId);
          },
        );
      },
    );
  }
}

class ValidationResult {
  final String pieceId;
  final double metadataWidth;
  final double metadataHeight;
  final double actualImageWidth;
  final double actualImageHeight;
  final double metadataLeft;
  final double metadataTop;
  final double metadataRight;
  final double metadataBottom;
  final double canvasWidth;
  final double canvasHeight;

  ValidationResult({
    required this.pieceId,
    required this.metadataWidth,
    required this.metadataHeight,
    required this.actualImageWidth,
    required this.actualImageHeight,
    required this.metadataLeft,
    required this.metadataTop,
    required this.metadataRight,
    required this.metadataBottom,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  // Calculate width and height from bounds (like Python should do)
  double get calculatedWidth => metadataRight - metadataLeft;
  double get calculatedHeight => metadataBottom - metadataTop;

  // Validation checks
  bool get widthMatches => (metadataWidth - actualImageWidth).abs() < 1.0;
  bool get heightMatches => (metadataHeight - actualImageHeight).abs() < 1.0;
  bool get boundsValid => (calculatedWidth - metadataWidth).abs() < 1.0 && (calculatedHeight - metadataHeight).abs() < 1.0;
  bool get inCanvas => metadataLeft >= 0 && metadataTop >= 0 && metadataRight <= canvasWidth && metadataBottom <= canvasHeight;

  bool get isValid => widthMatches && heightMatches && boundsValid && inCanvas;

  List<String> get errors {
    final errors = <String>[];
    if (!widthMatches) errors.add('Width mismatch: metadata=${metadataWidth.toInt()}, actual=${actualImageWidth.toInt()}');
    if (!heightMatches) errors.add('Height mismatch: metadata=${metadataHeight.toInt()}, actual=${actualImageHeight.toInt()}');
    if (!boundsValid) errors.add('Bounds calculation error: calc=${calculatedWidth.toInt()}×${calculatedHeight.toInt()}, stored=${metadataWidth.toInt()}×${metadataHeight.toInt()}');
    if (!inCanvas) errors.add('Outside canvas bounds');
    return errors;
  }
}
