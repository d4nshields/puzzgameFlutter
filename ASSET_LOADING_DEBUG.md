# Asset Loading Debug Guide

**Issue**: Assets exist on disk but Flutter can't load them via `rootBundle.load()`

## Debugging Steps

### 1. **Clean and Rebuild**
```bash
flutter clean
flutter pub get
flutter build linux --release
```

### 2. **Verify pubspec.yaml Asset Declaration**
Ensure this is in your `pubspec.yaml`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/puzzles/
```

### 3. **Test Asset Loading Manually**
Add this test in your game screen to verify assets are accessible:

```dart
// Add this method to GameScreen for testing
Future<void> _testAssetLoading() async {
  try {
    final data = await rootBundle.load('assets/puzzles/sample_puzzle_01/layouts/8x8/pieces/0_0.png');
    print('✅ Asset loading test PASSED: ${data.lengthInBytes} bytes');
  } catch (e) {
    print('❌ Asset loading test FAILED: $e');
  }
}

// Call this in your build method or initState
```

### 4. **Check File Paths**
Verify these files exist:
- `assets/puzzles/sample_puzzle_01/layouts/8x8/pieces/0_0.png`
- `assets/puzzles/sample_puzzle_01/layouts/12x12/pieces/0_0.png`
- `assets/puzzles/sample_puzzle_01/layouts/15x15/pieces/0_0.png`
- `assets/puzzles/sample_puzzle_01/preview.jpg`

### 5. **Simplified Asset Manager**
If the issue persists, try this simplified test:

```dart
Future<void> testPuzzleAssets() async {
  const testPaths = [
    'assets/puzzles/sample_puzzle_01/preview.jpg',
    'assets/puzzles/sample_puzzle_01/layouts/8x8/pieces/0_0.png',
    'assets/puzzles/sample_puzzle_01/layouts/12x12/pieces/0_0.png',
    'assets/puzzles/sample_puzzle_01/layouts/15x15/pieces/0_0.png',
  ];
  
  for (final path in testPaths) {
    try {
      final data = await rootBundle.load(path);
      print('✅ $path (${data.lengthInBytes} bytes)');
    } catch (e) {
      print('❌ $path: $e');
    }
  }
}
```

## Common Solutions

### **Solution 1: Hot Restart Required**
After changing `pubspec.yaml` assets, you need a **full restart**, not just hot reload:
- Stop the app completely
- Run `flutter clean && flutter pub get`
- Rebuild and restart

### **Solution 2: Asset Bundle Regeneration**
Sometimes the asset bundle doesn't update properly:
```bash
rm -rf build/
flutter clean
flutter pub get
flutter build linux
```

### **Solution 3: Case Sensitivity**
Ensure file names match exactly (case-sensitive on Linux):
- `0_0.png` not `0_0.PNG`
- `preview.jpg` not `Preview.jpg`

### **Solution 4: Asset Path Verification**
Double-check the relative path from project root:
```
puzzgameFlutter/
├── pubspec.yaml
├── lib/
└── assets/
    └── puzzles/
        └── sample_puzzle_01/
            ├── preview.jpg
            └── layouts/
                ├── 8x8/pieces/0_0.png
                ├── 12x12/pieces/0_0.png
                └── 15x15/pieces/0_0.png
```

## Expected Debug Output

After the fix, you should see:
```
PuzzleAssetManager: ✅ Found grid size 8x8 for sample_puzzle_01 (12345 bytes)
PuzzleAssetManager: ✅ Found grid size 12x12 for sample_puzzle_01 (23456 bytes)
PuzzleAssetManager: ✅ Found grid size 15x15 for sample_puzzle_01 (34567 bytes)
PuzzleAssetManager: ✅ Found 3 grid sizes for sample_puzzle_01: [8x8, 12x12, 15x15]
PuzzleGameModule: Asset manager initialized with 1 puzzles
```

Instead of:
```
PuzzleAssetManager: ❌ Grid size 8x8 not available for sample_puzzle_01
Exception: No puzzles available
```
