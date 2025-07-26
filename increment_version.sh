#!/bin/bash

# Script to increment version numbers in Flutter project
# Usage: ./increment_version.sh [major|minor|patch]

set -e  # Exit on error

# Set the root directory to the script location
cd "$(dirname "$0")"

# Default to patch increment if no argument provided
INCREMENT_TYPE=${1:-patch}

# Read current version from pubspec.yaml
PUBSPEC_PATH="pubspec.yaml"
CURRENT_VERSION=$(grep -E "^version:" "$PUBSPEC_PATH" | awk '{print $2}' | tr -d "'\"")

# Split version into components
IFS='+' read -r VERSION_NAME VERSION_CODE <<< "$CURRENT_VERSION"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_NAME"

# Increment based on the specified type
case $INCREMENT_TYPE in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Unknown increment type: $INCREMENT_TYPE. Use major, minor, or patch."
    exit 1
    ;;
esac

# Create new version strings
NEW_VERSION_NAME="$MAJOR.$MINOR.$PATCH"

# Generate timestamp-based version code (YYMMDDHHMM format)
# YY = years since 2025 (2025=00, 2026=01, etc.)
# This ensures version codes are always increasing across years
CURRENT_YEAR=$(date +"%Y")
YEAR_OFFSET=$((CURRENT_YEAR - 2025))
TIMESTAMP_VERSION_CODE=$(printf "%02d%s" $YEAR_OFFSET $(date +"%m%d%H%M"))

# Remove leading zeros to ensure it's treated as a number
NEW_VERSION_CODE=$((10#$TIMESTAMP_VERSION_CODE))

NEW_VERSION="$NEW_VERSION_NAME+$NEW_VERSION_CODE"

echo "🔢 Generated timestamp-based version code: $NEW_VERSION_CODE (Year offset: $YEAR_OFFSET, $(date +'%Y-%m-%d %H:%M'))"

# Update pubspec.yaml
sed -i "s/^version:.*/version: $NEW_VERSION/" "$PUBSPEC_PATH"
echo "✅ Updated pubspec.yaml version: $NEW_VERSION"

# Update build.gradle.kts
GRADLE_PATH="android/app/build.gradle.kts"
sed -i "s/versionCode\s*=\s*[0-9]\+/versionCode = $NEW_VERSION_CODE/" "$GRADLE_PATH"
sed -i "s/versionName\s*=\s*\"[0-9]*\.[0-9]*\.[0-9]*\"/versionName = \"$NEW_VERSION_NAME\"/" "$GRADLE_PATH"
echo "✅ Updated build.gradle.kts: versionCode=$NEW_VERSION_CODE, versionName=$NEW_VERSION_NAME"

# Show verification
echo ""
echo "📋 Verification:"
grep "^version:" "$PUBSPEC_PATH"
grep -E "versionCode|versionName" "$GRADLE_PATH"

echo ""
echo "🚀 Version increment complete!"
echo "📅 Timestamp: $(date)"
echo "💡 Remember to run 'flutter pub get' to update dependencies"
