#!/bin/bash

# Quick configuration switcher for development
# Usage: ./switch_config.sh [internal|external]

set -e

CONFIG_FILE="lib/core/configuration/build_config.dart"

if [ $# -eq 0 ]; then
    echo "Usage: ./switch_config.sh [internal|external]"
    echo ""
    echo "Current configuration:"
    if grep -q "_activeBuildVariant = 'internal'" "$CONFIG_FILE"; then
        echo "  INTERNAL - Sample puzzle enabled, all development features available"
    else
        echo "  EXTERNAL - Sample puzzle disabled, production-ready features only"
    fi
    exit 0
fi

BUILD_VARIANT="$1"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 Switching to $BUILD_VARIANT configuration...${NC}"

if [ "$BUILD_VARIANT" = "internal" ]; then
    sed -i "s/const String _activeBuildVariant = 'external';/const String _activeBuildVariant = 'internal';/" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Switched to INTERNAL configuration${NC}"
    echo "   • Sample puzzle: ENABLED (for development)"
    echo "   • Debug tools: ENABLED"
    echo "   • Experimental features: ENABLED"
elif [ "$BUILD_VARIANT" = "external" ]; then
    sed -i "s/const String _activeBuildVariant = 'internal';/const String _activeBuildVariant = 'external';/" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Switched to EXTERNAL configuration${NC}"
    echo "   • Sample puzzle: DISABLED (not ready for users)"
    echo "   • Debug tools: DISABLED"
    echo "   • Experimental features: DISABLED"
else
    echo "Error: Unknown build variant '$BUILD_VARIANT'"
    echo "Use 'internal' or 'external'"
    exit 1
fi

echo ""
echo "Run 'flutter hot reload' to apply changes in development mode."
