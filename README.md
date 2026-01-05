# Spring Boot Log Management with Loki and Grafana

A complete, production-ready local log management solution for Spring Boot applications using Loki and Grafana.

## ⚠️ Work Environment Version

This project is configured for specific versions available in enterprise registries:

- **Loki**: 2.9.2
- **Promtail**: 3.5.0 (newer than Loki - see compatibility notes)
- **Grafana**: 10.2.2

**Important**: If you encounter issues with Promtail 3.5.0, refer to [`docs/PROMTAIL-COMPATIBILITY.md`](docs/PROMTAIL-COMPATIBILITY.md) for troubleshooting and fallback options.

## 🎯 Overview

This project provides a fully configured Docker Compose stack for collecting, storing, querying, and visualizing Spring
Boot logs in JSON Lines format using:

- **Loki** - Lightweight log aggregation system
- **Promtail** - Log collection agent
- **Grafana** - Visualization and querying interface

## 📋 Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 1.29+
- Python 3.7+ (for log generator)

### Simple Way (Recommended)

```bash
./up.sh
```

### Manual Way

```bash
# Create logs directory
mkdir logs

# Start all services
docker-compose up -d

# Generate test logs
python scripts/generate-logs.py batch 50

# Check status
docker-compose ps
```

### 2. Generate Test Logs

```bash
# Generate 100 sample logs
python scripts/generate-logs.py batch 100

# Or generate continuously
python scripts/generate-logs.py continuous
```

### 3. View Logs in Grafana

1. Open http://localhost:3000
2. Login: `admin` / `admin`
3. Navigate to "Explore" (compass icon)
4. Query: `{job="spring-boot"}`

## 📁 Project Structure

```
.
├── README.md                    # This file
├── docker-compose.yml           # Complete stack configuration
├── .gitignore                   # Git ignore patterns
├── up.sh                        # Start stack script
├── down.sh                      # Stop stack script
├── reset.sh                     # Reset stack script
├── config/                      # Configuration files
│   ├── loki-config.yaml         # Loki configuration
│   ├── promtail-config.yaml     # Promtail configuration
│   └── grafana-datasource.yaml  # Grafana data source provisioning
├── scripts/                     # Utility scripts
│   └── generate-logs.py         # Spring Boot log generator
├── docs/                        # Documentation
│   ├── GUIDE.md                 # Comprehensive documentation
│   ├── VERIFICATION.md          # Testing and verification guide
│   ├── PROMTAIL-COMPATIBILITY.md # Version compatibility troubleshooting
│   └── spec.md                  # Project specification
└── logs/                        # Log directory (created automatically)
    └── application.log          # Spring Boot logs
```

## 📚 Documentation

### [GUIDE.md](docs/GUIDE.md)

Comprehensive guide covering:

- Conceptual overview of each component
- Individual component setup and verification
- Integration guide with step-by-step instructions
- LogQL query examples
- Best practices

### [VERIFICATION.md](docs/VERIFICATION.md)

Testing and troubleshooting guide with:

- Detailed verification steps
- Troubleshooting common issues
- Performance testing
- Health check scripts

### [JSON-LOGS.md](docs/JSON-LOGS.md)

Understanding JSON log processing:

- Why you don't see raw JSON in Grafana (and how Promtail transforms it)
- How to preserve original JSON while still getting parsing benefits
- Two configuration approaches (raw vs. formatted)
- How to query and work with JSON fields in LogQL
- Switching between configurations

### [PROMTAIL-COMPATIBILITY.md](docs/PROMTAIL-COMPATIBILITY.md)

**⚠️ Important for Work Environment:** Version compatibility guide:

- Compatibility notes for Promtail 3.5.0 with Loki 2.9.2
- Health check procedures and diagnostics
- Common issues and solutions
- How to verify your Promtail version is genuine Grafana
- Emergency fallback options if versions are incompatible
- Quick reference commands for troubleshooting

## 🔧 Configuration

### Services

| Service  | Port | Description              |
|----------|------|--------------------------|
| Grafana  | 3000 | Web UI for visualization |
| Loki     | 3100 | Log aggregation API      |
| Promtail | 9080 | Log shipper metrics      |

### Default Credentials

- **Grafana**: `admin` / `admin`

### Volumes

- `loki-data` - Loki log storage
- `grafana-data` - Grafana dashboards and settings
- `promtail-positions` - Promtail file positions
- `./logs` - Spring Boot log files

## 🚀 Usage

### Generate Logs

**Batch mode** (generate fixed number):

```bash
python scripts/generate-logs.py batch 500
```

**Continuous mode** (generate continuously):

```bash
python scripts/generate-logs.py continuous
```

**Burst mode** (generate in bursts):

```bash
python scripts/generate-logs.py burst 10 100  # 10 bursts of 100 logs
```

### Query Logs

#### Basic Queries

View all Spring Boot logs:

```logql
{job="spring-boot"}
```

Filter by log level:

```logql
{job="spring-boot", level="ERROR"}
```

Search in messages:

```logql
{job="spring-boot"} |= "exception"
```

#### Advanced Queries

Parse JSON and filter:

```logql
{job="spring-boot"} | json | level="ERROR" | logger=~".*Controller"
```

Count by log level:

```logql
sum by (level) (count_over_time({job="spring-boot"}[5m]))
```

Log rate per second:

```logql
rate({job="spring-boot"}[1m])
```

