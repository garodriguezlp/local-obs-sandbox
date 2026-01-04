#!/bin/bash

echo "=== Spring Boot Log Management Setup ==="
echo ""

# Create logs directory
echo "Creating logs directory..."
mkdir -p logs
echo "✓ Logs directory created"

# Start Docker Compose stack
echo ""
echo "Starting Docker Compose stack..."
docker-compose up -d

# Wait a few seconds for services to start
echo ""
echo "Waiting for services to start..."
sleep 5

# Check status
echo ""
echo "=== Service Status ==="
docker-compose ps

# Verify Loki
echo ""
echo "=== Verifying Loki ==="
curl -s http://localhost:3100/ready && echo "✓ Loki is ready" || echo "✗ Loki is not ready"

# Verify Grafana
echo ""
echo "=== Verifying Grafana ==="
curl -s http://localhost:3000/api/health | grep -q "ok" && echo "✓ Grafana is healthy" || echo "✗ Grafana is not healthy"

# Generate sample logs
echo ""
echo "=== Generating Sample Logs ==="
python scripts/generate-logs.py batch 50

# Verify logs were sent to Loki
echo ""
echo "=== Verifying Log Ingestion ==="
sleep 2
curl -s http://localhost:3100/loki/api/v1/label/job/values | grep -q "spring-boot" && echo "✓ Logs are in Loki" || echo "✗ Logs not found in Loki"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Access Grafana at: http://localhost:3000"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "Try this query in Grafana Explore: {job=\"spring-boot\"}"
