#!/bin/bash

# Comprehensive test runner for Day 10 completion
# This script runs all tests to verify the system is working correctly

cd /home/daniel/work/puzzgameFlutter

echo "==================================================="
echo "Day 10 Development - Test Suite Verification"
echo "==================================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

run_test() {
    local test_path=$1
    local test_name=$2
    
    echo -e "${YELLOW}Running: $test_name${NC}"
    if flutter test "$test_path" --no-pub 2>&1 | grep -q "All tests passed"; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        return 1
    fi
}

# Track overall success
all_passed=true

echo "1. Core Domain Tests"
echo "-------------------"
run_test "test/game_module2/domain/" "Domain layer tests" || all_passed=false

echo ""
echo "2. Application Layer Tests"
echo "-------------------------"
run_test "test/game_module2/application/" "Application layer tests" || all_passed=false

echo ""
echo "3. Infrastructure Tests"
echo "----------------------"
run_test "test/game_module2/infrastructure/" "Infrastructure tests" || all_passed=false

echo ""
echo "4. Presentation Layer Tests"
echo "--------------------------"
run_test "test/game_module2/presentation/" "Presentation tests" || all_passed=false

echo ""
echo "5. Integration Tests"
echo "-------------------"
run_test "test/integration/" "Integration tests" || all_passed=false

echo ""
echo "==================================================="
if [ "$all_passed" = true ]; then
    echo -e "${GREEN}✓ All test suites passed successfully!${NC}"
    echo "Day 10 development is complete and verified."
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    echo "Running detailed test to see specific failures:"
    flutter test --no-pub
fi
echo "==================================================="
