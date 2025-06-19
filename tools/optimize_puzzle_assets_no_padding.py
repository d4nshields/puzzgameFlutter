#!/usr/bin/env python3
"""
NO-PADDING Puzzle Asset Optimization Tool

CORRECT APPROACH: Crop exactly to content bounds with NO padding.
The cropped image contains only the actual puzzle piece content.
Metadata stores where this content should be positioned on the canvas.
"""

import os
import sys
import json
import argparse
import hashlib
import shutil
from typing import Dict, List, Tuple, Optional, NamedTuple
from pathlib import Path
import numpy as np
from PIL import Image

def convert_to_serializable(obj):
    """Convert numpy types to JSON serializable types."""
    if isinstance(obj, np.integer):
        return int(obj)
    elif isinstance(obj, np.floating):
        return float(obj)
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    return obj

class BoundingBox(NamedTuple):
    """Represents the bounding box of non-transparent content."""
    left: int
    top: int
    right: int
    bottom: int
    
    @property
    def width(self) -> int:
        return int(self.right - self.left + 1)  # Inclusive bounds
    
    @property
    def height(self) -> int:
        return int(self.bottom - self.top + 1)  # Inclusive bounds
    
    def to_dict(self) -> Dict:
        return {
            "left": int(self.left),
            "top": int(self.top),
            "right": int(self.right),
            "bottom": int(self.bottom),
            "width": int(self.width),
            "height": int(self.height)
        }

class PieceOptimizationResult(NamedTuple):
    """Result of optimizing a single piece."""
    piece_id: str
    original_size: Tuple[int, int]
    content_bounds: BoundingBox      # Where the content was found in original image
    cropped_image: Image.Image       # Pure content, no padding
    content_hash: str
    memory_saved_bytes: int

