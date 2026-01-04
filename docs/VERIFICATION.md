# Verification and Testing Guide

This guide provides step-by-step instructions to verify that your Loki + Grafana stack is working correctly with Spring Boot logs.

## Quick Start

### 1. Start the Stack

```bash
# Start all services
docker-compose up -d

# Watch the logs
docker-compose logs -f
```

Wait for all services to be healthy (about 30 seconds).

### 2. Generate Test Logs

```bash
# Generate 100 sample logs
python generate-logs.py batch 100

# Or generate continuously
python generate-logs.py continuous
```

### 3. View Logs in Grafana

1. Open http://localhost:3000
2. Login with `admin` / `admin`
3. Go to "Explore" (compass icon on left)
4. Query: `{job="spring-boot"}`

---

## Detailed Verification Steps

### Step 1: Verify Docker Containers

```bash
# Check all containers are running
docker-compose ps
```

Expected output:
```
NAME                IMAGE                       STATUS
grafana             grafana/grafana:10.2.3      Up (healthy)
loki                grafana/loki:2.9.3          Up (healthy)
promtail            grafana/promtail:2.9.3      Up
```

### Step 2: Verify Loki

#### Check Loki Health

```bash
curl http://localhost:3100/ready
```

Expected output: `ready`

#### Check Loki Can Receive Logs

```bash
# Push a test log entry
curl -X POST http://localhost:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [
      {
        "stream": {
          "job": "test",
          "level": "info"
        },
        "values": [
          ["'$(powershell -Command "([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000).ToString()")'", "test message from curl"]
        ]
      }
    ]
  }'
```

#### Query Loki Directly

```bash
# List available labels
curl http://localhost:3100/loki/api/v1/label

# List label values for 'job'
curl http://localhost:3100/loki/api/v1/label/job/values

# Query logs
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={job="test"}' \
  --data-urlencode 'limit=10'
```

### Step 3: Verify Promtail

#### Check Promtail Metrics

```bash
curl http://localhost:9080/metrics
```

Look for these metrics:
- `promtail_sent_entries_total` - Number of log entries sent
- `promtail_read_bytes_total` - Bytes read from log files
- `promtail_targets_active_total` - Number of active targets

#### Check Promtail Targets

```bash
curl http://localhost:9080/targets
```

You should see your log file target listed with status.

#### View Promtail Logs

```bash
docker-compose logs promtail
```

Look for messages like:
- "Starting Promtail"
- "Tailing file: /var/log/spring-boot/application.log"
- "Successfully pushed logs to Loki"

### Step 4: Verify Grafana

#### Check Grafana Health

```bash
curl http://localhost:3000/api/health
```

Expected output:
```json
{
  "commit": "...",
  "database": "ok",
  "version": "10.2.3"
}
```

#### Check Loki Data Source

```bash
# List data sources
curl -u admin:admin http://localhost:3000/api/datasources
```

You should see Loki configured with URL `http://loki:3100`.

#### Test Loki Connection from Grafana

```bash
curl -u admin:admin http://localhost:3000/api/datasources/proxy/1/loki/api/v1/labels
```

### Step 5: Generate Logs

#### Option A: Batch Generation

```bash
# Generate 100 logs
python generate-logs.py batch 100

# Generate 500 logs
python generate-logs.py batch 500
```

#### Option B: Continuous Generation

```bash
# Generate logs continuously
python generate-logs.py continuous
```

Press Ctrl+C to stop.

#### Option C: Burst Generation

```bash
# Generate 5 bursts of 50 logs each
python generate-logs.py burst 5 50
```

#### Verify Log File

```bash
# View the log file
cat logs/application.log

# Count log lines
wc -l logs/application.log

# View last 10 logs
tail -10 logs/application.log

# Validate JSON format
head -1 logs/application.log | python -m json.tool
```

### Step 6: Query Logs in Grafana

#### Access Grafana Explore

1. Open http://localhost:3000
2. Login: `admin` / `admin`
3. Click "Explore" (compass icon)
4. Select "Loki" data source

