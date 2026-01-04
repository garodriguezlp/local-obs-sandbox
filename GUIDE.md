# Spring Boot Log Management with Loki and Grafana

A comprehensive guide to setting up a local log management solution for Spring Boot applications using Loki and Grafana.

## Table of Contents

1. [Conceptual Overview](#conceptual-overview)
2. [Prerequisites](#prerequisites)
3. [Individual Component Setup](#individual-component-setup)
4. [Integration Guide](#integration-guide)
5. [Testing the Stack](#testing-the-stack)
6. [Troubleshooting](#troubleshooting)

---

## Conceptual Overview

### What is this Stack?

This stack provides a complete log aggregation, storage, querying, and visualization solution specifically designed for Spring Boot applications that produce JSON Lines formatted logs.

### Components

#### 1. **Promtail** - Log Shipper
- **Role**: Log collection agent that reads log files and forwards them to Loki
- **Why**: Acts as the bridge between your Spring Boot application logs and Loki
- **How it works**: 
  - Watches log files for changes
  - Parses JSON Lines format
  - Adds labels and metadata
  - Streams logs to Loki via HTTP

#### 2. **Loki** - Log Aggregation System
- **Role**: Horizontally scalable log aggregation and storage system
- **Why**: Designed specifically for logs (not full-text indexing like Elasticsearch), making it lightweight and cost-effective
- **How it works**:
  - Stores compressed, unindexed log data
  - Indexes only metadata (labels)
  - Provides LogQL query language (similar to PromQL)
  - Optimized for aggregation and filtering

#### 3. **Grafana** - Visualization and Querying
- **Role**: Web UI for querying, visualizing, and alerting on log data
- **Why**: Provides a powerful interface to explore logs, create dashboards, and set up alerts
- **How it works**:
  - Connects to Loki as a data source
  - Provides LogQL query builder
  - Creates dashboards and visualizations
  - Supports alerting and annotations

### Architecture Flow

```
Spring Boot App (JSON Lines logs)
        ↓
    Log File
        ↓
    Promtail (reads & parses)
        ↓ (HTTP push)
    Loki (stores & indexes labels)
        ↓ (queries via HTTP)
    Grafana (visualizes & explores)
        ↓
    User (web browser)
```

### Why This Architecture?

- **Simplicity**: Less complex than ELK stack
- **Cost-effective**: No full-text indexing = less storage
- **Container-native**: Built for cloud-native environments
- **Label-based**: Similar to Prometheus, making it familiar
- **JSON support**: Native support for JSON log parsing

---

## Prerequisites

### Required Software
- Docker (20.10+)
- Docker Compose (1.29+)
- HTTPie (optional, for testing): `pip install httpie`
- curl (alternative to HTTPie)

### System Requirements
- 4GB RAM minimum
- 10GB free disk space
- Ports available: 3000 (Grafana), 3100 (Loki), 9080 (Promtail)

---

## Individual Component Setup

This section covers how to set up and verify each component independently before integration.

### 1. Loki Setup

#### Pull the Image
```bash
docker pull grafana/loki:2.9.3
```

#### Run Loki Standalone
```bash
docker run -d \
  --name loki \
  -p 3100:3100 \
  grafana/loki:2.9.3 \
  -config.file=/etc/loki/local-config.yaml
```

#### Verify Loki

**Check if Loki is ready:**
```bash
curl http://localhost:3100/ready
```
Expected output: `ready`

**Check Loki metrics:**
```bash
curl http://localhost:3100/metrics
```

**Using HTTPie:**
```bash
http GET http://localhost:3100/ready
http GET http://localhost:3100/metrics
```

**Push a test log entry:**
```bash
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
          ["'$(date +%s)000000000'", "test log message"]
        ]
      }
    ]
  }'
```

**Query the test log:**
```bash
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={job="test"}'
```

#### Stop and Remove
```bash
docker stop loki
docker rm loki
```

---

### 2. Promtail Setup

#### Pull the Image
```bash
docker pull grafana/promtail:2.9.3
```

#### Create Test Configuration

Create a file `promtail-test-config.yaml`:
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: test
    static_configs:
      - targets:
          - localhost
        labels:
          job: test_logs
          __path__: /var/log/test/*.log
```

#### Run Promtail Standalone
```bash
docker run -d \
  --name promtail \
  -p 9080:9080 \
  -v $(pwd)/promtail-test-config.yaml:/etc/promtail/config.yml \
  -v /var/log:/var/log \
  grafana/promtail:2.9.3 \
  -config.file=/etc/promtail/config.yml
```

#### Verify Promtail

**Check Promtail metrics:**
```bash
curl http://localhost:9080/metrics
```

**Check Promtail targets:**
```bash
curl http://localhost:9080/targets
```

**Using HTTPie:**
```bash
http GET http://localhost:9080/metrics
http GET http://localhost:9080/targets
```

#### Stop and Remove
```bash
docker stop promtail
docker rm promtail
```

---

### 3. Grafana Setup

#### Pull the Image
```bash
docker pull grafana/grafana:10.2.3
```

#### Run Grafana Standalone
```bash
docker run -d \
  --name=grafana \
  -p 3000:3000 \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  -e "GF_USERS_ALLOW_SIGN_UP=false" \
  grafana/grafana:10.2.3
```

#### Verify Grafana

**Check health:**
```bash
curl http://localhost:3000/api/health
```

**Using HTTPie:**
```bash
http GET http://localhost:3000/api/health
```

**Access Web UI:**
1. Open browser: http://localhost:3000
2. Login with:
   - Username: `admin`
   - Password: `admin`
3. You'll be prompted to change the password (can skip in dev)

#### Stop and Remove
```bash
docker stop grafana
docker rm grafana
```

---

## Integration Guide

### Step 1: Create Loki Configuration

Create `loki-config.yaml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  instance_addr: 127.0.0.1
  path_prefix: /tmp/loki
  storage:
    filesystem:
      chunks_directory: /tmp/loki/chunks
      rules_directory: /tmp/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

# Parse JSON logs
analytics:
  reporting_enabled: false
```

### Step 2: Create Promtail Configuration

Create `promtail-config.yaml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: spring-boot-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: spring-boot
          app: demo-app
          __path__: /var/log/spring-boot/*.log

    # JSON Lines pipeline
    pipeline_stages:
      - json:
          expressions:
            timestamp: timestamp
            level: level
            thread: thread
            logger: logger
            message: message
            trace_id: traceId
            span_id: spanId
            application: application
      
      # Extract timestamp if present
      - timestamp:
          source: timestamp
          format: RFC3339
      
      # Add labels from JSON fields
      - labels:
          level:
          application:
          logger:
      
      # Output the message as the log line
      - output:
          source: message
```

### Step 3: Create Docker Compose File

See [`docker-compose.yml`](docker-compose.yml:1) for the complete configuration.

### Step 4: Network Configuration

The Docker Compose file creates a bridge network called `loki-network` that allows all containers to communicate using their service names as hostnames:

- `loki` is accessible at `http://loki:3100`
- `grafana` is accessible at `http://grafana:3000`
- `promtail` pushes to `http://loki:3100/loki/api/v1/push`

### Step 5: Volume Mappings

Three types of volumes are used:

1. **Configuration volumes** (bind mounts):
   - `./loki-config.yaml:/etc/loki/local-config.yaml`
   - `./promtail-config.yaml:/etc/promtail/config.yml`

2. **Data volumes** (named volumes for persistence):
   - `loki-data:/tmp/loki`
   - `grafana-data:/var/lib/grafana`

3. **Log volumes** (for log ingestion):
   - `./logs:/var/log/spring-boot`

### Step 6: Launch the Stack

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Step 7: Configure Grafana Data Source

#### Option 1: Manual Configuration (Web UI)

1. Open Grafana: http://localhost:3000
2. Login (admin/admin)
3. Navigate to: Configuration → Data Sources
4. Click "Add data source"
5. Select "Loki"
6. Configure:
   - Name: `Loki`
   - URL: `http://loki:3100`
7. Click "Save & Test"

#### Option 2: Automatic Configuration (Provisioning)

Create `grafana-datasource.yaml`:

```yaml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      maxLines: 1000
```

Add to docker-compose.yml under grafana volumes:
```yaml
- ./grafana-datasource.yaml:/etc/grafana/provisioning/datasources/loki.yaml
```

---

## Testing the Stack

### 1. Generate Sample Logs

Use the provided log generator script (see [`generate-logs.py`](generate-logs.py:1)):

```bash
python generate-logs.py
```

Or manually create a test log:
```bash
echo '{"timestamp":"'$(date -Iseconds)'","level":"INFO","thread":"main","logger":"com.example.DemoApplication","message":"Application started successfully","application":"demo-app","traceId":"abc123","spanId":"xyz789"}' >> logs/application.log
```

### 2. Verify Logs in Grafana

1. Open Grafana: http://localhost:3000
2. Go to "Explore" (compass icon)
3. Select "Loki" data source
4. Try these queries:

**View all Spring Boot logs:**
```logql
{job="spring-boot"}
```

**Filter by log level:**
```logql
{job="spring-boot", level="ERROR"}
```

**Search for specific text:**
```logql
{job="spring-boot"} |= "started"
```

**JSON filtering:**
```logql
{job="spring-boot"} | json | level="ERROR"
```

**Rate of logs:**
```logql
rate({job="spring-boot"}[5m])
```

**Count by level:**
```logql
sum by (level) (count_over_time({job="spring-boot"}[5m]))
```

### 3. Create a Dashboard

1. In Grafana, click "+" → "Dashboard"
2. Click "Add visualization"
3. Select "Loki" data source
4. Add panels for:
   - Log volume over time
   - Error rate
   - Log level distribution
   - Recent error logs

### 4. Verify Each Component

**Check Loki:**
```bash
curl http://localhost:3100/ready
curl -G http://localhost:3100/loki/api/v1/label
```

**Check Promtail:**
```bash
curl http://localhost:9080/metrics | grep promtail_sent_entries_total
```

**Check Grafana:**
```bash
curl http://localhost:3000/api/health
```

---

## Troubleshooting

### Logs Not Appearing in Grafana

1. **Check Promtail is reading logs:**
   ```bash
   docker-compose logs promtail
   curl http://localhost:9080/targets
   ```

2. **Check Loki is receiving logs:**
   ```bash
   curl -G http://localhost:3100/loki/api/v1/label/job/values
   ```

3. **Check file permissions:**
   ```bash
   ls -la ./logs/
   ```

4. **Verify log format is valid JSON Lines:**
   ```bash
   cat logs/application.log | head -1 | python -m json.tool
   ```

### Loki Not Starting

1. **Check configuration syntax:**
   ```bash
   docker run --rm -v $(pwd)/loki-config.yaml:/etc/loki/config.yaml \
     grafana/loki:2.9.3 \
     -config.file=/etc/loki/config.yaml -verify-config
   ```

2. **Check logs:**
   ```bash
   docker-compose logs loki
   ```

### Grafana Can't Connect to Loki

1. **Verify network connectivity:**
   ```bash
   docker-compose exec grafana ping loki
   ```

2. **Check Loki is accessible:**
   ```bash
   docker-compose exec grafana curl http://loki:3100/ready
   ```

### Performance Issues

1. **Increase Loki limits:**
   ```yaml
   limits_config:
     ingestion_rate_mb: 50
     ingestion_burst_size_mb: 100
   ```

2. **Increase retention:**
   ```yaml
   table_manager:
     retention_deletes_enabled: true
     retention_period: 720h
   ```

### Port Already in Use

```bash
# Find what's using the port
netstat -ano | findstr :3000  # Windows
lsof -i :3000                  # Linux/Mac

# Change ports in docker-compose.yml
ports:
  - "3001:3000"  # Use 3001 instead
```

---

## Version Compatibility Matrix

| Component | Version | Compatible With |
|-----------|---------|----------------|
| Loki | 2.9.3 | Promtail 2.9.x, Grafana 9.x-10.x |
| Promtail | 2.9.3 | Loki 2.9.x |
| Grafana | 10.2.3 | Loki 2.x |

**Recommendations:**
- Keep Loki and Promtail on the same minor version (e.g., both 2.9.x)
- Grafana can be on a different version but test compatibility
- Avoid mixing major versions (e.g., Loki 2.x with Promtail 3.x)

---

## LogQL Query Examples

### Basic Queries

```logql
# All logs from spring-boot job
{job="spring-boot"}

# Filter by label
{job="spring-boot", level="ERROR"}

# Multiple labels (AND)
{job="spring-boot", application="demo-app", level="ERROR"}
```

### Text Filtering

```logql
# Contains text
{job="spring-boot"} |= "exception"

# Doesn't contain text
{job="spring-boot"} != "health"

# Regex match
{job="spring-boot"} |~ "error|exception"

# Regex not match
{job="spring-boot"} !~ "debug|trace"
```

### JSON Parsing

```logql
# Parse JSON and filter
{job="spring-boot"} | json | level="ERROR"

# Extract and label
{job="spring-boot"} | json | logger="com.example.Service"

# Multiple conditions
{job="spring-boot"} | json | level="ERROR" | logger=~"com.example.*"
```

### Aggregations

```logql
# Count over time
count_over_time({job="spring-boot"}[5m])

# Rate of logs
rate({job="spring-boot"}[5m])

# Sum by label
sum by (level) (count_over_time({job="spring-boot"}[5m]))

# Average over time
avg_over_time({job="spring-boot"} | unwrap duration [5m])
```

---

## Best Practices

### For Spring Boot Applications

1. **Use Structured Logging:**
   ```xml
   <!-- logback-spring.xml -->
   <appender name="JSON" class="ch.qos.logback.core.FileAppender">
     <file>logs/application.log</file>
     <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
   </appender>
   ```

2. **Add Context:**
   ```java
   MDC.put("traceId", traceId);
   MDC.put("userId", userId);
   log.info("User action performed");
   ```

3. **Use Appropriate Log Levels:**
   - ERROR: System errors requiring attention
   - WARN: Potential issues
   - INFO: Important business events
   - DEBUG: Detailed diagnostic information

### For Loki Configuration

1. **Use Labels Wisely:**
   - Keep label cardinality low (< 10,000 unique combinations)
   - Use labels for dimensions you want to aggregate on
   - Put high-cardinality data in log lines, not labels

2. **Retention:**
   - Set appropriate retention periods
   - Monitor disk usage
   - Consider using object storage for long-term retention

3. **Performance:**
   - Tune `ingestion_rate_mb` based on log volume
   - Use caching for frequently accessed queries
   - Consider running Loki in microservices mode for scale

---

## Additional Resources

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Loki Guide](https://grafana.com/docs/loki/latest/getting-started/)

---

## License

This guide is provided as-is for educational purposes.
