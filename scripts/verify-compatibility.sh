#!/bin/bash

# ===========================================
# PROMTAIL COMPATIBILITY VERIFICATION SCRIPT
# ===========================================
# This script helps verify that Promtail 3.5.0 is working correctly with Loki 2.9.2
#
# Usage:
#   bash scripts/verify-compatibility.sh
#   OR
#   chmod +x scripts/verify-compatibility.sh && ./scripts/verify-compatibility.sh

set -e

echo "================================================"
echo "🔍 Promtail 3.5.0 Compatibility Check"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "ok" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "fail" ]; then
        echo -e "${RED}✗${NC} $message"
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${BLUE}ℹ${NC} $message"
    fi
}

# Function to check if command succeeded
check_command() {
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Check if Docker is running
echo "Step 1: Checking Docker..."
if docker ps > /dev/null 2>&1; then
    print_status "ok" "Docker is running"
else
    print_status "fail" "Docker is not running or accessible"
    exit 1
fi
echo ""

# Check if containers are running
echo "Step 2: Checking containers..."
LOKI_RUNNING=$(docker ps --filter "name=loki" --filter "status=running" -q)
PROMTAIL_RUNNING=$(docker ps --filter "name=promtail" --filter "status=running" -q)
GRAFANA_RUNNING=$(docker ps --filter "name=grafana" --filter "status=running" -q)

if [ -n "$LOKI_RUNNING" ]; then
    print_status "ok" "Loki is running"
else
    print_status "fail" "Loki is not running"
fi

if [ -n "$PROMTAIL_RUNNING" ]; then
    print_status "ok" "Promtail is running"
else
    print_status "fail" "Promtail is not running"
    echo ""
    print_status "info" "Try starting with: docker-compose up -d"
    exit 1
fi

if [ -n "$GRAFANA_RUNNING" ]; then
    print_status "ok" "Grafana is running"
else
    print_status "warn" "Grafana is not running"
fi
echo ""

# Check Loki health
echo "Step 3: Checking Loki health..."
LOKI_READY=$(curl -s http://localhost:3100/ready 2>/dev/null)
if [ "$LOKI_READY" = "ready" ]; then
    print_status "ok" "Loki is ready and accepting requests"
else
    print_status "fail" "Loki is not ready (response: $LOKI_READY)"
fi
echo ""

# Check Promtail health
echo "Step 4: Checking Promtail health..."
PROMTAIL_READY=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9080/ready 2>/dev/null)
if [ "$PROMTAIL_READY" = "200" ]; then
    print_status "ok" "Promtail is healthy (HTTP $PROMTAIL_READY)"
else
    print_status "warn" "Promtail health check returned HTTP $PROMTAIL_READY"
    print_status "info" "This may be normal if Promtail is still starting up"
fi
echo ""

# Check Promtail logs for errors
echo "Step 5: Checking Promtail logs for errors..."
PROMTAIL_ERRORS=$(docker logs promtail 2>&1 | grep -i "error\|fatal\|panic" | head -5)
if [ -z "$PROMTAIL_ERRORS" ]; then
    print_status "ok" "No errors found in Promtail logs"
else
    print_status "warn" "Found potential issues in Promtail logs:"
    echo "$PROMTAIL_ERRORS" | sed 's/^/    /'
fi
echo ""

# Check if Promtail is sending logs
echo "Step 6: Checking if Promtail is sending logs to Loki..."
SENT_ENTRIES=$(curl -s http://localhost:9080/metrics 2>/dev/null | grep "promtail_sent_entries_total" | awk '{print $2}' | head -1)
if [ -n "$SENT_ENTRIES" ] && [ "$SENT_ENTRIES" != "0" ]; then
    print_status "ok" "Promtail has sent $SENT_ENTRIES log entries"
else
    print_status "warn" "Promtail has not sent any logs yet (sent: ${SENT_ENTRIES:-0})"
    print_status "info" "Try generating logs: python scripts/generate-logs.py batch 10"
fi
echo ""

# Check Promtail targets
echo "Step 7: Checking Promtail file targets..."
TARGETS=$(curl -s http://localhost:9080/targets 2>/dev/null)
if echo "$TARGETS" | grep -q "spring-boot"; then
    print_status "ok" "Promtail is watching Spring Boot log files"
else
    print_status "warn" "Could not verify Promtail targets"
fi
echo ""

# Check Promtail version
echo "Step 8: Verifying Promtail version..."
PROMTAIL_VERSION=$(docker inspect grafana/promtail:3.5.0 2>/dev/null | grep -i "org.opencontainers.image.version" | head -1)
if [ -n "$PROMTAIL_VERSION" ]; then
    print_status "ok" "Promtail image information found"
    echo "    $PROMTAIL_VERSION"
else
    print_status "warn" "Could not verify Promtail version metadata"
    print_status "info" "This is normal if the image doesn't have OCI labels"
fi
echo ""

# Test query to Loki
echo "Step 9: Testing log query to Loki..."
QUERY_RESULT=$(curl -s -G "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="spring-boot"}' --data-urlencode 'limit=1' 2>/dev/null)
if echo "$QUERY_RESULT" | grep -q "\"status\":\"success\""; then
    LOG_COUNT=$(echo "$QUERY_RESULT" | grep -o '"result":\[' | wc -l)
    if [ "$LOG_COUNT" -gt 0 ]; then
        print_status "ok" "Successfully queried logs from Loki"
    else
        print_status "warn" "Query successful but no logs found"
        print_status "info" "Try generating logs: python scripts/generate-logs.py batch 10"
    fi
else
    print_status "fail" "Failed to query logs from Loki"
fi
echo ""

# Check restart count
echo "Step 10: Checking container restart count..."
PROMTAIL_RESTARTS=$(docker inspect promtail 2>/dev/null | grep -i "RestartCount" | awk -F: '{print $2}' | tr -d ' ,')
if [ -z "$PROMTAIL_RESTARTS" ]; then
    PROMTAIL_RESTARTS=0
fi

if [ "$PROMTAIL_RESTARTS" -eq 0 ]; then
    print_status "ok" "Promtail has not restarted (stable)"
elif [ "$PROMTAIL_RESTARTS" -le 3 ]; then
    print_status "warn" "Promtail has restarted $PROMTAIL_RESTARTS time(s)"
    print_status "info" "Check logs: docker logs promtail"
else
    print_status "fail" "Promtail has restarted $PROMTAIL_RESTARTS times (unstable!)"
    print_status "info" "This indicates compatibility issues"
    print_status "info" "See docs/PROMTAIL-COMPATIBILITY.md for solutions"
fi
echo ""

# Summary
echo "================================================"
echo "📊 SUMMARY"
echo "================================================"
echo ""

if [ -n "$LOKI_RUNNING" ] && [ -n "$PROMTAIL_RUNNING" ] && [ "$PROMTAIL_RESTARTS" -eq 0 ] && [ -n "$SENT_ENTRIES" ] && [ "$SENT_ENTRIES" != "0" ]; then
    print_status "ok" "All checks passed! Promtail 3.5.0 is compatible with Loki 2.9.2"
    echo ""
    echo "Next steps:"
    echo "  1. Access Grafana: http://localhost:3000 (admin/admin)"
    echo "  2. Go to Explore and query: {job=\"spring-boot\"}"
    echo "  3. Generate more logs: python scripts/generate-logs.py batch 100"
elif [ -n "$PROMTAIL_RUNNING" ]; then
    print_status "warn" "Promtail is running but some checks failed"
    echo ""
    echo "Recommendations:"
    echo "  1. Generate test logs: python scripts/generate-logs.py batch 10"
    echo "  2. Wait 30 seconds and re-run this script"
    echo "  3. If issues persist, check: docs/PROMTAIL-COMPATIBILITY.md"
else
    print_status "fail" "Promtail has compatibility issues"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check logs: docker logs promtail"
    echo "  2. See detailed guide: docs/PROMTAIL-COMPATIBILITY.md"
    echo "  3. Try minimal config: config/promtail-config-minimal.yaml"
fi
echo ""