#### Basic Queries

**All Spring Boot logs:**
```logql
{job="spring-boot"}
```

**Filter by log level:**
```logql
{job="spring-boot", level="ERROR"}
```

**Search in message:**
```logql
{job="spring-boot"} |= "exception"
```

**Exclude debug logs:**
```logql
{job="spring-boot"} != "DEBUG"
```

#### JSON Queries

**Parse JSON and filter:**
```logql
{job="spring-boot"} | json | level="ERROR"
```

**Filter by logger:**
```logql
{job="spring-boot"} | json | logger=~".*Controller"
```

**Filter by trace ID:**
```logql
{job="spring-boot"} | json | traceId!=""
```

#### Aggregation Queries

**Log rate per second:**
```logql
rate({job="spring-boot"}[1m])
```

**Count by level:**
```logql
sum by (level) (count_over_time({job="spring-boot"}[5m]))
```

**Error rate:**
```logql
sum(rate({job="spring-boot", level="ERROR"}[5m]))
```

**Log volume by application:**
```logql
sum by (application) (count_over_time({job="spring-boot"}[5m]))
```

---

## Expected Results

### After Successful Setup

1. **Loki endpoint** http://localhost:3100/ready returns `ready`
2. **Promtail** is reading logs from `./logs/application.log`
3. **Grafana** is accessible at http://localhost:3000
4. **Logs appear** in Grafana Explore within 1-2 seconds of generation

### Sample Grafana Query Output

When you query `{job="spring-boot"}` in Grafana, you should see:

- Log entries with timestamps
- Color-coded log levels (RED for ERROR, ORANGE for WARN, etc.)
- Full log messages
- Ability to expand logs to see JSON fields
- Trace IDs and span IDs (when present)

---

## Troubleshooting

### Problem: No logs appearing in Grafana

**Check 1: Verify logs are being generated**
```bash
ls -lh logs/application.log
tail logs/application.log
```

**Check 2: Verify Promtail is reading the file**
```bash
docker-compose logs promtail | grep -i "application.log"
```

**Check 3: Verify Promtail is sending to Loki**
```bash
curl http://localhost:9080/metrics | grep promtail_sent_entries_total
```

**Check 4: Query Loki directly**
```bash
curl -G http://localhost:3100/loki/api/v1/label/job/values
```

Should return `["spring-boot"]`.

### Problem: Promtail not reading logs

**Check file permissions:**
```bash
ls -la logs/
```

The logs directory and files must be readable by Docker.

**Check Promtail configuration:**
```bash
docker-compose exec promtail cat /etc/promtail/config.yml
```

**Check Promtail targets:**
```bash
curl http://localhost:9080/targets
```

### Problem: Loki not accepting logs

**Check Loki logs:**
```bash
docker-compose logs loki | tail -50
```

**Check for rate limiting:**
```bash
curl http://localhost:3100/metrics | grep loki_discarded_samples_total
```

**Increase ingestion limits** in `loki-config.yaml`:
```yaml
limits_config:
  ingestion_rate_mb: 20
  ingestion_burst_size_mb: 40
```

### Problem: Grafana can't connect to Loki

**Test from Grafana container:**
```bash
docker-compose exec grafana wget -O- http://loki:3100/ready
```

**Check network connectivity:**
```bash
docker-compose exec grafana ping loki
```

**Verify data source configuration:**
1. Grafana → Configuration → Data Sources
2. Click "Loki"
3. Check URL is `http://loki:3100`
4. Click "Save & Test"

### Problem: Logs are delayed

**Reduce scrape interval** in `promtail-config.yaml`:

Add under `scrape_configs`:
```yaml
scrape_configs:
  - job_name: spring-boot-logs
    # ... existing config ...
    
    # Add these settings
    static_configs:
      - targets:
          - localhost
        labels:
          job: spring-boot
          __path__: /var/log/spring-boot/*.log
        
    # Reduce read frequency (default is 10s)
    file_sd_configs:
      - refresh_interval: 5s
```

Restart Promtail:
```bash
docker-compose restart promtail
```

