#!/bin/bash
cd /home/daniel/work/puzzgameFlutter
flutter test test/piece_state_machine_test.dart 2>&1 | head -100
