#!/bin/bash
# Quick test for the drag sequence fix

cd /home/daniel/work/puzzgameFlutter

echo "Testing drag sequence fix..."
flutter test test/piece_state_machine_test.dart --name "should handle drag sequence correctly" 2>&1 | tail -20
