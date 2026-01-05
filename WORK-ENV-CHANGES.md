# Work Environment Adaptation Changes

## Summary

This project has been adapted to work with the specific versions available in your work Docker registry:

- **Loki**: 2.9.2 (was 2.9.3)
- **Promtail**: 3.5.0 (was 2.9.3)
- **Grafana**: 10.2.2 (was 10.2.3)

## ⚠️ Important Note: Promtail Version

The most significant change is **Promtail 3.5.0**, which is **newer than Loki 2.9.2**. This is an unusual configuration but generally backward compatible. However, we've added extensive error handling and fallback options in case of compatibility issues.

## Changes Made

### 1. [`docker-compose.yml`](docker-compose.yml)

**Version Updates:**
- Line 10: Loki image: `grafana/loki:2.9.2` (was 2.9.3)
- Line 60: Promtail image: `grafana/promtail:3.5.0` (was 2.9.3)
- Line 111: Grafana image: `grafana/grafana:10.2.2` (was 10.2.3)

**Promtail Error Handling (lines 102-115):**
- Changed restart policy from `unless-stopped` to `on-failure:3`
  - This prevents endless restart loops if Promtail is incompatible
  - After 3 failed attempts, the container will stop
  - You'll get clear feedback that something is wrong
  
- Added comprehensive health check:
  ```yaml
  healthcheck:
    test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9080/ready"]
    interval: 15s
    timeout: 5s
    retries: 5
    start_period: 30s
  ```
  - Monitors Promtail's `/ready` endpoint
  - Gives 30 seconds grace period on startup
  - Marks container as unhealthy if checks fail
  - Helps identify issues quickly with `docker ps`

### 2. [`docs/PROMTAIL-COMPATIBILITY.md`](docs/PROMTAIL-COMPATIBILITY.md) (NEW)

**Comprehensive troubleshooting guide including:**

- Quick health check procedures
- Common issues and solutions specific to version mismatch
- How to verify if your Promtail 3.5.0 is genuine Grafana product
- Emergency fallback options
- Testing compatibility steps
- Monitoring recommendations for production
- Quick reference commands

**Key sections:**
- **Issue 1**: Promtail won't start
- **Issue 2**: Logs not appearing in Grafana
- **Issue 3**: API version mismatch (most critical for version differences)
- **Issue 4**: High CPU/Memory usage

### 3. [`config/promtail-config-minimal.yaml`](config/promtail-config-minimal.yaml) (NEW)

**Emergency fallback configuration:**

- Stripped-down Promtail config with no advanced features
- Removes JSON parsing, field extraction, templates
- Only basic file tailing and forwarding to Loki
- Maximizes compatibility across versions
- Falls back to query-time JSON parsing in LogQL

**Use if:**
- Promtail 3.5.0 won't start with the current config
- You see API version mismatch errors
- Container keeps restarting

**To switch to this config:**
```yaml
# In docker-compose.yml, change:
volumes:
  - ./config/promtail-config-minimal.yaml:/etc/promtail/config.yml
```

### 4. [`scripts/verify-compatibility.sh`](scripts/verify-compatibility.sh) (NEW)

**Automated verification script for Linux/Mac:**

Performs 10 comprehensive checks:
1. Docker availability
2. Container status
3. Loki health
4. Promtail health
5. Promtail error logs
6. Log sending metrics
7. File target verification
8. Promtail version check
9. Loki query test
10. Container restart count

**Usage:**
```bash
bash scripts/verify-compatibility.sh
```

### 5. [`scripts/verify-compatibility.bat`](scripts/verify-compatibility.bat) (NEW)

**Windows-compatible verification script:**

Same checks as the bash version, adapted for Windows command prompt.

**Usage:**
```batch
scripts\verify-compatibility.bat
```

### 6. [`README.md`](README.md)

**Updated sections:**

