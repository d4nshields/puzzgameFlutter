#!/bin/bash

echo "Running Flutter analysis to check for errors..."
echo "=============================================="

# Run flutter analyze and filter for errors only
flutter analyze --fatal-infos --fatal-warnings

echo ""
echo "Analysis complete!"
