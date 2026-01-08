# Spring Boot Log Management Guide

A practical guide to setting up and using Loki and Grafana for Spring Boot log management.

## Components Overview

### Promtail - Log Shipper
- Watches log files for changes
- Parses JSON Lines format
- Adds labels and metadata
- Streams logs to Loki via HTTP

### Loki - Log Aggregation System
- Stores compressed log data
- Indexes only metadata (labels)
- Provides LogQL query language
- Optimized for aggregation and filtering

### Grafana - Visualization
- Connects to Loki as a data source
- Provides LogQL query builder
- Creates dashboards and visualizations
- Supports alerting

## Quick Setup

### 1. Start the Stack

```bash
docker-compose up -d

# Wait for services to be ready
docker-compose ps
```

### 2. Generate Test Logs

```bash
# Generate 100 logs (default path: ../logs)
jbang scripts/generate-logs.java batch 100

# Generate logs to custom path
jbang scripts/generate-logs.java batch --logs-path "./logs" 100
```

### 3. View Logs in Grafana

1. Open http://localhost:3000
2. Login: `admin` / `admin`
3. Go to "Explore" (compass icon)
4. Query: `{job="spring-boot"}`

## Configuration

### Loki (`config/loki-config.yaml`)

Key settings:
- Authentication: disabled (local dev)
- Storage: filesystem
- Retention: 168h (7 days)
- Ingestion limits: 10MB/s rate, 20MB burst

### Promtail (`config/promtail-config.yaml`)

Pipeline stages:
1. **JSON parsing** - Extracts fields from JSON logs
2. **Timestamp extraction** - Uses log timestamp
3. **Labels** - Indexes level and application fields
4. **Message formatting** - Formats output for readability

### Grafana (`config/grafana-datasource.yaml`)

Auto-provisioned with Loki data source at `http://loki:3100`.

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

# Log rate per second
rate({job="spring-boot"}[1m])
```

## Troubleshooting

### Logs Not Appearing

**1. Check Promtail is reading logs:**
```bash
docker-compose logs promtail
curl http://localhost:9080/targets
```

**2. Check Loki is receiving logs:**
```bash
curl -G http://localhost:3100/loki/api/v1/label/job/values
```

**3. Check file permissions:**
```bash
ls -la ./logs/
```

**4. Verify log format is valid JSON Lines:**
```bash
cat logs/application.log | head -1 | jq .
```

### Grafana Can't Connect to Loki

```bash
# Verify network connectivity
docker-compose exec grafana ping loki

# Check Loki is accessible from Grafana
docker-compose exec grafana curl http://loki:3100/ready
```

### Performance Issues

**Increase Loki limits:**
```yaml
limits_config:
  ingestion_rate_mb: 50
  ingestion_burst_size_mb: 100
```

**Reduce Promtail batch size:**
```yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
    batchwait: 1s
    batchsize: 102400  # 100KB
```

## Best Practices

### For Spring Boot Applications

**1. Use Structured Logging (JSON Lines):**
```xml
<!-- logback-spring.xml -->
<appender name="JSON" class="ch.qos.logback.core.FileAppender">
  <file>logs/application.log</file>
  <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
</appender>
```

**2. Add Context:**
```java
MDC.put("traceId", traceId);
MDC.put("userId", userId);
log.info("User action performed");
```

**3. Use Appropriate Log Levels:**
- ERROR: System errors requiring attention
- WARN: Potential issues
- INFO: Important business events
- DEBUG: Detailed diagnostic information

### For Loki Configuration

**1. Use Labels Wisely:**
- Keep label cardinality low (< 10,000 unique combinations)
- Use labels for dimensions you want to aggregate on
- Put high-cardinality data in log lines, not labels

**2. Retention:**
- Set appropriate retention periods
- Monitor disk usage
- Consider using object storage for long-term retention

**3. Performance:**
- Tune `ingestion_rate_mb` based on log volume
- Use caching for frequently accessed queries
- Consider running Loki in microservices mode for scale

## Health Check Commands

```bash
# Loki
curl http://localhost:3100/ready

# Promtail
curl http://localhost:9080/metrics

# Grafana
curl http://localhost:3000/api/health

# View all logs
docker-compose logs -f

# Restart specific service
docker-compose restart promtail

# Complete reset
docker-compose down -v && rm -rf logs/
```

## Resources

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Grafana Explore](https://grafana.com/docs/grafana/latest/explore/)
