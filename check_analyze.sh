#!/bin/bash

# Run flutter analyze and format the output
echo "Running flutter analyze..."
cd /home/daniel/work/puzzgameFlutter

flutter analyze 2>&1 | while IFS= read -r line; do
    if echo "$line" | grep -E "error •" > /dev/null; then
        echo -e "\033[1;31m$line\033[0m"  # Red for errors
    elif echo "$line" | grep -E "warning •" > /dev/null; then
        echo -e "\033[1;33m$line\033[0m"  # Yellow for warnings
    elif echo "$line" | grep -E "info •" > /dev/null; then
        echo -e "\033[1;36m$line\033[0m"  # Cyan for info
    elif echo "$line" | grep -E "No issues found!" > /dev/null; then
        echo -e "\033[1;32m$line\033[0m"  # Green for success
    else
        echo "$line"
    fi
done

echo ""
echo "Analysis complete."
