#!/bin/bash

echo "🔍 Checking Sentry Flutter for AD_ID permission..."
echo "================================================"

echo "📦 Sentry Flutter version: $(grep 'sentry_flutter:' pubspec.yaml)"

echo ""
echo "🔍 Checking Sentry's Android dependencies..."

cd android
./gradlew app:dependencies --configuration releaseRuntimeClasspath | grep -E "(sentry)" -A 10 -B 5

echo ""
echo "📋 Checking if Sentry includes Google Play Services..."
./gradlew app:dependencies --configuration releaseRuntimeClasspath | grep -E "(sentry.*gms|gms.*sentry)"

echo ""
echo "💡 Common Sentry + AD_ID issues:"
echo "   - Sentry can auto-collect advertising IDs for user tracking"
echo "   - This can be disabled in Sentry configuration"
echo "   - Check Sentry's Android manifest for automatic permissions"

echo ""
echo "🔧 To disable Sentry advertising ID collection, add to AndroidManifest.xml:"
echo '   <meta-data android:name="io.sentry.auto-init" android:value="false" />'
echo '   <meta-data android:name="io.sentry.performance.enable-automatic-performance-instrumentation" android:value="false" />'
