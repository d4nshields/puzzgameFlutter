#!/bin/bash

# Example usage of the feature flag system
# This script demonstrates common workflows

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎯 Puzzle Nook Feature Flag System - Usage Examples${NC}"
echo ""

# Example 1: Development workflow
echo -e "${YELLOW}📝 Example 1: Development Workflow${NC}"
echo "1. Switch to internal build for development:"
echo "   ./switch_config.sh internal"
echo ""
echo "2. Run in development mode (hot reload works):"
echo "   flutter run"
echo ""
echo "3. Test features - sample puzzle will be shown"
echo ""

# Example 2: Testing external build
echo -e "${YELLOW}📝 Example 2: Testing External Build${NC}"
echo "1. Switch to external build:"
echo "   ./switch_config.sh external"
echo ""
echo "2. Run in development mode:"
echo "   flutter run"
echo ""
echo "3. Test complete user flow - sample puzzle included"
echo ""

# Example 3: Production builds
echo -e "${YELLOW}📝 Example 3: Production Builds${NC}"
echo "1. Build internal debug APK for testing:"
echo "   ./build.sh internal debug apk"
echo ""
echo "2. Build external release APK for beta testing:"
echo "   ./build.sh external release apk"
echo ""
echo "3. Build external release bundle for Play Store:"
echo "   ./build.sh external release aab"
echo ""

# Example 4: Feature flag usage in code
echo -e "${YELLOW}📝 Example 4: Using Feature Flags in Code${NC}"
echo ""
echo "// Check feature flags:"
echo "if (Features.skipSamplePuzzle) {"
echo "  // Skip sample puzzle flow"
echo "  navigateToEarlyAccess();"
echo "} else {"
echo "  // Show sample puzzle"
echo "  navigateToGame();"
echo "}"
echo ""
echo "// Conditional widgets:"
echo "FeatureGate("
echo "  feature: Features.debugTools,"
echo "  child: DebugButton(),"
echo "  fallback: SizedBox.shrink(),"
echo ")"
echo ""
echo "// Debug-only widgets:"
echo "DebugOnly("
echo "  child: FloatingActionButton("
echo "    onPressed: showDebugMenu,"
echo "    child: Icon(Icons.bug_report),"
echo "  ),"
echo ")"
echo ""

# Current status
echo -e "${YELLOW}📊 Current Configuration Status${NC}"
CONFIG_FILE="lib/core/configuration/build_config.dart"

if [ -f "$CONFIG_FILE" ]; then
    if grep -q "_internalBuildConfig" "$CONFIG_FILE"; then
        echo -e "${GREEN}✅ Current: INTERNAL build${NC}"
        echo "   • Sample puzzle: SKIPPED"
        echo "   • Debug tools: ENABLED"
        echo "   • All features: ENABLED"
    else
        echo -e "${BLUE}✅ Current: EXTERNAL build${NC}"
        echo "   • Sample puzzle: INCLUDED"
        echo "   • Debug tools: DISABLED"
        echo "   • Production features: ENABLED"
    fi
else
    echo -e "${RED}❌ Build configuration not found${NC}"
fi

echo ""
echo -e "${GREEN}🚀 Ready to start development!${NC}"
echo ""
echo "Quick commands:"
echo "  ./switch_config.sh internal    # Switch to development mode"
echo "  ./switch_config.sh external    # Switch to production mode"
echo "  ./build.sh external release    # Build production APK"
echo "  ./build.sh --help             # Show all build options"
