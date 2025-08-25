#!/bin/bash

# Performance Test Runner for Puzzle Nook
# 
# This script runs performance benchmarks locally and generates reports
# Usage: ./run_performance_tests.sh [options]
#
# Options:
#   --baseline    Create a new performance baseline
#   --compare     Compare with existing baseline
#   --ci          Run in CI mode (strict thresholds)
#   --quick       Run only quick tests
#   --full        Run all tests including long sessions
#   --help        Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
CREATE_BASELINE=false
COMPARE_BASELINE=true
CI_MODE=false
TEST_SUITE="standard"
RESULTS_DIR="test_results/performance"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --baseline)
      CREATE_BASELINE=true
      shift
      ;;
    --compare)
      COMPARE_BASELINE=true
      shift
      ;;
    --ci)
      CI_MODE=true
      shift
      ;;
    --ci-runner)
      # Special mode to run the CI runner directly
      echo -e "${BLUE}🚀 Running CI Performance Runner${NC}"
      dart test/performance/ci_runner.dart
      exit $?
      ;;
    --quick)
      TEST_SUITE="quick"
      shift
      ;;
    --full)
      TEST_SUITE="full"
      shift
      ;;
    --help)
      echo "Performance Test Runner for Puzzle Nook"
      echo ""
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --baseline    Create a new performance baseline"
      echo "  --compare     Compare with existing baseline"
      echo "  --ci          Run in CI mode (strict thresholds)"
      echo "  --ci-runner   Run the CI runner directly (for CI/CD pipelines)"
      echo "  --quick       Run only quick tests"
      echo "  --full        Run all tests including long sessions"
      echo "  --help        Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Print configuration
echo -e "${BLUE}🚀 Performance Test Configuration${NC}"
echo "=================================="
echo "Test Suite: $TEST_SUITE"
echo "CI Mode: $CI_MODE"
echo "Create Baseline: $CREATE_BASELINE"
echo "Compare with Baseline: $COMPARE_BASELINE"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Check Flutter installation
echo -e "${BLUE}📋 Checking Flutter environment...${NC}"
flutter doctor -v || {
  echo -e "${RED}❌ Flutter is not properly installed${NC}"
  exit 1
}

# Get dependencies
echo -e "${BLUE}📦 Getting dependencies...${NC}"
flutter pub get

# Clean previous results
if [ "$CI_MODE" = true ]; then
  echo -e "${YELLOW}🧹 Cleaning previous results...${NC}"
  # Safe cleanup with directory check
  if [ -n "$RESULTS_DIR" ] && [ -d "$RESULTS_DIR" ]; then
    find "$RESULTS_DIR" -mindepth 1 -delete 2>/dev/null || true
  fi
fi

# Run performance tests
echo -e "${BLUE}🏃 Running performance tests...${NC}"
echo ""

# Temporarily disable errexit to capture test failures
set +e

if [ "$TEST_SUITE" = "quick" ]; then
  # Run only quick tests
  flutter test \
    test/performance/performance_test.dart \
    --name "Small Puzzle|Medium Puzzle|Many Pieces" \
    --reporter expanded \
    --timeout 5m
elif [ "$TEST_SUITE" = "full" ]; then
  # Run all tests
  flutter test \
    test/performance/performance_test.dart \
    --reporter expanded \
    --timeout 15m
else
  # Run standard test suite
  flutter test \
    test/performance/performance_test.dart \
    --reporter expanded \
    --timeout 10m
fi

TEST_EXIT_CODE=$?

# Re-enable errexit
set -e

# Check if CI summary was generated
if [ -f "$RESULTS_DIR/ci_summary.json" ]; then
  echo ""
  echo -e "${BLUE}📊 Test Results Summary${NC}"
  echo "======================="
  
  # Parse results using Python (more portable than jq)
  python3 -c "
import json
import sys

with open('$RESULTS_DIR/ci_summary.json', 'r') as f:
    summary = json.load(f)
    
