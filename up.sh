#!/bin/bash
set -e

echo "🚀 Starting Spring Boot Log Stack..."
echo ""

# Create logs directory if it doesn't exist
if [ ! -d "logs" ]; then
    echo "📁 Creating logs directory..."
    mkdir logs
fi

# Start services
echo "🐳 Starting Docker containers..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
sleep 8

# Check Loki
echo ""
if curl -sf http://localhost:3100/ready > /dev/null 2>&1; then
    echo "✅ Loki is ready"
else
    echo "❌ Loki is not responding"
fi

# Check Grafana
if curl -sf http://localhost:3000/api/health | grep -q "ok"; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana is not responding"
fi

# Generate initial logs
echo ""
echo "📝 Generating sample logs..."
python scripts/generate-logs.py batch 50

# Wait for ingestion
sleep 2

# Verify logs in Loki
echo ""
if curl -sf http://localhost:3100/loki/api/v1/label/job/values | grep -q "spring-boot"; then
    echo "✅ Logs successfully ingested into Loki"
else
    echo "⚠️  Logs not yet in Loki (Promtail may still be processing)"
fi

echo ""
echo "✨ Stack is ready!"
echo ""
echo "📊 Grafana UI: http://localhost:3000"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "🔍 Query example: {job=\"spring-boot\"}"
echo ""
