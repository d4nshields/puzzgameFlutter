Please analyze the source code for my puzzle game in /home/daniel/work/puzzgameFlutter.

I'm developing a Flutter puzzle game with severe memory issues. My puzzle pieces are stored as 2048×2048 padded PNGs where each piece has 99% transparent pixels for positioning. This causes:

8x8 grid: ~1GB RAM (64 pieces × 16MB each)
12x12 grid: ~2.3GB RAM (144 pieces × 16MB each) ❌ CRASHES
15x15 grid: ~3.6GB RAM (225 pieces × 16MB each) ❌ CRASHES

Current Architecture:

Flutter puzzle game in /home/daniel/work/puzzgameFlutter
Pieces stored as /assets/puzzles/sample_puzzle_01/layouts/{8x8,12x12,15x15}/pieces/{row}_{col}.png
Each piece is full canvas size (2048×2048) with transparent padding for exact positioning
Current asset managers: PuzzleAssetManager and EnhancedPuzzleAssetManager
Game uses canvas-based rendering where PNG padding handles positioning

SOLUTION NEEDED:
Create a hybrid preprocessing + runtime approach that:

Python Tool (tools/optimize_puzzle_assets.py):

Analyzes existing padded PNGs to find content bounds (non-transparent pixels)
Crops pieces to minimal bounding boxes (removes 99% transparent padding)
Stores precise positioning metadata in JSON format
Generates optimized asset bundles: layouts/{gridsize}_optimized/
Should achieve 60-80% memory reduction


Flutter Memory-Optimized Asset Manager (lib/game_module/services/memory_optimized_asset_manager.dart):

Automatically detects optimized assets and uses them when available
Falls back to runtime optimization for non-optimized puzzles
Uses positioning metadata for perfect canvas placement accuracy
Dual rendering modes: cropped images for tray, positioned placement for canvas
Integrates with existing PuzzleGameModule architecture


Asset Structure:
layouts/8x8_optimized/
├── pieces/
│   ├── 0_0.png          # Cropped to content bounds
│   └── ...
├── optimization_metadata.json  # Positioning data
└── layout.ipuz.json     # Original layout (copied)

Metadata Format:
json{
  "version": "1.0",
  "canvas_size": {"width": 2048, "height": 2048},
  "pieces": {
    "0_0": {
      "bounds": {"left": 45, "top": 67, "right": 298, "bottom": 301, "width": 254, "height": 235},
      "canvas_size": {"width": 2048, "height": 2048},
      "content_hash": "a1b2c3d4",
      "cropped_filename": "0_0.png"
    }
  },
  "statistics": {"memory_reduction_percent": 72.3, "total_pieces": 64}
}


REQUIREMENTS:

Maintain perfect placement accuracy (pieces must place exactly as before)
Backwards compatible (works with existing non-optimized assets)
Graceful fallback (runtime optimization if preprocessed assets unavailable)
Minimal code changes to existing game logic
Python tool should use PIL/numpy for image processing
Include test scripts and documentation

KEY TECHNICAL DETAILS:

Use ui.Image objects in Flutter for performance
Smart rendering: tray shows cropped pieces, canvas uses positioning metadata
Memory target: reduce 12x12 from ~2.3GB to ~500-800MB
Asset manager should check for optimized version first, fallback to original
Use CustomPainter for efficient rendering with positioning calculations

Please implement this complete solution with proper error handling, testing capabilities, and clear documentation. Focus on creating clean, working files without corruption.