class PuzzleOptimizer:
    """Main puzzle optimization engine."""
    
    def __init__(self, base_path: str, verbose: bool = False):
        self.base_path = Path(base_path)
        self.verbose = verbose
        
    def log(self, message: str) -> None:
        """Print log message if verbose is enabled."""
        if self.verbose:
            print(f"[PuzzleOptimizer] {message}")
    
    def find_content_bounds(self, image: Image.Image) -> Optional[BoundingBox]:
        """
        Find the exact bounding box of non-transparent pixels.
        
        Args:
            image: PIL Image in RGBA format
            
        Returns:
            BoundingBox of content or None if image is completely transparent
        """
        if image.mode != 'RGBA':
            image = image.convert('RGBA')
        
        # Convert to numpy array for fast processing
        img_array = np.array(image)
        alpha_channel = img_array[:, :, 3]  # Alpha channel
        
        # Find all non-transparent pixels
        non_transparent = alpha_channel > 0
        
        if not np.any(non_transparent):
            self.log(f"Warning: Image appears completely transparent")
            return None
        
        # Find bounds of non-transparent pixels
        rows = np.any(non_transparent, axis=1)
        cols = np.any(non_transparent, axis=0)
        
        top = int(np.argmax(rows))
        bottom = int(len(rows) - 1 - np.argmax(rows[::-1]))
        left = int(np.argmax(cols))
        right = int(len(cols) - 1 - np.argmax(cols[::-1]))
        
        return BoundingBox(int(left), int(top), int(right), int(bottom))
    
    def crop_to_exact_content(self, image: Image.Image, bounds: BoundingBox) -> Image.Image:
        """
        Crop image to EXACT content bounds with NO padding.
        
        Args:
            image: Source image
            bounds: Content bounding box (inclusive coordinates)
            
        Returns:
            Cropped image containing only the actual content
        """
        # Convert inclusive bounds to exclusive for PIL crop
        # PIL crop expects (left, top, right, bottom) where right/bottom are exclusive
        crop_box = (bounds.left, bounds.top, bounds.right + 1, bounds.bottom + 1)
        
        cropped = image.crop(crop_box)
        
        self.log(f"  Content bounds (inclusive): left={bounds.left}, top={bounds.top}, right={bounds.right}, bottom={bounds.bottom}")
        self.log(f"  PIL crop box (exclusive): {crop_box}")
        self.log(f"  Expected size: {bounds.width}x{bounds.height}")
        self.log(f"  Actual cropped size: {cropped.size[0]}x{cropped.size[1]}")
        
        # Verify the crop worked correctly
        expected_width = bounds.right - bounds.left + 1
        expected_height = bounds.bottom - bounds.top + 1
        
        if cropped.size != (expected_width, expected_height):
            raise ValueError(f"Crop size mismatch! Expected {expected_width}x{expected_height}, got {cropped.size[0]}x{cropped.size[1]}")
        
        return cropped
    
    def calculate_content_hash(self, image: Image.Image) -> str:
        """Calculate SHA-256 hash of image content for verification."""
        img_bytes = image.tobytes()
        return hashlib.sha256(img_bytes).hexdigest()[:8]
    
    def optimize_piece(self, piece_path: Path) -> Optional[PieceOptimizationResult]:
        """
        Optimize a single puzzle piece by removing ALL transparent padding.
        
        Args:
            piece_path: Path to the piece PNG file
            
        Returns:
            PieceOptimizationResult or None if optimization failed
        """
        try:
            piece_id = piece_path.stem
            self.log(f"Optimizing piece {piece_id}")
            
            # Load original image
            original_image = Image.open(piece_path).convert('RGBA')
            original_size = original_image.size
            original_bytes = original_size[0] * original_size[1] * 4  # RGBA = 4 bytes per pixel
            
            # Find exact content bounds
            content_bounds = self.find_content_bounds(original_image)
            if content_bounds is None:
                self.log(f"Warning: Piece {piece_id} has no content, skipping")
                return None
            
            # Crop to exact content with NO padding
            cropped_image = self.crop_to_exact_content(original_image, content_bounds)
            cropped_bytes = cropped_image.size[0] * cropped_image.size[1] * 4
            
            # Calculate hash for verification
            content_hash = self.calculate_content_hash(cropped_image)
            
            memory_saved = int(original_bytes - cropped_bytes)
            reduction_percent = float((memory_saved / original_bytes) * 100)
            
            self.log(f"  Original: {original_size[0]}x{original_size[1]} ({original_bytes:,} bytes)")
            self.log(f"  Cropped:  {cropped_image.size[0]}x{cropped_image.size[1]} ({cropped_bytes:,} bytes)")
            self.log(f"  Saved:    {memory_saved:,} bytes ({reduction_percent:.1f}%)")
            
            return PieceOptimizationResult(
                piece_id=piece_id,
                original_size=original_size,
                content_bounds=content_bounds,
                cropped_image=cropped_image,
                content_hash=content_hash,
                memory_saved_bytes=memory_saved
            )
            
        except Exception as e:
            self.log(f"Error optimizing piece {piece_path}: {e}")
            return None
    
    def optimize_grid_size(self, puzzle_id: str, grid_size: str) -> bool:
        """
        Optimize all pieces for a specific puzzle and grid size.
        
        Args:
            puzzle_id: Puzzle identifier
            grid_size: Grid size (e.g., "8x8", "12x12")
            
        Returns:
            True if optimization succeeded
        """
        source_layout_path = self.base_path / "assets" / "puzzles" / puzzle_id / "layouts" / grid_size
        pieces_path = source_layout_path / "pieces"
        
        if not pieces_path.exists():
            self.log(f"Error: Pieces directory not found: {pieces_path}")
            return False
        
        # Create optimized layout directory
        optimized_layout_path = source_layout_path.parent / f"{grid_size}_optimized"
        optimized_pieces_path = optimized_layout_path / "pieces"
        
        self.log(f"Creating optimized layout: {optimized_layout_path}")
        optimized_layout_path.mkdir(exist_ok=True)
        optimized_pieces_path.mkdir(exist_ok=True)
        
        # Copy original layout.ipuz.json
        original_layout = source_layout_path / "layout.ipuz.json"
        if original_layout.exists():
            shutil.copy2(original_layout, optimized_layout_path / "layout.ipuz.json")
            self.log(f"Copied layout.ipuz.json")
        
        # Process all piece files
        piece_files = list(pieces_path.glob("*.png"))
        results = []
        total_original_bytes = 0
        total_saved_bytes = 0
        
        self.log(f"Processing {len(piece_files)} pieces...")
        
        for piece_file in sorted(piece_files):
            result = self.optimize_piece(piece_file)
            if result:
                # Save optimized piece (pure content, no padding)
                output_path = optimized_pieces_path / f"{result.piece_id}.png"
                result.cropped_image.save(output_path, "PNG", optimize=True)
                
                results.append(result)
                total_original_bytes += int(result.original_size[0] * result.original_size[1] * 4)
                total_saved_bytes += int(result.memory_saved_bytes)
        
        if not results:
            self.log(f"Error: No pieces were successfully optimized")
            return False
        
        # Generate optimization metadata
        canvas_info = self._load_canvas_info(source_layout_path / "layout.ipuz.json")
        metadata = self._generate_optimization_metadata(results, canvas_info, total_original_bytes, total_saved_bytes)
        
        # Save metadata with custom encoder to handle numpy types
        metadata_path = optimized_layout_path / "optimization_metadata.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2, default=convert_to_serializable)
        
        total_reduction = (total_saved_bytes / total_original_bytes) * 100
        self.log(f"✅ Optimization complete!")
        self.log(f"   Pieces optimized: {len(results)}")
        self.log(f"   Memory reduction: {total_saved_bytes:,} bytes ({total_reduction:.1f}%)")
        self.log(f"   Output directory: {optimized_layout_path}")
        
        return True
    
    def _load_canvas_info(self, layout_path: Path) -> Dict:
        """Load canvas information from layout.ipuz.json."""
        try:
            with open(layout_path, 'r') as f:
                layout_data = json.load(f)
            return layout_data.get('canvas', {'width': 2048, 'height': 2048})
        except Exception as e:
            self.log(f"Warning: Could not load canvas info from {layout_path}: {e}")
            return {'width': 2048, 'height': 2048}
    
    def _generate_optimization_metadata(self, results: List[PieceOptimizationResult], 
                                       canvas_info: Dict, total_original_bytes: int, 
                                       total_saved_bytes: int) -> Dict:
        """Generate the optimization metadata JSON for NO-PADDING approach."""
        pieces_metadata = {}
        
        for result in results:
            content_bounds = result.content_bounds
            cropped_image = result.cropped_image
            
            # Verify dimensions match
            actual_width = cropped_image.size[0]
            actual_height = cropped_image.size[1]
            expected_width = content_bounds.width
            expected_height = content_bounds.height
            
            if actual_width != expected_width or actual_height != expected_height:
                raise ValueError(f"Piece {result.piece_id}: dimension mismatch! "
                               f"Expected {expected_width}x{expected_height}, "
                               f"got {actual_width}x{actual_height}")
            
            # Store the original canvas coordinates where this content was found
            bounds_dict = {
                "left": int(content_bounds.left),
                "top": int(content_bounds.top),
                "right": int(content_bounds.right),
                "bottom": int(content_bounds.bottom),
                "width": int(content_bounds.width),    # Matches actual cropped image width
                "height": int(content_bounds.height)   # Matches actual cropped image height
            }
            
            pieces_metadata[result.piece_id] = {
                "bounds": bounds_dict,
                "canvas_size": {
                    "width": int(canvas_info['width']),
                    "height": int(canvas_info['height'])
                },
                "content_hash": result.content_hash,
                "cropped_filename": f"{result.piece_id}.png"
            }
            
            self.log(f"Piece {result.piece_id}: canvas_position=({content_bounds.left},{content_bounds.top}), "
                    f"size={actual_width}x{actual_height}")
        
        return {
            "version": "1.0", 
            "canvas_size": {
                "width": int(canvas_info['width']),
                "height": int(canvas_info['height'])
            },
            "pieces": pieces_metadata,
            "statistics": {
                "memory_reduction_percent": float((total_saved_bytes / total_original_bytes) * 100) if total_original_bytes > 0 else 0.0,
                "total_pieces": int(len(results)),
                "original_total_bytes": int(total_original_bytes),
                "optimized_total_bytes": int(total_original_bytes - total_saved_bytes),
                "bytes_saved": int(total_saved_bytes)
            }
        }
    
    def optimize_puzzle(self, puzzle_id: str, grid_sizes: Optional[List[str]] = None) -> bool:
        """
        Optimize all grid sizes for a puzzle.
        
        Args:
            puzzle_id: Puzzle identifier
            grid_sizes: List of grid sizes to optimize, or None for all
            
        Returns:
            True if all optimizations succeeded
        """
        puzzle_path = self.base_path / "assets" / "puzzles" / puzzle_id / "layouts"
        
        if not puzzle_path.exists():
            self.log(f"Error: Puzzle directory not found: {puzzle_path}")
            return False
        
        # Discover available grid sizes if not specified
        if grid_sizes is None:
            grid_sizes = [d.name for d in puzzle_path.iterdir() 
                         if d.is_dir() and not d.name.endswith('_optimized')]
        
        self.log(f"Optimizing puzzle '{puzzle_id}' grid sizes: {grid_sizes}")
        
        success_count = 0
        for grid_size in grid_sizes:
            self.log(f"\n--- Optimizing {puzzle_id} {grid_size} ---")
            if self.optimize_grid_size(puzzle_id, grid_size):
                success_count += 1
            else:
                self.log(f"❌ Failed to optimize {puzzle_id} {grid_size}")
        
        self.log(f"\n✅ Optimization summary: {success_count}/{len(grid_sizes)} grid sizes optimized")
        return success_count == len(grid_sizes)
    
    def analyze_memory_usage(self, puzzle_id: str) -> None:
        """Analyze and display memory usage before and after optimization."""
        puzzle_path = self.base_path / "assets" / "puzzles" / puzzle_id / "layouts"
        
        if not puzzle_path.exists():
            self.log(f"Error: Puzzle directory not found: {puzzle_path}")
            return
        
        print(f"\n=== Memory Analysis for {puzzle_id} ===")
        
        grid_sizes = [d.name for d in puzzle_path.iterdir() 
                     if d.is_dir() and not d.name.endswith('_optimized')]
        
        for grid_size in sorted(grid_sizes):
            original_path = puzzle_path / grid_size / "pieces"
            optimized_path = puzzle_path / f"{grid_size}_optimized"
            metadata_path = optimized_path / "optimization_metadata.json"
            
            if not original_path.exists():
                continue
            
            # Count original pieces and calculate memory
            original_pieces = list(original_path.glob("*.png"))
            pieces_count = len(original_pieces)
            
            # Estimate original memory (assuming 2048x2048 RGBA)
            original_memory_mb = (pieces_count * 2048 * 2048 * 4) / (1024 * 1024)
            
            print(f"\n{grid_size}: {pieces_count} pieces")
            print(f"  Original memory: ~{original_memory_mb:.0f} MB")
            
            # Show optimized stats if available
            if metadata_path.exists():
                try:
                    with open(metadata_path, 'r') as f:
                        metadata = json.load(f)
                    
                    stats = metadata.get('statistics', {})
                    reduction = stats.get('memory_reduction_percent', 0)
                    optimized_memory_mb = original_memory_mb * (1 - reduction/100)
                    saved_mb = original_memory_mb - optimized_memory_mb
                    
                    print(f"  Optimized memory: ~{optimized_memory_mb:.0f} MB")
                    print(f"  Memory saved: ~{saved_mb:.0f} MB ({reduction:.1f}%)")
                    
                except Exception as e:
                    print(f"  Error reading optimization metadata: {e}")
            else:
                print(f"  Status: Not optimized")

