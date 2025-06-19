#!/bin/bash

# Regenerate optimized assets with fixed bounds calculation
echo "Regenerating optimized puzzle assets with fixed bounds calculation..."

cd /home/daniel/work/puzzgameFlutter

# Run the Python optimization script
python3 tools/optimize_puzzle_assets.py sample_puzzle_01 --verbose

echo "Optimization complete! Please test the pixel subtraction now."
