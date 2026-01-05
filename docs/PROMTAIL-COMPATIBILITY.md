# Promtail 3.5.0 Compatibility Guide

## Overview

This project uses **Promtail 3.5.0** with **Loki 2.9.2**. While Promtail is generally backward compatible, version mismatches can cause issues. This guide helps you troubleshoot and verify compatibility.

## Version Information

- **Loki**: 2.9.2
- **Promtail**: 3.5.0 (⚠️ newer than Loki)
- **Grafana**: 10.2.2

## Quick Health Check

### 1. Check Container Status
```bash
docker ps
```

Look for:
- ✅ All three containers running (loki, promtail, grafana)
- ✅ promtail shows "healthy" status
- ❌ promtail constantly restarting = compatibility issue

### 2. Check Promtail Logs
```bash
docker logs promtail
```

**Good signs:**
```
level=info msg="Starting Promtail"
level=info msg="Successfully created target" 
level=info msg="Clients configured" clients=1
```

**Warning signs:**
```
level=error msg="error sending batch"
level=error msg="failed to connect to Loki"
level=error msg="unsupported API version"
level=fatal msg="incompatible configuration"
```

### 3. Check Promtail Metrics
```bash
curl http://localhost:9080/metrics | grep promtail
```

Look for:
- `promtail_sent_entries_total` > 0 (logs being sent successfully)
- `promtail_dropped_entries_total` = 0 (no dropped logs)
- `promtail_request_duration_seconds` (successful requests to Loki)

### 4. Check Loki Health
```bash
curl http://localhost:3100/ready
```

Should return: `ready` (HTTP 200)

## Common Issues & Solutions

### Issue 1: Promtail Won't Start

**Symptoms:**
```bash
docker logs promtail
# Shows: level=fatal msg="error initializing..."
```

**Solutions:**

1. **Check config syntax compatibility**
   ```bash
   # Test promtail config
   docker run --rm -v ./config/promtail-config-raw-json.yaml:/etc/promtail/config.yml grafana/promtail:3.5.0 -config.file=/etc/promtail/config.yml -dry-run
   ```

2. **Use simpler config** - If the current config fails, try this minimal version:
   ```yaml
   # Save as config/promtail-config-minimal.yaml
   server:
     http_listen_port: 9080
     grpc_listen_port: 0
   
   positions:
     filename: /tmp/positions.yaml
   
   clients:
     - url: http://loki:3100/loki/api/v1/push
   
   scrape_configs:
     - job_name: spring-boot
       static_configs:
         - targets:
             - localhost
           labels:
             job: spring-boot
             __path__: /var/log/spring-boot/*.log
   ```
   
   Then update docker-compose.yml:
   ```yaml
   volumes:
     - ./config/promtail-config-minimal.yaml:/etc/promtail/config.yml
   ```

### Issue 2: Logs Not Appearing in Grafana

**Symptoms:**
- Promtail running
- No logs in Grafana when querying `{job="spring-boot"}`

**Debugging steps:**

1. **Verify logs exist**
   ```bash
   ls -lh logs/
   # Should show *.log files
   ```

2. **Check Promtail is reading files**
   ```bash
   docker exec promtail cat /tmp/positions.yaml
   # Should show file paths and positions
   ```

3. **Test Loki API directly**
   ```bash
   curl -G -s "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="spring-boot"}' | jq
   ```

4. **Check Promtail targets**
   ```bash
   curl http://localhost:9080/targets
   ```

### Issue 3: API Version Mismatch

**Symptoms:**
```
level=error msg="server returned HTTP status 400 Bad Request"
level=error msg="unsupported push request"
```

**Solution:**
This means Promtail 3.5.0 is using a newer API that Loki 2.9.2 doesn't support.

**Option A:** Downgrade Promtail (if possible)
- Check if your registry has `promtail:2.9.2` or similar

**Option B:** Use compatibility mode in promtail config
Add to the `clients` section:
```yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
    timeout: 30s
    # Force older API format
    headers:
      X-Scope-OrgID: "fake"
```

### Issue 4: High CPU/Memory Usage

**Symptoms:**
- Promtail using excessive resources
- Logs with: `level=warn msg="dropping batch"`

**Solutions:**

1. **Reduce batch size** (add to config/promtail-config-raw-json.yaml):
   ```yaml
   clients:
     - url: http://loki:3100/loki/api/v1/push
       batchwait: 1s
       batchsize: 102400  # 100KB (smaller than default)
   ```

