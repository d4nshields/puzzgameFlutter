#!/bin/bash

echo "🔧 Making signing scripts executable..."

# Make scripts executable
chmod +x setup_signing.sh
chmod +x validate_signing.sh  
chmod +x load_env_signing.sh

echo "✅ Scripts are now executable"
echo ""
echo "📋 Available commands:"
echo "   ./setup_signing.sh       - Interactive signing setup"
echo "   ./validate_signing.sh    - Validate current configuration" 
echo "   ./load_env_signing.sh    - Load from environment variables"
echo ""
echo "💡 Run ./setup_signing.sh to get started!"
