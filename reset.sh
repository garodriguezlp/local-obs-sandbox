#!/bin/bash
set -e

echo "🔄 Resetting Spring Boot Log Stack..."
echo ""

# Stop containers
echo "🛑 Stopping Docker containers..."
docker-compose down -v

# Remove logs
if [ -d "logs" ]; then
    echo "🗑️  Removing logs directory..."
    rm -rf logs
fi

echo ""
echo "✅ Stack reset complete"
echo ""
echo "🚀 Starting fresh stack..."
echo ""

# Start fresh using the up script
if [ -f "up.sh" ]; then
    ./up.sh
else
    # Inline version if up.sh doesn't exist
    mkdir -p logs
    docker-compose up -d
    sleep 8
    python scripts/generate-logs.py batch 50
    echo ""
    echo "✨ Fresh stack is ready!"
    echo "📊 Grafana UI: http://localhost:3000"
fi