## 🐛 Troubleshooting

### Logs not appearing?

1. Check containers are running:
   ```bash
   docker-compose ps
   ```

2. Verify Loki is ready:
   ```bash
   curl http://localhost:3100/ready
   ```

3. Check Promtail is sending logs:
   ```bash
   curl http://localhost:9080/metrics | grep promtail_sent_entries_total
   ```

4. Check Promtail health:
   ```bash
   curl http://localhost:9080/ready
   ```

5. View container logs:
   ```bash
   docker-compose logs promtail
   docker-compose logs loki
   ```

### Promtail version issues?

If Promtail 3.5.0 is not starting or showing compatibility errors:

1. Check Promtail logs for errors:
   ```bash
   docker logs promtail
   ```

2. See detailed troubleshooting in [PROMTAIL-COMPATIBILITY.md](docs/PROMTAIL-COMPATIBILITY.md)

3. Test with minimal config if issues persist

See [VERIFICATION.md](docs/VERIFICATION.md) for complete troubleshooting steps.

## 📊 Sample Dashboards

After verification, you can create dashboards in Grafana for:

- Log volume over time
- Error rate trends
- Log level distribution
- Top error messages
- Application health monitoring

## 🔄 Managing the Stack

### Quick Scripts

**Start the stack:**
```bash
./up.sh
```

**Stop the stack:**
```bash
./down.sh
```

**Complete reset (removes all data and logs):**
```bash
./reset.sh
```

### Manual Commands

**Start services:**
```bash
docker-compose up -d
```

**View logs:**
```bash
docker-compose logs -f
```

**Stop services:**
```bash
docker-compose down
```

**Restart a specific service:**
```bash
docker-compose restart promtail
```

**Clean up everything (including data):**
```bash
docker-compose down -v
rm -rf logs/
```

## 📦 What's Included

### Configuration Files

- **[`config/loki-config.yaml`](config/loki-config.yaml)** - Optimized Loki configuration for local development
- **[`config/promtail-config.yaml`](config/promtail-config.yaml)** - Promtail with JSON Lines parsing pipeline
- **[`config/grafana-datasource.yaml`](config/grafana-datasource.yaml)** - Auto-provisioned Loki data source
- **[`docker-compose.yml`](docker-compose.yml)** - Complete stack with health checks

### Management Scripts

- **[`up.sh`](up.sh:1)** - Start the complete stack with verification
- **[`down.sh`](down.sh:1)** - Stop all services (preserves data)
- **[`reset.sh`](reset.sh:1)** - Complete reset and fresh start

### Utility Scripts

- **[`scripts/generate-logs.py`](scripts/generate-logs.py:1)** - Flexible Spring Boot log generator with multiple modes

## 🎓 Learning Objectives

This project helps you learn:

1. **Loki Architecture** - How Loki stores and indexes logs
2. **Log Shipping** - How Promtail collects and forwards logs
3. **LogQL** - Loki's query language for filtering and aggregating logs
4. **Grafana Integration** - Connecting and visualizing log data
5. **JSON Parsing** - Extracting structured data from JSON logs
6. **Docker Compose** - Orchestrating multi-container applications

## 🔒 Security Notes

⚠️ **This setup is for local development only!**

For production use:

- Enable authentication in Loki
- Use TLS/HTTPS for all services
- Set strong passwords
- Configure proper retention policies
- Use secrets management
- Implement network policies

## 🌟 Key Features

✅ Complete Docker Compose stack with health checks  
✅ Auto-provisioned Grafana data source  
✅ JSON Lines parsing with field extraction  
✅ Label-based log indexing  
✅ Trace and span ID support  
✅ Sample log generator with realistic data  
✅ Comprehensive documentation and examples  
✅ Troubleshooting guides and health checks

## 🔧 Customization

### For Your Spring Boot App

1. Update `promtail-config.yaml` with your log path:
   ```yaml
   __path__: /path/to/your/logs/*.log
   ```

2. Adjust JSON field mappings to match your log format:
   ```yaml
   - json:
       expressions:
         timestamp: '@timestamp'  # Your timestamp field
         level: logLevel           # Your level field
         # ... other fields
   ```

3. Mount your log directory in `docker-compose.yml`:
   ```yaml
   volumes:
     - /path/to/your/logs:/var/log/spring-boot:ro
   ```

## 📖 Additional Resources

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Language Guide](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Grafana Explore](https://grafana.com/docs/grafana/latest/explore/)

## 🤝 Contributing

This is a learning project. Feel free to:

- Extend the log generator with more patterns
- Add sample Grafana dashboards
- Improve the documentation
- Add more query examples

## 📄 License

This project is provided as-is for educational purposes.

---

## 🚦 Status Indicators

### Service Health

Check all services are healthy:

```bash
docker-compose ps
```

Expected output:

```
NAME       STATUS
grafana    Up (healthy)
loki       Up (healthy)
promtail   Up (healthy)
```

**Note**: Promtail 3.5.0 includes health checks. If it shows "unhealthy", check [`docs/PROMTAIL-COMPATIBILITY.md`](docs/PROMTAIL-COMPATIBILITY.md).

### Quick Health Check

```bash
# Loki
curl http://localhost:3100/ready

# Promtail
curl http://localhost:9080/metrics

# Grafana
curl http://localhost:3000/api/health
```

---

**Happy Log Hunting! 🔍**
