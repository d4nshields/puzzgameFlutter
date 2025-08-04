#!/usr/bin/env bash

set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Making signing scripts executable..."

# Make scripts executable with error handling
for f in setup_signing.sh validate_signing.sh load_env_signing.sh; do
    chmod +x "${script_dir}/${f}" 2>/dev/null || echo "⚠️ ${f} not found"
done

echo "✅ Scripts are now executable"
echo ""
echo "📋 Available commands:"
echo "   ./setup_signing.sh       - Interactive signing setup"
echo "   ./validate_signing.sh    - Validate current configuration" 
echo "   ./load_env_signing.sh    - Load from environment variables"
echo ""
echo "💡 Run ./setup_signing.sh to get started!"
