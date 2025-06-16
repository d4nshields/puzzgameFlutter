#!/usr/bin/env python3
"""
Memory Optimization Benchmark Tool

This script measures memory usage before and after optimization,
providing detailed statistics and performance analysis.
"""

import os
import sys
import json
import time
from pathlib import Path
from typing import Dict, List, Tuple
import argparse

# Add tools directory to path
sys.path.insert(0, str(Path(__file__).parent))
from optimize_puzzle_assets import PuzzleOptimizer

class MemoryBenchmark:
    """Benchmark tool for memory optimization analysis."""
    
    def __init__(self, base_path: str, verbose: bool = False):
        self.base_path = Path(base_path)
        self.verbose = verbose
        self.optimizer = PuzzleOptimizer(base_path, verbose)
    
    def log(self, message: str) -> None:
        """Print log message if verbose is enabled."""
        if self.verbose:
            print(f"[MemoryBenchmark] {message}")
    
    def calculate_original_memory_usage(self, puzzle_id: str, grid_size: str) -> Dict:
        """Calculate memory usage for original (non-optimized) assets."""
        pieces_path = self.base_path / "assets" / "puzzles" / puzzle_id / "layouts" / grid_size / "pieces"
        
        if not pieces_path.exists():
            return {"error": f"Pieces directory not found: {pieces_path}"}
        
        piece_files = list(pieces_path.glob("*.png"))
        pieces_count = len(piece_files)
        
        # Estimate memory assuming 2048x2048 RGBA
        bytes_per_piece = 2048 * 2048 * 4  # RGBA = 4 bytes per pixel
        total_bytes = pieces_count * bytes_per_piece
        total_mb = total_bytes / (1024 * 1024)
        total_gb = total_mb / 1024
        
        return {
            "pieces_count": pieces_count,
            "bytes_per_piece": bytes_per_piece,
            "total_bytes": total_bytes,
            "total_mb": round(total_mb, 1),
            "total_gb": round(total_gb, 2),
            "grid_dimensions": grid_size,
        }
    
    def calculate_optimized_memory_usage(self, puzzle_id: str, grid_size: str) -> Dict:
        """Calculate memory usage for optimized assets."""
        optimized_path = self.base_path / "assets" / "puzzles" / puzzle_id / "layouts" / f"{grid_size}_optimized"
        metadata_path = optimized_path / "optimization_metadata.json"
        
        if not metadata_path.exists():
            return {"error": f"Optimization metadata not found: {metadata_path}"}
        
        try:
            with open(metadata_path, 'r') as f:
                metadata = json.load(f)
            
            stats = metadata.get('statistics', {})
            pieces = metadata.get('pieces', {})
            
            # Calculate actual file sizes
            pieces_path = optimized_path / "pieces"
            actual_total_bytes = 0
            piece_sizes = []
            
            for piece_file in pieces_path.glob("*.png"):
                size = piece_file.stat().st_size
                actual_total_bytes += size
                piece_sizes.append(size)
            
            actual_total_mb = actual_total_bytes / (1024 * 1024)
            actual_total_gb = actual_total_mb / 1024
            
            # Get theoretical calculations from metadata
            theoretical_reduction = stats.get('memory_reduction_percent', 0)
            original_bytes = stats.get('original_total_bytes', 0)
            optimized_bytes = stats.get('optimized_total_bytes', 0)
            
            avg_piece_size_bytes = actual_total_bytes / len(pieces) if pieces else 0
            avg_piece_size_kb = avg_piece_size_bytes / 1024
            
            return {
                "pieces_count": len(pieces),
                "actual_total_bytes": actual_total_bytes,
                "actual_total_mb": round(actual_total_mb, 1),
                "actual_total_gb": round(actual_total_gb, 2),
                "theoretical_reduction_percent": round(theoretical_reduction, 1),
                "theoretical_original_bytes": original_bytes,
                "theoretical_optimized_bytes": optimized_bytes,
                "avg_piece_size_bytes": round(avg_piece_size_bytes),
                "avg_piece_size_kb": round(avg_piece_size_kb, 1),
                "min_piece_size": min(piece_sizes) if piece_sizes else 0,
                "max_piece_size": max(piece_sizes) if piece_sizes else 0,
                "grid_dimensions": grid_size,
            }
            
        except Exception as e:
            return {"error": f"Failed to read optimization metadata: {e}"}
    
    def run_benchmark(self, puzzle_id: str, grid_sizes: List[str] = None) -> Dict:
        """Run complete benchmark analysis for a puzzle."""
        if grid_sizes is None:
            grid_sizes = ['8x8', '12x12', '15x15']
        
        results = {
            "puzzle_id": puzzle_id,
            "timestamp": time.time(),
            "grid_sizes": {},
            "summary": {}
        }
        
        total_original_mb = 0
        total_optimized_mb = 0
        optimized_grids = 0
        
        for grid_size in grid_sizes:
            self.log(f"Analyzing {puzzle_id} {grid_size}")
            
            # Calculate original memory usage
            original = self.calculate_original_memory_usage(puzzle_id, grid_size)
            
            # Calculate optimized memory usage
            optimized = self.calculate_optimized_memory_usage(puzzle_id, grid_size)
            
            grid_result = {
                "original": original,
                "optimized": optimized,
                "analysis": {}
            }
            
            # Perform comparison analysis
            if "error" not in original and "error" not in optimized:
                reduction_mb = original["total_mb"] - optimized["actual_total_mb"]
                reduction_percent = (reduction_mb / original["total_mb"]) * 100
                compression_ratio = original["total_mb"] / optimized["actual_total_mb"]
                
                grid_result["analysis"] = {
                    "memory_saved_mb": round(reduction_mb, 1),
                    "memory_saved_gb": round(reduction_mb / 1024, 2),
                    "reduction_percent": round(reduction_percent, 1),
                    "compression_ratio": round(compression_ratio, 1),
                    "status": "optimized"
                }
                
                total_original_mb += original["total_mb"]
                total_optimized_mb += optimized["actual_total_mb"]
                optimized_grids += 1
                
            elif "error" not in original:
                grid_result["analysis"] = {
                    "status": "not_optimized",
                    "potential_savings_mb": original["total_mb"] * 0.7,  # Estimate 70% savings
                    "potential_savings_gb": (original["total_mb"] * 0.7) / 1024,
                }
                total_original_mb += original["total_mb"]
            else:
                grid_result["analysis"] = {"status": "unavailable"}
            
            results["grid_sizes"][grid_size] = grid_result
        
        # Calculate summary statistics
        if optimized_grids > 0:
            overall_reduction = ((total_original_mb - total_optimized_mb) / total_original_mb) * 100
            overall_compression = total_original_mb / total_optimized_mb
            
            results["summary"] = {
                "total_grids_analyzed": len(grid_sizes),
                "optimized_grids": optimized_grids,
                "total_original_memory_mb": round(total_original_mb, 1),
                "total_optimized_memory_mb": round(total_optimized_mb, 1),
                "total_memory_saved_mb": round(total_original_mb - total_optimized_mb, 1),
                "total_memory_saved_gb": round((total_original_mb - total_optimized_mb) / 1024, 2),
                "overall_reduction_percent": round(overall_reduction, 1),
                "overall_compression_ratio": round(overall_compression, 1),
                "optimization_status": "partial" if optimized_grids < len(grid_sizes) else "complete"
            }
        
        return results
    
    def print_benchmark_results(self, results: Dict) -> None:
        """Print formatted benchmark results."""
        puzzle_id = results["puzzle_id"]
        print(f"\n{'='*60}")
        print(f"Memory Optimization Benchmark: {puzzle_id}")
        print(f"{'='*60}")
        
        for grid_size, data in results["grid_sizes"].items():
            print(f"\n📐 {grid_size} Grid:")
            print("-" * 20)
            
            original = data["original"]
            optimized = data["optimized"]
            analysis = data["analysis"]
            
            if "error" in original:
                print(f"   ❌ Original: {original['error']}")
                continue
            
            print(f"   📊 Original:  {original['total_mb']} MB ({original['pieces_count']} pieces)")
            
            if "error" in optimized:
                print(f"   ⚠️  Optimized: Not available ({optimized['error']})")
                if "potential_savings_mb" in analysis:
                    print(f"   💡 Potential:  ~{analysis['potential_savings_mb']:.1f} MB savings (est. 70%)")
            else:
                print(f"   ✅ Optimized: {optimized['actual_total_mb']} MB ({optimized['pieces_count']} pieces)")
                if "memory_saved_mb" in analysis:
                    print(f"   💾 Savings:   {analysis['memory_saved_mb']} MB ({analysis['reduction_percent']:.1f}%)")
                    print(f"   📈 Ratio:     {analysis['compression_ratio']:.1f}:1 compression")
        
        # Print summary
        if "summary" in results and results["summary"]:
            summary = results["summary"]
            print(f"\n🎯 Overall Summary:")
            print("-" * 20)
            print(f"   Grids analyzed: {summary['total_grids_analyzed']}")
            print(f"   Optimized grids: {summary['optimized_grids']}")
            
            if summary["optimized_grids"] > 0:
                print(f"   Total original: {summary['total_original_memory_mb']} MB")
                print(f"   Total optimized: {summary['total_optimized_memory_mb']} MB")
                print(f"   Total saved: {summary['total_memory_saved_mb']} MB ({summary['overall_reduction_percent']:.1f}%)")
                print(f"   Overall ratio: {summary['overall_compression_ratio']:.1f}:1")
                
                # Mobile device impact
                print(f"\n📱 Mobile Device Impact:")
                print("-" * 25)
                if summary['total_original_memory_mb'] > 2000:
                    print("   Before: ❌ Would crash on most mobile devices (>2GB)")
                elif summary['total_original_memory_mb'] > 1000:
                    print("   Before: ⚠️  High memory usage, crashes likely (>1GB)")
                else:
                    print("   Before: ✅ Acceptable for high-end devices")
                
                if summary['total_optimized_memory_mb'] > 1000:
                    print("   After:  ⚠️  Still high, but much improved")
                elif summary['total_optimized_memory_mb'] > 500:
                    print("   After:  ✅ Good - works on most devices")
                else:
                    print("   After:  🚀 Excellent - works on all devices")
    
    def save_benchmark_results(self, results: Dict, output_path: str) -> None:
        """Save benchmark results to JSON file."""
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        self.log(f"Benchmark results saved to: {output_file}")

