#!/usr/bin/env python3
"""
Quick test to verify the optimization script works
"""

import sys
import subprocess
from pathlib import Path

def test_script_syntax():
    """Test that the Python script has valid syntax."""
    try:
        result = subprocess.run([
            sys.executable, '-m', 'py_compile', 'tools/optimize_puzzle_assets.py'
        ], capture_output=True, text=True, cwd='.')
        
        if result.returncode == 0:
            print("✅ Python script syntax is valid")
            return True
        else:
            print("❌ Python script has syntax errors:")
            print(result.stderr)
            return False
    except Exception as e:
        print(f"❌ Error testing script: {e}")
        return False

def check_dependencies():
    """Check that required Python packages are available."""
    required_packages = ['PIL', 'numpy']
    missing_packages = []
    
    for package in required_packages:
        try:
            if package == 'PIL':
                import PIL
                print(f"✅ PIL (Pillow) version: {PIL.__version__}")
            elif package == 'numpy':
                import numpy
                print(f"✅ NumPy version: {numpy.__version__}")
        except ImportError:
            missing_packages.append(package)
            print(f"❌ Missing package: {package}")
    
    if missing_packages:
        print(f"\n📦 Install missing packages with:")
        print(f"pip install {' '.join(['pillow' if p == 'PIL' else p for p in missing_packages])}")
        return False
    
    return True

def check_puzzle_assets():
    """Check if sample puzzle assets exist."""
    puzzle_path = Path("assets/puzzles/sample_puzzle_01")
    
    if not puzzle_path.exists():
        print(f"❌ Puzzle directory not found: {puzzle_path}")
        return False
    
    # Check for at least one grid size
    layouts_path = puzzle_path / "layouts"
    if not layouts_path.exists():
        print(f"❌ Layouts directory not found: {layouts_path}")
        return False
    
    grid_sizes = [d.name for d in layouts_path.iterdir() 
                 if d.is_dir() and not d.name.endswith('_optimized')]
    
    if not grid_sizes:
        print(f"❌ No grid size directories found in: {layouts_path}")
        return False
    
    print(f"✅ Found puzzle with grid sizes: {grid_sizes}")
    
    # Check for pieces in first grid size
    first_grid = grid_sizes[0]
    pieces_path = layouts_path / first_grid / "pieces"
    
    if not pieces_path.exists():
        print(f"❌ Pieces directory not found: {pieces_path}")
        return False
    
    piece_files = list(pieces_path.glob("*.png"))
    if not piece_files:
        print(f"❌ No PNG pieces found in: {pieces_path}")
        return False
    
    print(f"✅ Found {len(piece_files)} piece files in {first_grid}")
    return True

def main():
    print("🧪 Testing Puzzle Optimization Setup")
    print("=" * 40)
    
    all_good = True
    
    # Test script syntax
    if not test_script_syntax():
        all_good = False
    
    print()
    
    # Check dependencies
    if not check_dependencies():
        all_good = False
    
    print()
    
    # Check puzzle assets
    if not check_puzzle_assets():
        all_good = False
    
    print()
    print("=" * 40)
    
    if all_good:
        print("🎉 All checks passed! Ready to run optimization:")
        print("python3 tools/optimize_puzzle_assets.py sample_puzzle_01 --verbose")
    else:
        print("❌ Some issues found. Please fix them before running optimization.")
        return 1
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
