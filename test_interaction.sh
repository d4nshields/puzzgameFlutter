#!/bin/bash

# Quick test runner script for interaction integration tests
cd /home/daniel/work/puzzgameFlutter

echo "Running interaction integration tests..."
flutter test test/integration/interaction_integration_test.dart --no-pub
