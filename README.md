# Spring Boot Log Management with Loki and Grafana

A complete, production-ready local log management solution for Spring Boot applications using Loki and Grafana.

## Overview

This project provides a fully configured Docker Compose stack for collecting, storing, querying, and visualizing Spring Boot logs in JSON Lines format using:

- **Loki** (2.9.2) - Lightweight log aggregation system
- **Promtail** (3.5.0) - Log collection agent
- **Grafana** (10.2.2) - Visualization and querying interface

## Quick Start

```bash
# Start all services
./up.sh

# Generate test logs
jbang scripts/generate-logs.java batch 100

# View logs
# Open http://localhost:3000 (admin/admin)
# Go to Explore → Query: {job="spring-boot"}
```

## Project Structure

```
.
├── README.md                    # This file
├── GUIDE.md                     # Setup and usage guide
├── docker-compose.yml           # Complete stack configuration
├── up.sh / down.sh / reset.sh   # Management scripts
├── config/                      # Configuration files
│   ├── loki-config.yaml
│   ├── promtail-config.yaml
│   └── grafana-datasource.yaml
├── scripts/                     # Utility scripts
│   └── generate-logs.java       # Spring Boot log generator (jbang)
└── logs/                        # Log directory (created automatically)
```

## Services

| Service  | Port | Description              |
|----------|------|--------------------------|
| Grafana  | 3000 | Web UI for visualization |
| Loki     | 3100 | Log aggregation API      |
| Promtail | 9080 | Log shipper metrics      |

## Usage

### Generate Logs

```bash
# Generate fixed number (uses default ../logs path)
jbang scripts/generate-logs.java batch 500

# Generate with custom log path
jbang scripts/generate-logs.java batch --logs-path "/path/to/logs" 500

# Generate continuously
jbang scripts/generate-logs.java continuous

# Generate in bursts
jbang scripts/generate-logs.java burst 10 100
```

### Query Logs (in Grafana)

```logql
# View all Spring Boot logs
{job="spring-boot"}

# Filter by log level
{job="spring-boot", level="ERROR"}

# Search in messages
{job="spring-boot"} |= "exception"

# Count by log level
sum by (level) (count_over_time({job="spring-boot"}[5m]))
```

## Managing the Stack

```bash
# Start
./up.sh

# Stop (preserves data)
./down.sh

# Complete reset (removes all data and logs)
./reset.sh
```

## Troubleshooting

### Logs not appearing?

```bash
# Check containers are running
docker-compose ps

# Verify Loki is ready
curl http://localhost:3100/ready

# Check Promtail is sending logs
curl http://localhost:9080/metrics | grep promtail_sent_entries_total

# View container logs
docker-compose logs promtail
docker-compose logs loki
```

See [`GUIDE.md`](GUIDE.md) for detailed troubleshooting steps.

## Configuration

### Environment Variables

All configuration variables are prefixed with `LOCALOBS_` to avoid collisions when exported alongside other environment variables:

```bash
# Component versions
LOCALOBS_LOKI_IMAGE=grafana/loki
LOCALOBS_LOKI_TAG=2.9.2
LOCALOBS_PROMTAIL_IMAGE=grafana/promtail
LOCALOBS_PROMTAIL_TAG=3.5.0
LOCALOBS_GRAFANA_IMAGE=grafana/grafana
LOCALOBS_GRAFANA_TAG=10.2.2

# Log directory
LOCALOBS_LOG_FOLDER=./logs

# Timestamp parsing (using Go reference time format)
# Reference: Mon Jan 2 15:04:05 MST 2006
LOCALOBS_TIMESTAMP_SOURCE=ts
LOCALOBS_TIMESTAMP_FORMAT=2006-01-02T15:04:05.999-0700
```

### Timestamp Format Configuration

Promtail now uses environment variables for timestamp parsing, configured with `-config.expand-env=true`. This allows you to:

- **Customize timestamp parsing** without editing YAML files
- **Use Go's reference time format** (Jan 2, 2006 15:04:05) for precise timestamp parsing
- **Control the JSON field** containing timestamps via `LOCALOBS_TIMESTAMP_SOURCE`
- **Match any timestamp format** by adjusting `LOCALOBS_TIMESTAMP_FORMAT`

**Example:** For timestamp `2026-01-07T22:16:19.999-0500`, the format is `2006-01-02T15:04:05.999-0700`

## For Production

⚠️ This setup is for local development. For production:

- Enable authentication in Loki
- Use TLS/HTTPS for all services
- Configure proper retention policies
- Use secrets management
- Implement network policies

## Documentation

- **[`GUIDE.md`](GUIDE.md)** - Comprehensive setup and usage guide
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Language Guide](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)

---

**Happy Log Hunting! 🔍**
