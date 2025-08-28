/// Test configuration for Puzzle Nook
/// 
/// This file provides configuration for running different test suites

// Set to false to skip performance tests during regular 'flutter test' runs
const bool runPerformanceTests = false; // Change to true to include performance tests

// Set to false to skip long-running tests
const bool runLongTests = false;

// Test timeout configurations
const Duration quickTestTimeout = Duration(seconds: 30);
const Duration normalTestTimeout = Duration(minutes: 2);
const Duration longTestTimeout = Duration(minutes: 10);