print(f'Total Tests: {summary[\"totalTests\"]}')
print(f'Passed: {summary[\"passed\"]}')
print(f'Failed: {summary[\"failed\"]}')
print(f'Pass Rate: {summary[\"passRate\"]*100:.1f}%')
print()

if summary['failed'] > 0:
    print('Failed Tests:')
    for test, result in summary['results'].items():
        if not result['passed']:
            print(f'  ❌ {test}')
            print(f'     FPS: {result[\"avgFps\"]:.1f}')
            print(f'     Frame Time: {result[\"avgFrameTime\"]:.2f}ms')
" || echo "Could not parse summary file"
fi

# Handle baseline creation
if [ "$CREATE_BASELINE" = true ]; then
  echo ""
  echo -e "${BLUE}📝 Creating new performance baseline...${NC}"
  
  if [ -f "$RESULTS_DIR/ci_summary.json" ]; then
    cp "$RESULTS_DIR/ci_summary.json" performance_baseline.json
    echo -e "${GREEN}✅ Baseline created successfully${NC}"
  else
    echo -e "${RED}❌ Could not create baseline - no results found${NC}"
    exit 1
  fi
fi

# Compare with baseline if requested
if [ "$COMPARE_BASELINE" = true ] && [ -f "performance_baseline.json" ]; then
  echo ""
  echo -e "${BLUE}🔍 Comparing with baseline...${NC}"
  
  python3 -c "
import json

with open('performance_baseline.json', 'r') as f:
    baseline = json.load(f)
    
with open('$RESULTS_DIR/ci_summary.json', 'r') as f:
    current = json.load(f)
    
print('Performance Comparison:')
print('-' * 30)

for test in baseline['results']:
    if test in current['results']:
        base_fps = baseline['results'][test]['avgFps']
        curr_fps = current['results'][test]['avgFps']
        diff = ((curr_fps - base_fps) / base_fps) * 100
        
        symbol = '✅' if diff >= -5 else '⚠️' if diff >= -10 else '❌'
        print(f'{symbol} {test}:')
        print(f'   FPS: {base_fps:.1f} → {curr_fps:.1f} ({diff:+.1f}%)')
" || echo "Could not compare with baseline"
fi

# Generate performance report
echo ""
echo -e "${BLUE}📄 Generating performance report...${NC}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$RESULTS_DIR/performance_report_$TIMESTAMP.md"

# Find the most recent markdown report
LATEST_MD=$(ls -t "$RESULTS_DIR"/*.md 2>/dev/null | head -n1)

if [ -f "$LATEST_MD" ]; then
  cp "$LATEST_MD" "$REPORT_FILE"
  echo -e "${GREEN}✅ Report saved to: $REPORT_FILE${NC}"
  
  # Display report preview
  echo ""
  echo "Report Preview:"
  echo "==============="
  head -n 20 "$REPORT_FILE"
  echo "..."
  echo ""
  echo "Full report available at: $REPORT_FILE"
else
  echo -e "${YELLOW}⚠️ No markdown report generated${NC}"
fi

# CI mode exit handling
if [ "$CI_MODE" = true ]; then
  if [ $TEST_EXIT_CODE -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Performance tests failed in CI mode${NC}"
    exit $TEST_EXIT_CODE
  fi
  
  # Check pass rate for CI
  if [ -f "$RESULTS_DIR/ci_summary.json" ]; then
    # Use Python to check pass rate (no bc dependency)
    python3 -c "
import json
import sys
with open('$RESULTS_DIR/ci_summary.json') as f:
    data = json.load(f)
    pass_rate = data['passRate']
    if pass_rate < 0.9:
        print(f'Pass rate {pass_rate:.2%} is below 90% threshold')
        sys.exit(1)
" || {
      echo ""
      echo -e "${RED}❌ Pass rate below 90% threshold for CI${NC}"
      exit 1
    }
  fi
fi

# Final status
echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✅ Performance tests completed successfully!${NC}"
else
  echo -e "${RED}❌ Performance tests completed with failures${NC}"
fi

exit $TEST_EXIT_CODE
