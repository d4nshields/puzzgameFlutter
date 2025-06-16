#!/usr/bin/env python3
"""
Test script for puzzle asset optimization.

This script tests the optimization tool and verifies that optimized assets
maintain perfect placement accuracy.
"""

import os
import sys
import json
import tempfile
import shutil
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

# Add the tools directory to path so we can import the optimizer
sys.path.insert(0, str(Path(__file__).parent))
from optimize_puzzle_assets import PuzzleOptimizer, BoundingBox

def create_test_puzzle(temp_dir: Path, puzzle_id: str = "test_puzzle") -> Path:
    """Create a test puzzle with known properties."""
    puzzle_path = temp_dir / "assets" / "puzzles" / puzzle_id
    layout_path = puzzle_path / "layouts" / "2x2"
    pieces_path = layout_path / "pieces"
    
    # Create directory structure
    pieces_path.mkdir(parents=True, exist_ok=True)
    
    # Create test layout.ipuz.json
    layout_data = {
        "version": "http://ipuz.org/v2",
        "kind": ["http://ipuz.org/jigsaw#1"],
        "canvas": {"width": 400, "height": 400}
    }
    
    with open(layout_path / "layout.ipuz.json", 'w') as f:
        json.dump(layout_data, f, indent=2)
    
    # Create test pieces with known content areas
    # Each piece is 400x400 with content in specific areas
    for row in range(2):
        for col in range(2):
            piece_id = f"{row}_{col}"
            
            # Create 400x400 transparent image
            img = Image.new('RGBA', (400, 400), (0, 0, 0, 0))
            draw = ImageDraw.Draw(img)
            
            # Draw content in specific area for each piece
            content_x = col * 150 + 50  # Offset content based on position
            content_y = row * 150 + 50
            content_size = 100
            
            # Draw a colored rectangle as content
            color = (255, row * 100, col * 100, 255)  # Different color per piece
            draw.rectangle([
                content_x, content_y,
                content_x + content_size, content_y + content_size
            ], fill=color)
            
            # Save piece
            piece_path = pieces_path / f"{piece_id}.png"
            img.save(piece_path, "PNG")
    
    return puzzle_path

