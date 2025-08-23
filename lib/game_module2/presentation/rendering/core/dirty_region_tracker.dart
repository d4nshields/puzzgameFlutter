part of '../hybrid_renderer.dart';

/// Tracks dirty regions for optimized repainting
class DirtyRegionTracker {
  final Set<Rect> _dirtyRegions = {};
  final List<Rect> _frameHistory = [];
  static const int maxHistorySize = 10;
  
  /// Mark a region as dirty (needs repaint)
  void markDirty(Rect region) {
    // Try to merge with existing regions if they overlap
    final mergedRegion = _tryMergeRegion(region);
    if (mergedRegion != null) {
      _dirtyRegions.removeWhere((r) => r.overlaps(region));
      _dirtyRegions.add(mergedRegion);
    } else {
      _dirtyRegions.add(region);
    }
  }

  /// Try to merge a region with existing dirty regions
  Rect? _tryMergeRegion(Rect region) {
    Rect? merged;
    
    for (final existing in _dirtyRegions) {
      if (existing.overlaps(region)) {
        if (merged == null) {
          merged = existing.expandToInclude(region);
        } else {
          merged = merged.expandToInclude(existing);
        }
      }
    }
    
    return merged;
  }

  /// Check if a region intersects with any dirty region
  bool isDirty(Rect region) {
    return _dirtyRegions.any((dirty) => dirty.overlaps(region));
  }

  /// Get all dirty regions
  List<Rect> get dirtyRegions => _dirtyRegions.toList();

  /// Get the bounding box of all dirty regions
  Rect? get boundingBox {
    if (_dirtyRegions.isEmpty) return null;
    
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    
    for (final region in _dirtyRegions) {
      minX = math.min(minX, region.left);
      minY = math.min(minY, region.top);
      maxX = math.max(maxX, region.right);
      maxY = math.max(maxY, region.bottom);
    }
    
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Clear all dirty regions (after repaint)
  void clear() {
    // Store in history for analysis
    if (_dirtyRegions.isNotEmpty) {
      _frameHistory.add(boundingBox!);
      if (_frameHistory.length > maxHistorySize) {
        _frameHistory.removeAt(0);
      }
    }
    
    _dirtyRegions.clear();
  }

  /// Get the number of dirty regions
  int get dirtyRegionCount => _dirtyRegions.length;

  /// Optimize dirty regions by merging nearby ones
  void optimize() {
    if (_dirtyRegions.length <= 1) return;
    
    final optimized = <Rect>[];
    final processed = <Rect>{};
    
    for (final region in _dirtyRegions) {
      if (processed.contains(region)) continue;
      
      Rect merged = region;
      final toMerge = <Rect>{region};
      
      // Find all regions that can be merged
      for (final other in _dirtyRegions) {
        if (other == region || processed.contains(other)) continue;
        
        // Check if merging would be beneficial
        if (_shouldMerge(merged, other)) {
          merged = merged.expandToInclude(other);
          toMerge.add(other);
        }
      }
      
      optimized.add(merged);
      processed.addAll(toMerge);
    }
    
    _dirtyRegions.clear();
    _dirtyRegions.addAll(optimized);
  }

  /// Determine if two regions should be merged
  bool _shouldMerge(Rect a, Rect b) {
    // Calculate the area of individual regions
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final individualArea = areaA + areaB;
    
    // Calculate the area if merged
    final merged = a.expandToInclude(b);
    final mergedArea = merged.width * merged.height;
    
    // Merge if the wasted area is less than 50% of the individual areas
    final wastedArea = mergedArea - individualArea;
    return wastedArea < individualArea * 0.5;
  }

  /// Get statistics about dirty regions
  DirtyRegionStats getStats() {
    final totalArea = _dirtyRegions.fold<double>(
      0,
      (sum, region) => sum + region.width * region.height,
    );
    
    final boundingArea = boundingBox?.let((box) => box.width * box.height) ?? 0;
    
    return DirtyRegionStats(
      regionCount: _dirtyRegions.length,
      totalArea: totalArea,
      boundingArea: boundingArea,
      efficiency: totalArea > 0 ? totalArea / boundingArea : 1.0,
    );
  }
}

/// Statistics about dirty regions
class DirtyRegionStats {
  final int regionCount;
  final double totalArea;
  final double boundingArea;
  final double efficiency;

  const DirtyRegionStats({
    required this.regionCount,
    required this.totalArea,
    required this.boundingArea,
    required this.efficiency,
  });
}

/// Extension to help with null-safe operations
extension _RectExtensions on Rect {
  T let<T>(T Function(Rect) operation) => operation(this);
}