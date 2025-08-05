#!/bin/bash

# Build script for different variants of the Flutter puzzle game
# Usage: ./build.sh [internal|external] [debug|release] [apk|aab]

set -e  # Exit on any error

# Default values
BUILD_VARIANT="external"
BUILD_MODE="release"
BUILD_TYPE="apk"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        internal|external)
            BUILD_VARIANT="$1"
            shift
            ;;
        debug|release)
            BUILD_MODE="$1"
            shift
            ;;
        apk|aab)
            BUILD_TYPE="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: ./build.sh [internal|external] [debug|release] [apk|aab]"
            echo ""
            echo "Build variants:"
            echo "  internal  - All features enabled, debug tools available"
            echo "  external  - Only approved features, production-ready"
            echo ""
            echo "Build modes:"
            echo "  debug     - Debug version with development tools"
            echo "  release   - Optimized production version"
            echo ""
            echo "Build types:"
            echo "  apk       - Android APK for direct installation"
            echo "  aab       - Android App Bundle for Play Store"
            echo ""
            echo "Examples:"
            echo "  ./build.sh internal debug apk    # Internal debug APK"
            echo "  ./build.sh external release aab  # Production Play Store bundle"
            echo "  ./build.sh external               # External release APK (defaults)"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use ./build.sh --help for usage information"
            exit 1
            ;;
    esac
done

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Flutter Puzzle Game Build${NC}"
echo -e "${YELLOW}Build Variant: $BUILD_VARIANT${NC}"
echo -e "${YELLOW}Build Mode: $BUILD_MODE${NC}"
echo -e "${YELLOW}Build Type: $BUILD_TYPE${NC}"
echo ""

# Configuration file path
CONFIG_FILE="lib/core/configuration/build_config.dart"

# Backup current configuration
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"

echo -e "${BLUE}📝 Configuring build variant...${NC}"

# Set the build configuration based on variant
if [ "$BUILD_VARIANT" = "internal" ]; then
    echo -e "${GREEN}Setting INTERNAL build configuration${NC}"
    sed -i "s/const String _activeBuildVariant = 'external';/const String _activeBuildVariant = 'internal';/" "$CONFIG_FILE"
else
    echo -e "${GREEN}Setting EXTERNAL build configuration${NC}"
    sed -i "s/const String _activeBuildVariant = 'internal';/const String _activeBuildVariant = 'external';/" "$CONFIG_FILE"
fi

# Verify the configuration was set correctly
echo -e "${BLUE}🔍 Verifying configuration...${NC}"
if grep -q "_activeBuildVariant = '$BUILD_VARIANT'" "$CONFIG_FILE"; then
    echo -e "${GREEN}✅ Configuration set to $BUILD_VARIANT${NC}"
else
    echo -e "${RED}❌ Failed to set configuration${NC}"
    # Restore backup
    mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"
    exit 1
fi

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean

# Get dependencies
echo -e "${BLUE}📦 Getting dependencies...${NC}"
flutter pub get

# Run code generation if needed
echo -e "${BLUE}⚙️ Running code generation...${NC}"
flutter packages pub run build_runner build --delete-conflicting-outputs

# Build the app
echo -e "${BLUE}🔨 Building Flutter app...${NC}"

# Set build command based on type and mode
if [ "$BUILD_TYPE" = "aab" ]; then
    BUILD_CMD="flutter build appbundle"
else
    BUILD_CMD="flutter build apk"
fi

# Add mode flag
if [ "$BUILD_MODE" = "debug" ]; then
    BUILD_CMD="$BUILD_CMD --debug"
else
    BUILD_CMD="$BUILD_CMD --release"
fi

# Execute build
echo -e "${YELLOW}Executing: $BUILD_CMD${NC}"
$BUILD_CMD

