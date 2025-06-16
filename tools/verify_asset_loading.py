#!/usr/bin/env python3
"""
Asset Loading Verification Tool

This tool helps verify that optimized assets are properly included and accessible.
"""

import sys
import json
from pathlib import Path

def check_asset_structure():
    """Check if optimized assets exist in the expected locations."""
    print("🔍 Checking Asset Structure")
    print("=" * 50)
    
    base_path = Path("assets/puzzles/sample_puzzle_01/layouts")
    
    if not base_path.exists():
        print(f"❌ Base path not found: {base_path}")
        return False
    
    grid_sizes = ['8x8', '12x12', '15x15']
    all_good = True
    
    for grid_size in grid_sizes:
        print(f"\n📁 {grid_size}:")
        
        # Check original assets
        original_path = base_path / grid_size / "pieces"
        if original_path.exists():
            original_count = len(list(original_path.glob("*.png")))
            print(f"  ✅ Original: {original_count} pieces")
        else:
            print(f"  ❌ Original: Not found")
            all_good = False
        
        # Check optimized assets
        optimized_path = base_path / f"{grid_size}_optimized"
        metadata_path = optimized_path / "optimization_metadata.json"
        pieces_path = optimized_path / "pieces"
        
        if optimized_path.exists():
            if metadata_path.exists():
                try:
                    with open(metadata_path, 'r') as f:
                        metadata = json.load(f)
                    
                    pieces_count = len(metadata.get('pieces', {}))
                    stats = metadata.get('statistics', {})
                    reduction = stats.get('memory_reduction_percent', 0)
                    
                    print(f"  ✅ Optimized: {pieces_count} pieces ({reduction:.1f}% memory reduction)")
                    
                    # Check if pieces actually exist
                    if pieces_path.exists():
                        actual_pieces = len(list(pieces_path.glob("*.png")))
                        if actual_pieces == pieces_count:
                            print(f"  ✅ Files: All {actual_pieces} optimized pieces present")
                        else:
                            print(f"  ⚠️  Files: {actual_pieces}/{pieces_count} optimized pieces found")
                    else:
                        print(f"  ❌ Files: Optimized pieces directory not found")
                        all_good = False
                        
                except Exception as e:
                    print(f"  ❌ Optimized: Error reading metadata: {e}")
                    all_good = False
            else:
                print(f"  ❌ Optimized: No metadata file")
                all_good = False
        else:
            print(f"  ⚠️  Optimized: Not created yet")
    
    return all_good

def check_pubspec_yaml():
    """Check if pubspec.yaml includes optimized asset paths."""
    print(f"\n🔍 Checking pubspec.yaml")
    print("=" * 50)
    
    pubspec_path = Path("pubspec.yaml")
    if not pubspec_path.exists():
        print("❌ pubspec.yaml not found")
        return False
    
    with open(pubspec_path, 'r') as f:
        content = f.read()
    
    required_paths = [
        "assets/puzzles/sample_puzzle_01/layouts/8x8_optimized/",
        "assets/puzzles/sample_puzzle_01/layouts/12x12_optimized/",
        "assets/puzzles/sample_puzzle_01/layouts/15x15_optimized/"
    ]
    
    all_present = True
    for path in required_paths:
        if path in content:
            print(f"  ✅ {path}")
        else:
            print(f"  ❌ {path} - Missing from pubspec.yaml")
            all_present = False
    
    return all_present

def generate_test_commands():
    """Generate commands to test the optimization."""
    print(f"\n🧪 Testing Commands")
    print("=" * 50)
    
    print("1. Create optimized assets:")
    print("   python3 tools/optimize_puzzle_assets.py sample_puzzle_01 --verbose")
    
    print("\n2. Update Flutter assets:")
    print("   flutter clean")
    print("   flutter pub get")
    
    print("\n3. Test compilation:")
    print("   flutter analyze")
    
    print("\n4. Check debug output when running app:")
    print("   flutter run --debug")
    print("   # Look for: '✅ Found optimized assets' or '❌ No optimized assets'")
    
    print("\n5. Benchmark memory usage:")
    print("   python3 tools/benchmark_memory_optimization.py sample_puzzle_01")

def main():
    print("🎯 Asset Loading Verification")
    print("=" * 60)
    
    assets_ok = check_asset_structure()
    pubspec_ok = check_pubspec_yaml()
    
    print(f"\n📊 Summary")
    print("=" * 50)
    
    if assets_ok and pubspec_ok:
        print("✅ All checks passed!")
        print("🚀 Optimized assets should be loaded by Flutter")
    elif not assets_ok and pubspec_ok:
        print("⚠️  pubspec.yaml is configured but optimized assets don't exist")
        print("📝 Run the optimization tool to create them")
    elif assets_ok and not pubspec_ok:
        print("⚠️  Optimized assets exist but pubspec.yaml needs updating")
        print("📝 Add the optimized asset paths to pubspec.yaml")
    else:
        print("❌ Both assets and pubspec.yaml need attention")
    
    generate_test_commands()
    
    return 0 if (assets_ok and pubspec_ok) else 1

if __name__ == '__main__':
    sys.exit(main())
