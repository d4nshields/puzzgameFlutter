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
NEW_VERSION_CODE=$((VERSION_CODE + 1))
NEW_VERSION="$NEW_VERSION_NAME+$NEW_VERSION_CODE"

# Update pubspec.yaml
sed -i "s/^version:.*/version: $NEW_VERSION/" "$PUBSPEC_PATH"
echo "Updated pubspec.yaml version: $NEW_VERSION"

# Update build.gradle.kts
GRADLE_PATH="android/app/build.gradle.kts"
sed -i "s/versionCode\s*=\s*[0-9]\+/versionCode = $NEW_VERSION_CODE/" "$GRADLE_PATH"
sed -i "s/versionName\s*=\s*\"[0-9]*\.[0-9]*\.[0-9]*\"/versionName = \"$NEW_VERSION_NAME\"/" "$GRADLE_PATH"
echo "Updated build.gradle.kts: versionCode=$NEW_VERSION_CODE, versionName=$NEW_VERSION_NAME"

echo "Version increment complete!"
echo "Remember to run 'flutter pub get' to update dependencies"