def main():
    """Main CLI interface."""
    parser = argparse.ArgumentParser(
        description="NO-PADDING Optimize puzzle assets by removing ALL transparent padding",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Optimize all grid sizes for sample_puzzle_01
  python optimize_puzzle_assets_no_padding.py sample_puzzle_01
  
  # Optimize specific grid sizes
  python optimize_puzzle_assets_no_padding.py sample_puzzle_01 --grid-sizes 8x8 12x12
  
  # Analyze memory usage
  python optimize_puzzle_assets_no_padding.py sample_puzzle_01 --analyze-only
  
  # Verbose output
  python optimize_puzzle_assets_no_padding.py sample_puzzle_01 --verbose
        """
    )
    
    parser.add_argument('puzzle_id', help='Puzzle identifier (e.g., sample_puzzle_01)')
    parser.add_argument('--grid-sizes', nargs='+', help='Specific grid sizes to optimize')
    parser.add_argument('--analyze-only', action='store_true', help='Only analyze memory usage')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--base-path', default='.', help='Base path to puzzle game project')
    
    args = parser.parse_args()
    
    # Initialize optimizer
    optimizer = PuzzleOptimizer(args.base_path, verbose=args.verbose)
    
    if args.analyze_only:
        optimizer.analyze_memory_usage(args.puzzle_id)
        return
    
    # Run optimization
    success = optimizer.optimize_puzzle(args.puzzle_id, args.grid_sizes)
    
    # Show memory analysis after optimization
    optimizer.analyze_memory_usage(args.puzzle_id)
    
    if success:
        print(f"\n✅ Optimization completed successfully!")
        print(f"🔧 Cropped images contain ONLY content, no padding")
        print(f"🔧 Metadata stores original canvas coordinates for positioning")
        sys.exit(0)
    else:
        print(f"\n❌ Optimization failed!")
        sys.exit(1)

if __name__ == '__main__':
    main()