- **Line 5-16**: Added prominent warning about work environment versions
- **Line 78-81**: Added PROMTAIL-COMPATIBILITY.md to documentation structure
- **Line 113-123**: Added section about compatibility guide
- **Line 219-236**: Enhanced troubleshooting with Promtail-specific steps
- **Line 403-406**: Updated status indicators to mention Promtail health check

## How to Use in Your Work Environment

### 1. Initial Setup

```bash
# Clone or copy the project
cd local-obs-sandbox

# Create logs directory
mkdir logs

# Start the stack
docker-compose up -d

# Wait for initialization (30 seconds)
timeout /t 30  # Windows
# sleep 30     # Linux/Mac

# Run compatibility check
scripts\verify-compatibility.bat  # Windows
# bash scripts/verify-compatibility.sh  # Linux/Mac
```

### 2. If Promtail Shows as Unhealthy

```bash
# Check logs for errors
docker logs promtail

# Look for these error patterns:
# - "error sending batch"
# - "unsupported API version"
# - "incompatible configuration"

# If found, see docs/PROMTAIL-COMPATIBILITY.md for solutions
```

### 3. If Promtail Keeps Restarting

```bash
# Check restart count
docker inspect promtail | find "RestartCount"  # Windows
# docker inspect promtail | grep RestartCount  # Linux/Mac

# If > 3 restarts, switch to minimal config:
# 1. Edit docker-compose.yml, change promtail volume to:
#    - ./config/promtail-config-minimal.yaml:/etc/promtail/config.yml
# 2. Restart: docker-compose restart promtail
```

### 4. Test Log Flow

```bash
# Generate test logs
python scripts/generate-logs.py batch 10

# Wait 10 seconds
timeout /t 10  # Windows
# sleep 10     # Linux/Mac

# Check in Grafana
# 1. Open http://localhost:3000
# 2. Login: admin / admin
# 3. Go to Explore
# 4. Query: {job="spring-boot"}
```

## Verifying Promtail Product

Your Promtail version (3.5.0) is unusual. To verify it's genuine Grafana Promtail:

```bash
# Inspect image labels
docker inspect grafana/promtail:3.5.0

# Look for:
"org.opencontainers.image.vendor": "Grafana Labs"
"org.opencontainers.image.title": "Promtail"
```

**If labels are different or missing:**
- It may be a custom/forked version
- Contact your DevOps team for documentation
- Use the minimal config for maximum compatibility
- Monitor closely in development before deploying to production

## Risk Mitigation

### Development Environment Testing

Before deploying to your work environment's production:

1. ✅ Test locally with these exact versions
2. ✅ Run verify-compatibility script
3. ✅ Generate significant load (1000+ logs)
4. ✅ Monitor for 24 hours
5. ✅ Check Promtail metrics regularly
6. ✅ Verify no restart loops
7. ✅ Test query performance in Grafana

### Production Deployment Checklist

- [ ] Document the Promtail version discrepancy in your deployment notes
- [ ] Set up monitoring for `promtail_sent_entries_total`
- [ ] Set up alerts for `promtail_dropped_entries_total` > 0
- [ ] Configure health check alerts for Promtail unhealthy status
- [ ] Have rollback plan ready (switch to minimal config)
- [ ] Test in staging environment first
- [ ] Document alternative log shipping methods as backup

### Monitoring Metrics

**Critical metrics to watch:**

```bash
# Promtail metrics
curl http://localhost:9080/metrics | grep promtail_sent_entries_total
curl http://localhost:9080/metrics | grep promtail_dropped_entries_total

# These should show:
# - promtail_sent_entries_total: steadily increasing
# - promtail_dropped_entries_total: staying at 0
```

## When to Contact DevOps

Contact your DevOps team if:

- [ ] Promtail restarts more than 3 times in 1 hour
- [ ] `promtail_dropped_entries_total` increases
- [ ] Logs appear in files but not in Grafana after 5 minutes
- [ ] Promtail logs show API version errors
- [ ] CPU/memory usage exceeds 500MB RAM or 50% CPU