---

## Performance Testing

### Test 1: Sustained Load

Generate logs continuously for 5 minutes:
```bash
timeout 300 python generate-logs.py continuous
```

**Monitor:**
- Loki memory usage: `docker stats loki`
- Promtail lag: `curl http://localhost:9080/metrics | grep promtail_read_lines_total`
- Query performance in Grafana

### Test 2: Burst Load

Generate large burst:
```bash
python generate-logs.py burst 10 1000
```

**Check:**
- All logs ingested: Check count in Grafana
- No errors in Loki logs: `docker-compose logs loki | grep -i error`
- Promtail backoff: `docker-compose logs promtail | grep -i backoff`

### Test 3: Query Performance

In Grafana, run an aggregation query over large time range:
```logql
sum by (level) (count_over_time({job="spring-boot"}[1h]))
```

**Expected:**
- Query completes in < 5 seconds
- Results are accurate
- No timeout errors

---

## Health Check Script

Create [`health-check.sh`](health-check.sh:1):

```bash
#!/bin/bash

echo "=== Loki + Grafana Stack Health Check ==="
echo ""

# Check Loki
echo -n "Loki: "
if curl -s http://localhost:3100/ready | grep -q "ready"; then
    echo "✓ Ready"
else
    echo "✗ Not ready"
fi

# Check Promtail
echo -n "Promtail: "
if curl -s http://localhost:9080/metrics > /dev/null 2>&1; then
    echo "✓ Running"
    SENT=$(curl -s http://localhost:9080/metrics | grep promtail_sent_entries_total | grep -v "#" | awk '{sum+=$2} END {print sum}')
    echo "  Logs sent: $SENT"
else
    echo "✗ Not responding"
fi

# Check Grafana
echo -n "Grafana: "
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "✓ Healthy"
else
    echo "✗ Unhealthy"
fi

# Check log file
echo -n "Log file: "
if [ -f logs/application.log ]; then
    LINES=$(wc -l < logs/application.log)
    echo "✓ Exists ($LINES lines)"
else
    echo "✗ Not found"
fi

echo ""
echo "=== Labels in Loki ==="
curl -s http://localhost:3100/loki/api/v1/label | python -m json.tool

echo ""
echo "=== Recent Logs ==="
curl -s -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={job="spring-boot"}' \
  --data-urlencode 'limit=5' | python -m json.tool
```

Run it:
```bash
bash health-check.sh
```

---

## Cleanup

### Stop Services
```bash
docker-compose down
```

### Remove Data
```bash
# Stop and remove volumes
docker-compose down -v

# Remove log files
rm -rf logs/
```

### Complete Cleanup
```bash
# Remove everything
docker-compose down -v
rm -rf logs/
docker volume rm loki-data grafana-data promtail-positions
```

---

## Success Criteria

Your stack is working correctly if:

- ✅ All containers are running and healthy
- ✅ Loki `/ready` endpoint returns `ready`
- ✅ Promtail is sending logs (check metrics)
- ✅ Grafana can connect to Loki (test data source)
- ✅ Logs appear in Grafana within 2 seconds of generation
- ✅ JSON fields are parsed correctly (check in Grafana)
- ✅ Log levels are shown as labels
- ✅ Queries return expected results
- ✅ No errors in container logs

---

## Next Steps

After verification:

1. **Create Dashboards**: Build visualization dashboards in Grafana
2. **Set Up Alerts**: Configure alerts for ERROR logs or anomalies
3. **Add More Services**: Extend to monitor multiple Spring Boot apps
4. **Configure Retention**: Set up log retention policies
5. **Optimize Performance**: Tune based on your log volume
6. **Add Authentication**: Secure Grafana and Loki endpoints
7. **Integrate with Tracing**: Connect trace IDs to distributed tracing system

---

## References

- [Loki HTTP API](https://grafana.com/docs/loki/latest/api/)
- [LogQL Syntax](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/configuration/)
- [Grafana Explore](https://grafana.com/docs/grafana/latest/explore/)
