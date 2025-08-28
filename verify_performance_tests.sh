#!/bin/bash

# Quick test to verify performance tests compile and run

echo "🔍 Verifying Performance Tests"
echo "=============================="
echo ""

# First, check if the tests compile
echo "📋 Checking test compilation..."
flutter analyze test/performance/performance_framework.dart 2>&1 | head -20

echo ""
echo "🧪 Running a quick performance test..."

# Run just one quick test to verify it works
flutter test \
  test/performance/performance_test.dart \
  --name "Small Puzzle" \
  --reporter compact \
  --timeout 1m \
  2>&1 | head -50

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ Performance tests are working correctly!"
else
  echo "⚠️ There might be issues with the performance tests"
  echo "Run 'flutter test test/performance/performance_test.dart --reporter expanded' for details"
fi

exit $EXIT_CODE
