#!/bin/bash

echo "Cleaning Flutter project..."

# Clean Flutter
flutter clean

# Clean pub cache
flutter pub get

# Clean Android build
cd android
./gradlew clean
cd ..

echo "Build cleanup complete. Try building again with:"
echo "flutter run"
echo "or"
echo "flutter build apk"