## Alternative Solutions

If Promtail 3.5.0 proves incompatible:

### Option 1: Request Older Promtail
Ask DevOps for `promtail:2.9.0` or `promtail:2.9.2` to match Loki version.

### Option 2: Alternative Log Shippers
- **Fluent Bit**: Lighter weight, supports Loki output
- **Filebeat**: Mature, can push to Loki via plugin
- **Vector**: Modern, high-performance log router

### Option 3: Direct Application Integration
Configure Spring Boot to push logs directly to Loki via Logback appender.

## Files You Can Safely Modify

**Safe to customize for your work environment:**
- `config/promtail-config-raw-json.yaml` - Adjust log paths, labels
- `config/promtail-config-minimal.yaml` - Minimal config
- `config/loki-config.yaml` - Retention, limits
- `config/grafana-datasource.yaml` - Grafana settings
- `docker-compose.yml` - Ports, volumes, resource limits

**Do NOT modify unless necessary:**
- Health check configurations (may break early warning system)
- Restart policies (carefully tuned for compatibility issues)

## Support Resources

**Included in this project:**
- [`docs/PROMTAIL-COMPATIBILITY.md`](docs/PROMTAIL-COMPATIBILITY.md) - Detailed troubleshooting
- [`docs/GUIDE.md`](docs/GUIDE.md) - Complete usage guide
- [`docs/VERIFICATION.md`](docs/VERIFICATION.md) - Testing procedures
- [`scripts/verify-compatibility.sh`](scripts/verify-compatibility.sh) - Automated checks
- [`scripts/verify-compatibility.bat`](scripts/verify-compatibility.bat) - Windows checks

**External resources:**
- Loki 2.9.x docs: https://grafana.com/docs/loki/v2.9.x/
- Promtail config reference: https://grafana.com/docs/loki/latest/send-data/promtail/
- Version compatibility matrix: https://grafana.com/docs/loki/latest/setup/upgrade/

## Quick Command Reference

```bash
# Start everything
docker-compose up -d

# Check status
docker-compose ps

# Run compatibility check
scripts\verify-compatibility.bat  # Windows
bash scripts/verify-compatibility.sh  # Linux/Mac

# View logs
docker logs promtail
docker logs loki
docker logs grafana

# Generate test logs
python scripts/generate-logs.py batch 50

# Check Promtail health
curl http://localhost:9080/ready

# Check metrics
curl http://localhost:9080/metrics

# Query Loki directly
curl -G "http://localhost:3100/loki/api/v1/query" --data-urlencode "query={job=\"spring-boot\"}" --data-urlencode "limit=5"

# Restart just Promtail
docker-compose restart promtail

# Stop everything
docker-compose down

# Full reset (removes all data)
docker-compose down -v
rmdir /s logs # Windows
# rm -rf logs/ # Linux/Mac
```

## Summary of Protection Measures

We've added multiple layers of protection:

1. **Restart limiting** (`on-failure:3`) - Prevents endless loops
2. **Health checks** - Early warning system
3. **Comprehensive logging** - Easy troubleshooting
4. **Minimal fallback config** - Emergency compatibility mode
5. **Verification scripts** - Automated compatibility testing
6. **Detailed documentation** - Step-by-step troubleshooting
7. **Clear error indicators** - Via docker ps status

These measures ensure that if Promtail 3.5.0 has compatibility issues with Loki 2.9.2, you'll know immediately and have clear paths to resolution.

## Final Recommendations

1. **Test locally first** with these exact versions before deploying to work
2. **Use the verification script** after every deployment
3. **Monitor Promtail health** for the first 24 hours in work environment
4. **Keep the minimal config ready** as a quick fallback
5. **Document any issues** you encounter with Promtail 3.5.0 for your team

Good luck with the deployment! The project is now ready for your work environment. 🚀
