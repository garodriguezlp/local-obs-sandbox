#!/bin/bash
set -e

echo "🔄 Resetting Spring Boot Log Stack..."
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Use LOCALOBS_LOG_FOLDER from .env or default to ./logs
LOCALOBS_LOG_FOLDER=${LOCALOBS_LOG_FOLDER:-./logs}

# Stop containers
echo "🛑 Stopping Docker containers..."
docker-compose down -v

# Remove logs with confirmation
if [ -d "$LOCALOBS_LOG_FOLDER" ]; then
    read -p "🗑️  Delete logs directory at $LOCALOBS_LOG_FOLDER? [N/y] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   Removing logs directory..."
        rm -rf "$LOCALOBS_LOG_FOLDER"
    else
        echo "   Keeping logs directory"
    fi
fi

echo ""
echo "✅ Stack reset complete"
echo ""
echo "🚀 Starting fresh stack..."
echo ""

# Start fresh using the up script
if [ ! -f "up.sh" ]; then
    echo "❌ ERROR: up.sh script not found!"
    echo "   The reset script depends on up.sh to restart the stack."
    exit 1
fi

./up.sh