# Create output directory with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="distribution/${BUILD_VARIANT}_${BUILD_MODE}_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# Copy built files to output directory
if [ "$BUILD_TYPE" = "aab" ]; then
    if [ "$BUILD_MODE" = "debug" ]; then
        cp build/app/outputs/bundle/debug/app-debug.aab "$OUTPUT_DIR/puzzlenook_${BUILD_VARIANT}_${BUILD_MODE}.aab"
    else
        cp build/app/outputs/bundle/release/app-release.aab "$OUTPUT_DIR/puzzlenook_${BUILD_VARIANT}_${BUILD_MODE}.aab"
    fi
else
    if [ "$BUILD_MODE" = "debug" ]; then
        cp build/app/outputs/flutter-apk/app-debug.apk "$OUTPUT_DIR/puzzlenook_${BUILD_VARIANT}_${BUILD_MODE}.apk"
    else
        cp build/app/outputs/flutter-apk/app-release.apk "$OUTPUT_DIR/puzzlenook_${BUILD_VARIANT}_${BUILD_MODE}.apk"
    fi
fi

# Create build info file
cat > "$OUTPUT_DIR/build_info.txt" << EOF
Build Information
=================
Timestamp: $(date)
Build Variant: $BUILD_VARIANT
Build Mode: $BUILD_MODE
Build Type: $BUILD_TYPE
Flutter Version: $(flutter --version | head -1)
Dart Version: $(dart --version)
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "Not available")
Git Branch: $(git branch --show-current 2>/dev/null || echo "Not available")

Feature Flags (for $BUILD_VARIANT build):
EOF

# Add feature flag status to build info
if [ "$BUILD_VARIANT" = "internal" ]; then
    cat >> "$OUTPUT_DIR/build_info.txt" << EOF
- Sample Puzzle: ENABLED (for development and testing)
- Debug Tools: ENABLED
- Experimental Features: ENABLED
- Detailed Analytics: ENABLED
- Google Sign-In: ENABLED
- Early Access Registration: ENABLED
- Sharing Flow: ENABLED

Navigation Flow:
- Start: sample_puzzle (test puzzle under development)
- After Game: early_access_registration
- After Registration: sharing_flow
EOF
else
    cat >> "$OUTPUT_DIR/build_info.txt" << EOF
- Sample Puzzle: DISABLED (not ready for users)
- Debug Tools: DISABLED
- Experimental Features: DISABLED
- Detailed Analytics: DISABLED
- Google Sign-In: ENABLED
- Early Access Registration: ENABLED
- Sharing Flow: ENABLED

Navigation Flow:
- Start: early_access_registration (skip sample puzzle)
- After Game: early_access_registration
- After Registration: sharing_flow
EOF
fi

# Restore original configuration
echo -e "${BLUE}🔄 Restoring original configuration...${NC}"
mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"

# Success message
echo ""
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${BLUE}📁 Output directory: $OUTPUT_DIR${NC}"
echo -e "${BLUE}📱 Build file: $(ls $OUTPUT_DIR/*.a?? 2>/dev/null || ls $OUTPUT_DIR/*.apk)${NC}"

# Show file size
BUILD_FILE=$(ls $OUTPUT_DIR/*.a?? 2>/dev/null || ls $OUTPUT_DIR/*.apk)
if [ -f "$BUILD_FILE" ]; then
    FILE_SIZE=$(du -h "$BUILD_FILE" | cut -f1)
    echo -e "${BLUE}📏 File size: $FILE_SIZE${NC}"
fi

echo ""
echo -e "${YELLOW}🎯 Next steps:${NC}"
if [ "$BUILD_VARIANT" = "internal" ]; then
    echo -e "   • This is an INTERNAL build - suitable for development and testing"
    echo -e "   • Sample puzzle is ENABLED for development"
    echo -e "   • All debug tools and experimental features are available"
else
    echo -e "   • This is an EXTERNAL build - suitable for production release"
    echo -e "   • Sample puzzle is DISABLED (not ready for users)"
    echo -e "   • Users will go directly to early access registration"
fi

if [ "$BUILD_TYPE" = "aab" ]; then
    echo -e "   • Upload the .aab file to Google Play Console"
else
    echo -e "   • Install the .apk file directly on Android devices"
fi
