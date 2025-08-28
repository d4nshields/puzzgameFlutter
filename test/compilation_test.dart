import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/scheduler.dart';
import 'package:puzzgame_flutter/game_module2/domain/entities/puzzle_piece.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/puzzle_coordinate.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/piece_bounds.dart';

void main() {
  test('Compilation test - all types are available', () {
    // Test that PuzzlePiece has isLocked getter
    final piece = PuzzlePiece(
      id: 'test',
      correctRow: 0,
      correctCol: 0,
      correctPosition: PuzzleCoordinate.zero,
      bounds: PieceBounds.zero(),
    );
    
    expect(piece.isLocked, false); // Not placed, so not locked
    piece.placeCorrectly();
    expect(piece.isLocked, true); // Now placed, so locked
    
    // Test that PuzzleCoordinate.zero exists
    final zeroCoord = PuzzleCoordinate.zero;
    expect(zeroCoord.x, 0);
    expect(zeroCoord.y, 0);
    
    // Test that PieceBounds.zero() exists
    final zeroBounds = PieceBounds.zero();
    expect(zeroBounds.paddedSize.width, 0);
    expect(zeroBounds.paddedSize.height, 0);
    
    // Test that Ticker and TickerCallback are available
    final vsync = TestVSync();
    expect(vsync, isNotNull);
  });
}

/// Test ticker provider
class TestVSync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}