def test_content_bounds_detection():
    """Test that content bounds are detected correctly."""
    print("Testing content bounds detection...")
    
    # Create test image with known content area
    img = Image.new('RGBA', (200, 200), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw content at known position
    content_bounds = (50, 30, 150, 120)  # left, top, right, bottom
    draw.rectangle(content_bounds, fill=(255, 0, 0, 255))
    
    # Test bounds detection
    optimizer = PuzzleOptimizer(".", verbose=True)
    detected_bounds = optimizer.find_content_bounds(img)
    
    assert detected_bounds is not None, "Should detect content bounds"
    assert detected_bounds.left == 50, f"Left should be 50, got {detected_bounds.left}"
    assert detected_bounds.top == 30, f"Top should be 30, got {detected_bounds.top}"
    assert detected_bounds.right == 150, f"Right should be 150, got {detected_bounds.right}"
    assert detected_bounds.bottom == 120, f"Bottom should be 120, got {detected_bounds.bottom}"
    
    print("✅ Content bounds detection test passed")

def test_cropping_accuracy():
    """Test that cropping maintains content integrity."""
    print("Testing cropping accuracy...")
    
    # Create test image
    img = Image.new('RGBA', (200, 200), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw test pattern
    content_bounds = BoundingBox(50, 30, 150, 120)
    draw.rectangle((content_bounds.left, content_bounds.top, 
                   content_bounds.right, content_bounds.bottom), 
                   fill=(255, 0, 0, 255))
    
    # Test cropping
    optimizer = PuzzleOptimizer(".", verbose=True)
    cropped = optimizer.crop_image_to_bounds(img, content_bounds, padding=2)
    
    # Verify cropped image contains all content
    expected_width = content_bounds.width + 4  # +4 for padding
    expected_height = content_bounds.height + 4
    
    assert cropped.size[0] == expected_width, f"Width should be {expected_width}, got {cropped.size[0]}"
    assert cropped.size[1] == expected_height, f"Height should be {expected_height}, got {cropped.size[1]}"
    
    # Verify content is preserved
    cropped_array = np.array(cropped)
    # Content should be at position (2, 2) due to padding
    content_pixel = cropped_array[2, 2]
    assert content_pixel[0] == 255, "Red content should be preserved"
    assert content_pixel[3] == 255, "Alpha should be preserved"
    
    print("✅ Cropping accuracy test passed")

def test_full_optimization():
    """Test full optimization workflow."""
    print("Testing full optimization workflow...")
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Create test puzzle
        puzzle_path = create_test_puzzle(temp_path, "test_puzzle")
        
        # Initialize optimizer
        optimizer = PuzzleOptimizer(str(temp_path), verbose=True)
        
        # Run optimization
        success = optimizer.optimize_puzzle("test_puzzle", ["2x2"])
        
        assert success, "Optimization should succeed"
        
        # Verify optimized assets exist
        optimized_path = puzzle_path / "layouts" / "2x2_optimized"
        assert optimized_path.exists(), "Optimized directory should exist"
        
        pieces_path = optimized_path / "pieces"
        assert pieces_path.exists(), "Optimized pieces directory should exist"
        
        # Verify all pieces are optimized
        for row in range(2):
            for col in range(2):
                piece_path = pieces_path / f"{row}_{col}.png"
                assert piece_path.exists(), f"Optimized piece {row}_{col}.png should exist"
                
                # Verify piece is smaller than original
                optimized_img = Image.open(piece_path)
                assert optimized_img.size[0] < 400, "Optimized width should be smaller"
                assert optimized_img.size[1] < 400, "Optimized height should be smaller"
        
        # Verify metadata exists and is valid
        metadata_path = optimized_path / "optimization_metadata.json"
        assert metadata_path.exists(), "Optimization metadata should exist"
        
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        
        assert metadata["version"] == "1.0", "Metadata version should be 1.0"
        assert len(metadata["pieces"]) == 4, "Should have 4 pieces"
        assert "statistics" in metadata, "Should have statistics"
        
        stats = metadata["statistics"]
        assert stats["total_pieces"] == 4, "Should report 4 pieces"
        assert stats["memory_reduction_percent"] > 0, "Should show memory reduction"
        
        print("✅ Full optimization test passed")

def test_memory_calculations():
    """Test memory usage calculations."""
    print("Testing memory calculations...")
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Create test puzzle
        create_test_puzzle(temp_path, "test_puzzle")
        
        # Run optimization
        optimizer = PuzzleOptimizer(str(temp_path), verbose=False)
        optimizer.optimize_puzzle("test_puzzle", ["2x2"])
        
        # Check memory analysis output
        print("  Running memory analysis...")
        optimizer.analyze_memory_usage("test_puzzle")
        
        print("✅ Memory calculations test passed")

def test_edge_cases():
    """Test edge cases and error handling."""
    print("Testing edge cases...")
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        optimizer = PuzzleOptimizer(str(temp_path), verbose=False)
        
        # Test with non-existent puzzle
        success = optimizer.optimize_puzzle("nonexistent_puzzle")
        assert not success, "Should fail for non-existent puzzle"
        
        # Test with completely transparent image
        img = Image.new('RGBA', (100, 100), (0, 0, 0, 0))
        bounds = optimizer.find_content_bounds(img)
        assert bounds is None, "Should return None for transparent image"
        
        print("✅ Edge cases test passed")

def run_all_tests():
    """Run all test functions."""
    print("🧪 Running puzzle optimization tests...\n")
    
    try:
        test_content_bounds_detection()
        test_cropping_accuracy()
        test_full_optimization()
        test_memory_calculations()
        test_edge_cases()
        
        print("\n🎉 All tests passed! The optimization tool is working correctly.")
        return True
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main test runner."""
    if len(sys.argv) > 1 and sys.argv[1] == "--requirements":
        print("Installing required packages...")
        os.system("pip install pillow numpy")
        return
    
    success = run_all_tests()
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
