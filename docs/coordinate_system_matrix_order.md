# Coordinate System Transformation Documentation

## Matrix Operation Order in Flutter/Dart

When using the Flutter/Dart Matrix4 class with the cascade operator (..), operations are applied in the order they are written. Each operation modifies the existing matrix.

## The Correct Implementation

For screen-to-canvas transformation where we want: `canvas = (screen - offset) / scale`

```dart
// CORRECT - operations are applied in sequence
_screenToCanvas = Matrix4.identity()
  ..translate(-offsetX, -offsetY)     // First: subtract offset
  ..scale(1 / scale, 1 / scale, 1.0); // Then: divide by scale
```

This correctly implements the transformation:
1. Translate the screen point by -offset (moves origin)
2. Scale the result by 1/scale (converts to canvas units)

## Why The Order Matters

The Matrix4 cascade operations work by modifying the matrix with each call:
- `translate()` multiplies the current matrix by a translation matrix
- `scale()` multiplies the current matrix by a scale matrix

The final matrix, when applied to a column vector, performs the operations in the order they were specified.

## Visual Example

Consider a screen of 800x600 pixels and a game area of 400x300:
- Scale factor: 2 (the game is displayed at 2x size)
- Offset: (0, 0) (centered)

### Screen to Canvas Transformation

| Screen Point | Expected Canvas | With Wrong Order | With Correct Order |
|--------------|-----------------|------------------|-------------------|
| (0, 0) | (0, 0) | (0, 0) ❌ | (0, 0) ✅ |
| (400, 300) | (200, 150) | (200, 150) ❌ | (200, 150) ✅ |
| (800, 600) | (400, 300) | (400, 300) ❌ | (400, 300) ✅ |

The issue becomes apparent with non-centered game areas:

Screen: 1000x600, Game: 400x300
- Scale: 2
- Offset: (100, 0) (horizontal padding)

| Screen Point | Expected Canvas | With Wrong Order | With Correct Order |
|--------------|-----------------|------------------|-------------------|
| (100, 0) | (0, 0) | (-50, 0) ❌ | (0, 0) ✅ |
| (500, 300) | (200, 150) | (150, 150) ❌ | (200, 150) ✅ |
| (900, 600) | (400, 300) | (350, 300) ❌ | (400, 300) ✅ |

## General Rule

For transforming from space A to space B:
1. **Remove A's offset** (translate by -offset)
2. **Apply scale** to convert units
3. **Add B's offset** (if needed)

Always remember: **Last operation specified is first applied** in matrix multiplication with column vectors.

## Testing

Run the test suite to verify transformations:
```bash
flutter test test/coordinate_system_test.dart
```

The tests verify:
- Centered game areas
- Off-center game areas (with padding)
- Round-trip transformations
- Matrix operation order
