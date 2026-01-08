#!/bin/bash
set -e

echo "🚀 Starting Spring Boot Log Stack..."
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Use LOG_FOLDER from .env or default to ./logs
LOG_FOLDER=${LOG_FOLDER:-./logs}

# Create logs directory if it doesn't exist
if [ ! -d "$LOG_FOLDER" ]; then
    echo "📁 Creating logs directory at $LOG_FOLDER..."
    mkdir -p "$LOG_FOLDER"
fi

# Start services
echo "🐳 Starting Docker containers..."
docker-compose up -d

# Wait for services to be running
echo "⏳ Waiting for services to be running..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    LOKI_RUNNING=$(docker inspect --format='{{.State.Running}}' loki 2>/dev/null || echo "false")
    PROMTAIL_RUNNING=$(docker inspect --format='{{.State.Running}}' promtail 2>/dev/null || echo "false")
    GRAFANA_RUNNING=$(docker inspect --format='{{.State.Running}}' grafana 2>/dev/null || echo "false")
    
    if [ "$LOKI_RUNNING" = "true" ] && [ "$PROMTAIL_RUNNING" = "true" ] && [ "$GRAFANA_RUNNING" = "true" ]; then
        echo "✅ All services are running"
        break
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "⚠️  Timeout waiting for services to start"
        echo "   Loki: $LOKI_RUNNING, Promtail: $PROMTAIL_RUNNING, Grafana: $GRAFANA_RUNNING"
        break
    fi
    
    sleep 2
done

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

# Generate sample logs if GENERATE_LOGS is enabled
if [ "${GENERATE_LOGS}" = "true" ]; then
    echo ""
    echo "📝 Generating sample logs..."
    jbang scripts/generate-logs.java batch --logs-path "$LOG_FOLDER" 50
    
    # Wait for ingestion
    sleep 2
fi

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
