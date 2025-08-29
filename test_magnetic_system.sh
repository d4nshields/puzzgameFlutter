#!/bin/bash

# Test script to verify magnetic gesture system activation

echo "========================================="
echo "🧲 MAGNETIC GESTURE SYSTEM TEST"
echo "========================================="

# Clear logs
adb logcat -c

# Enable magnetic gestures in development environment
echo "📝 Updating database flags..."
cat << 'EOF' > /tmp/enable_magnetic.sql
-- Enable magnetic gestures and related features
UPDATE environment_flag_overrides 
SET value = 'true'::jsonb, enabled = true
WHERE feature_flag_id IN (
  SELECT id FROM feature_flags 
  WHERE name IN ('magnetic_gestures', 'enhanced_feedback', 'smooth_animations')
)
AND environment_id = (SELECT id FROM environments WHERE name = 'development');

-- Verify the update
SELECT 
  ff.name as flag_name,
  e.name as environment,
  efo.value,
  efo.enabled
FROM environment_flag_overrides efo
JOIN feature_flags ff ON efo.feature_flag_id = ff.id
JOIN environments e ON efo.environment_id = e.id
WHERE ff.name IN ('magnetic_gestures', 'enhanced_feedback', 'smooth_animations')
AND e.name = 'development';
EOF

echo "SQL script created at /tmp/enable_magnetic.sql"
echo "Please run this in Supabase SQL editor to enable magnetic features"
echo ""

# Start the app
echo "🚀 Starting app..."
adb shell am start -n com.tinkerplexlabs.puzzlenook/.MainActivity

sleep 3

# Monitor logs with magnetic focus
echo "📱 Monitoring logs for magnetic system..."
echo "========================================="

# Run logcat with filters for our debug traces
adb logcat -s flutter | while IFS= read -r line; do
    # Highlight magnetic-related logs
    if echo "$line" | grep -E "MAGNETIC|🧲|magnetic_gestures|MagneticGesture|DEBUG:" > /dev/null; then
        echo -e "\033[1;32m$line\033[0m"  # Green for magnetic logs
    elif echo "$line" | grep -E "GAMESCREEN|FEATURE_FLAG|FLAGS" > /dev/null; then
        echo -e "\033[1;33m$line\033[0m"  # Yellow for feature flag logs
    elif echo "$line" | grep -E "INTERACTION|WORKSPACE|WIDGET" > /dev/null; then
        echo -e "\033[1;36m$line\033[0m"  # Cyan for interaction logs
    elif echo "$line" | grep -E "ERROR|FAIL|Exception" > /dev/null; then
        echo -e "\033[1;31m$line\033[0m"  # Red for errors
    else
        echo "$line"
    fi
done
