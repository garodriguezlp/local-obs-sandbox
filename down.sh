#!/bin/bash
set -e

echo "🛑 Stopping Spring Boot Log Stack..."
echo ""

# Stop and remove containers
echo "🐳 Stopping Docker containers..."
docker-compose down

echo ""
echo "✅ Stack stopped successfully"
echo ""
echo "💡 Note: Data volumes and logs are preserved"
echo "   To completely reset, run: ./reset.sh"
echo ""
