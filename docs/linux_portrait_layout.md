# Linux Desktop Portrait Layout Configuration

**Date**: June 28, 2025  
**Status**: Implemented  
**Feature**: Force Portrait Layout on Linux Desktop

## Problem Addressed

On Linux desktop, the app always uses landscape layout due to the default window dimensions (1280x720), which doesn't showcase the optimized phone layout that was specifically designed for portrait orientation.

## Solution: Native Window Size Constraint

### Implementation Approach

#### 1. **Native Window Configuration (Primary Solution)**
Modified the Linux GTK application window to use portrait dimensions:

```cpp
// File: linux/runner/my_application.cc
// Before: Landscape window
gtk_window_set_default_size(window, 1280, 720);  // 16:9 landscape

// After: Portrait window  
gtk_window_set_default_size(window, 480, 800);   // 3:5 portrait
gtk_window_set_size_request(window, 360, 640);   // Minimum size
```

#### 2. **Flutter-Level Support (Secondary)**
Added desktop window configuration utilities:

```dart
// File: lib/core/infrastructure/desktop_window_config.dart
class DesktopWindowConfig {
  static const double portraitWidth = 480.0;
  static const double portraitHeight = 800.0;
  static const double minWidth = 360.0;
  static const double minHeight = 640.0;
}
```

### Window Dimensions Chosen

#### Portrait Window Size: 480×800
- **Aspect Ratio**: 3:5 (0.6:1) - clearly portrait
- **Phone-like**: Similar to modern phone proportions
- **Desktop Friendly**: Not too narrow for desktop use
- **Layout Optimal**: Perfect for showcasing phone-optimized layout

#### Minimum Size: 360×640
- **Prevents Squashing**: Maintains usable minimum dimensions
- **Layout Integrity**: Ensures UI elements remain accessible
- **Scroll Stick Functional**: Enough space for all interface elements

### Benefits

#### ✅ **Showcases Phone Layout**
- Portrait layout with optimized vertical space usage
- Tray scroll stick appears and functions as designed
- Compact info sections and control buttons work perfectly
- Demonstrates the full mobile user experience

#### ✅ **Maintains Desktop Usability**
- Window can still be resized if needed
- All functionality remains accessible
- Debug console output shows orientation detection
- Familiar desktop window controls (close, minimize, etc.)

#### ✅ **Development Benefits**
- Easy testing of portrait layout on desktop
- No need for emulator or device for portrait testing
- Debug output shows layout calculations
- Consistent behavior across platforms

### Technical Details

#### Files Modified
- `linux/runner/my_application.cc` - Native window size configuration
- `lib/core/infrastructure/desktop_window_config.dart` - Flutter utilities
- `lib/core/infrastructure/app_initializer.dart` - Desktop config initialization
- `lib/game_module/widgets/enhanced_puzzle_game_widget.dart` - Debug output

#### Native GTK Configuration
```cpp
// Set portrait dimensions
gtk_window_set_default_size(window, 480, 800);

// Set minimum size to maintain aspect ratio
gtk_window_set_size_request(window, 360, 640);
```

#### Flutter Detection
```dart
// Automatically detects portrait vs landscape
final orientation = MediaQuery.of(context).orientation;
final isLandscape = orientation == Orientation.landscape;

// Debug output in development
if (DesktopWindowConfig.isDesktop && kDebugMode) {
  print('Size=${screenSize.aspectRatioString}, Orientation=$orientation');
}
```

### Orientation Detection

The app now correctly detects portrait orientation on Linux:

```dart
// Example debug output on Linux:
Enhanced Puzzle Widget: Size=480x800 (0.60:1), 
Orientation=Orientation.portrait, IsLandscape=false
```

### User Experience

#### Desktop Portrait Layout
- **Compact Header**: Reduced puzzle info container
- **Maximized Game Area**: 4:1 flex ratio for puzzle vs tray
- **Visible Scroll Stick**: 20px width tray scroll control
- **Proper Spacing**: 4px gaps between sections
- **Phone-like Feel**: Matches mobile layout exactly

#### Window Behavior
- **Resizable**: User can still resize window if desired
- **Minimum Size**: Prevents layout from breaking
- **Standard Controls**: Normal window minimize/maximize/close
- **Desktop Integration**: Works with all Linux window managers

### Configuration Options

#### Window Sizes
```dart
// Current portrait configuration
portraitWidth: 480.0   // 3:5 aspect ratio
portraitHeight: 800.0
minWidth: 360.0        // Minimum usable size
minHeight: 640.0

// Alternative configurations possible:
// More phone-like: 375×812 (iPhone 13 mini proportions)
// Wider portrait: 540×960 (more desktop-friendly)
// Tall portrait: 400×800 (narrower, more phone-like)
```

#### Easy Modification
To change window size, simply modify the values in `my_application.cc`:

```cpp
// For different portrait proportions
gtk_window_set_default_size(window, 375, 812);  // iPhone-like
gtk_window_set_default_size(window, 540, 960);  // Wider
gtk_window_set_default_size(window, 400, 800);  // Narrower
```

### Platform Support

#### Current Implementation
- ✅ **Linux**: Native GTK window configuration
- ✅ **Flutter Detection**: Works on all platforms
- ✅ **Debug Support**: Development output and utilities

#### Future Extensions
- **Windows**: Similar modification to `windows/runner/main.cpp`
- **macOS**: Modification to `macos/Runner/MainFlutterWindow.swift`
- **Web**: CSS constraints or responsive design

### Development Workflow

#### Testing Portrait Layout
1. **Build for Linux**: `flutter build linux`
2. **Run Application**: Window opens in portrait orientation
3. **Verify Layout**: All elements use portrait optimization
4. **Check Debug Output**: Console shows orientation detection
5. **Test Interactions**: Scroll stick and all features work

#### Debug Information
```bash
# Example console output
DesktopWindowConfig: Portrait layout initialized for desktop
DesktopWindowConfig: Window size 480.0x800.0
Enhanced Puzzle Widget: Size=480x800 (0.60:1), Orientation=Orientation.portrait, IsLandscape=false
```

## Result

Linux desktop now properly showcases the optimized portrait layout, allowing development and testing of the phone-optimized interface without requiring a mobile device or emulator.

**Key Achievements:**
- ✅ **Native Portrait Window**: 480×800 default size forces portrait layout
- ✅ **Layout Optimization Visible**: All vertical space improvements demonstrated
- ✅ **Scroll Stick Functional**: Accessibility features work as designed
- ✅ **Development Friendly**: Easy testing and debugging of mobile layout
- ✅ **Maintainable**: Simple configuration, easy to modify
- ✅ **Cross-Platform Ready**: Foundation for Windows/macOS portrait layout

The Linux desktop app now provides an excellent preview of the mobile user experience while maintaining full desktop functionality.
