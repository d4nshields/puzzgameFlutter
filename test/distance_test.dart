import 'package:flutter_test/flutter_test.dart';
import 'package:puzzgame_flutter/game_module2/domain/value_objects/puzzle_coordinate.dart';

void main() {
  test('Distance calculation verification', () {
    final pos1 = PuzzleCoordinate(x: 95, y: 95);
    final pos2 = PuzzleCoordinate(x: 100, y: 100);
    
    final distance = pos1.distanceTo(pos2);
    print('Distance from (95,95) to (100,100): $distance');
    print('Expected: ~7.071');
    print('Is less than 50? ${distance < 50}');
    
    expect(distance < 50, true);
    expect(distance > 7 && distance < 8, true);
  });
}