def main():
    """Main CLI interface."""
    parser = argparse.ArgumentParser(
        description="Benchmark memory optimization for puzzle assets",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run complete benchmark
  python benchmark_memory_optimization.py sample_puzzle_01
  
  # Benchmark specific grid sizes
  python benchmark_memory_optimization.py sample_puzzle_01 --grid-sizes 8x8 12x12
  
  # Save results to file
  python benchmark_memory_optimization.py sample_puzzle_01 --output results.json
  
  # Verbose output
  python benchmark_memory_optimization.py sample_puzzle_01 --verbose
        """
    )
    
    parser.add_argument('puzzle_id', help='Puzzle identifier (e.g., sample_puzzle_01)')
    parser.add_argument('--grid-sizes', nargs='+', help='Specific grid sizes to benchmark')
    parser.add_argument('--output', '-o', help='Save results to JSON file')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--base-path', default='.', help='Base path to puzzle game project')
    
    args = parser.parse_args()
    
    # Initialize benchmark tool
    benchmark = MemoryBenchmark(args.base_path, verbose=args.verbose)
    
    # Run benchmark
    results = benchmark.run_benchmark(args.puzzle_id, args.grid_sizes)
    
    # Print results
    benchmark.print_benchmark_results(results)
    
    # Save results if requested
    if args.output:
        benchmark.save_benchmark_results(results, args.output)
    
    # Return appropriate exit code
    summary = results.get("summary", {})
    if summary and summary.get("optimized_grids", 0) > 0:
        print(f"\n✅ Benchmark completed successfully!")
        sys.exit(0)
    else:
        print(f"\n⚠️  No optimized assets found. Run optimization first:")
        print(f"python tools/optimize_puzzle_assets.py {args.puzzle_id}")
        sys.exit(1)

if __name__ == '__main__':
    main()