2. **Limit file watching**:
   ```yaml
   scrape_configs:
     - job_name: spring-boot
       static_configs:
         - labels:
             __path__: /var/log/spring-boot/app.log  # Watch specific file only
   ```

## Version-Specific Compatibility Notes

### Promtail 3.5.0 Changes (vs 2.9.x)

**New features that should work:**
- ✅ Pipeline stages (json, timestamp, labels, template, output)
- ✅ File position tracking
- ✅ Retry logic and backoff
- ✅ Basic scrape configs

**Features to avoid (may not be compatible):**
- ❌ New pipeline stages introduced in 3.x (kafka, syslog parsing)
- ❌ Advanced regex features
- ❌ Native Kubernetes service discovery (use file-based scraping)

## Testing Compatibility

### Step 1: Clean Start
```bash
# Stop everything
docker-compose down -v

# Start with fresh state
docker-compose up -d

# Wait for startup
sleep 10
```

### Step 2: Check Health
```bash
# All should return success
docker exec loki wget --quiet --tries=1 --spider http://localhost:3100/ready && echo "✅ Loki healthy"
docker exec promtail wget --quiet --tries=1 --spider http://localhost:9080/ready && echo "✅ Promtail healthy"
docker exec grafana wget --quiet --tries=1 --spider http://localhost:3000/api/health && echo "✅ Grafana healthy"
```

### Step 3: Generate Test Logs
```bash
python scripts/generate-logs.py batch 10
```

### Step 4: Verify in Grafana
1. Open http://localhost:3000
2. Login (admin/admin)
3. Go to Explore
4. Query: `{job="spring-boot"}`
5. Should see 10 log entries

## Emergency Fallback: Use Older Promtail

If Promtail 3.5.0 is incompatible, create a custom fallback config:

```yaml
# Add to docker-compose.yml
  promtail-fallback:
    # Try to use vanilla Promtail if available in your registry
    # Replace with your actual registry path
    image: your-registry/promtail:2.9.0
    container_name: promtail-fallback
    # ... rest of promtail config ...
```

Or use filebeat/fluentd as alternative log shippers (they can also push to Loki).

## Determining if It's the Same Promtail

Your version (3.5.0) is unusual. Standard Grafana Promtail versions follow the pattern: 2.x.x or 3.0.0+

**To verify if it's genuine Grafana Promtail:**

```bash
# Check image details
docker pull grafana/promtail:3.5.0
docker inspect grafana/promtail:3.5.0 | jq '.[0].Config.Labels'
```

Look for:
- `org.opencontainers.image.vendor: "Grafana Labs"`
- `org.opencontainers.image.title: "Promtail"`

**If labels are missing or different**, it may be a customized/forked version. In that case:
1. Contact your DevOps team for documentation
2. Test extensively in your local environment first
3. Use the minimal config to maximize compatibility

## Support Checklist

Before asking for help, gather:

- [ ] `docker logs loki > loki.log`
- [ ] `docker logs promtail > promtail.log`
- [ ] `docker logs grafana > grafana.log`
- [ ] `docker ps -a` output
- [ ] `curl http://localhost:9080/metrics` output
- [ ] Your promtail config file
- [ ] Output of: `docker inspect grafana/promtail:3.5.0`

## Monitoring in Production

When deploying to work environment:

1. **Set up alerts** for promtail unhealthy status
2. **Monitor metrics**: 
   - `promtail_sent_entries_total` (should increase)
   - `promtail_dropped_entries_total` (should stay at 0)
3. **Regular health checks** in your CI/CD pipeline
4. **Backup plan**: Document alternative log shipping methods

## Resources

- Loki 2.9.2 docs: https://grafana.com/docs/loki/v2.9.x/
- Promtail configuration: https://grafana.com/docs/loki/latest/send-data/promtail/
- Check version compatibility: https://grafana.com/docs/loki/latest/setup/upgrade/

## Quick Reference Commands

```bash
# View all logs in real-time
docker-compose logs -f

# Restart just promtail
docker-compose restart promtail

# Check promtail health
curl http://localhost:9080/ready

# Test log generation
python scripts/generate-logs.py batch 5

# Query logs via API
curl -G "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="spring-boot"}' --data-urlencode 'limit=5' | jq '.data.result[].values'
```
