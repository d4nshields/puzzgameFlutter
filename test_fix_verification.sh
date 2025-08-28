#!/bin/bash

# Test runner for interaction integration tests after fixing compilation error
cd /home/daniel/work/puzzgameFlutter

echo "==================================================="
echo "Testing Interaction Integration After Fix"
echo "==================================================="
echo ""

# Run the specific test file
echo "Running interaction integration tests..."
flutter test test/integration/interaction_integration_test.dart --no-pub 2>&1 | tee test_output.log

# Check if tests compiled
if grep -q "Error:" test_output.log; then
    echo ""
    echo "❌ Compilation errors found. See output above."
else
    echo ""
    echo "✅ Tests compiled successfully!"
    
    # Check if tests passed
    if grep -q "All tests passed" test_output.log; then
        echo "✅ All tests passed!"
    elif grep -q "+[0-9]* -[0-9]*:" test_output.log; then
        echo "⚠️ Some tests failed. See output above."
    fi
fi

echo "==================================================="
