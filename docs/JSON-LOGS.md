# Understanding JSON Log Processing in Loki

## What's Happening?

When your Spring Boot application writes JSON logs to a file, Promtail reads them and processes them through a **pipeline** before sending to Loki. This processing transforms the raw JSON into something more convenient, but it can hide the original JSON structure.

## The Pipeline in Action

Your [`promtail-config.yaml`](../config/promtail-config.yaml:1) has these stages:

### 1. JSON Parsing (Lines 32-44)
```yaml
- json:
    expressions:
      timestamp: timestamp
      level: level
      thread: thread
      logger: logger
      message: message
      # ... etc
```
- **What it does**: Extracts individual fields from the JSON into variables
- **Why it's useful**: Allows you to search and filter by specific fields

### 2. Labels (Lines 52-59)
```yaml
- labels:
    level:
    application:
```
- **What it does**: Converts certain fields into Loki labels (indexed fields)
- **Why it's useful**: Enables fast filtering like `{level="ERROR"}`
- **Why it's limited**: Too many labels = poor performance (Loki indexes every label)

### 3. Message Formatting (Lines 62-69)
```yaml
- template:
    source: output_message
    template: |
      {{ if .logger }}[{{ .logger }}] {{ end }}{{ .message }}...
- output:
    source: output_message
```
- **What it does**: Reformats the log into a human-readable string
- **Why you don't see JSON**: This **replaces** the original JSON line with the formatted text
- **What's missing**: Fields not in the template (like `thread`) are lost from the displayed message

## Two Configurations: Pick Your Approach

### Option A: Keep Original JSON (Recommended for Learning)

**Benefits:**
- See the complete, original JSON structure
- All fields always visible
- Can parse on-the-fly in Grafana with `| json`
- Nothing is lost

**Limitations:**
- Slightly harder to read at a glance
- Need to parse JSON in every query

**Config:** Use [`config/promtail-config-raw-json.yaml`](../config/promtail-config-raw-json.yaml:1) (see below)

### Option B: Pre-Parsed with Formatted Output (Current Setup)

**Benefits:**
- Cleaner, human-readable messages
- Fields already extracted for filtering
- Faster queries (no parsing needed)

**Limitations:**
- Original JSON is gone
- Fields not in template are lost (like `thread`)
- Can't see the full structure

**Config:** Current [`config/promtail-config.yaml`](../config/promtail-config.yaml:1)

## How to See the Original JSON

### Quick Fix: View in Grafana with JSON Parsing

Even with the current config, you can parse fields on-the-fly:

```logql
{job="spring-boot"} | json
```

But this won't show the original JSON if it's been replaced by the template.

### Better Fix: Preserve Original JSON

Replace the pipeline in [`promtail-config.yaml`](../config/promtail-config.yaml:1) with this simplified version:

```yaml
pipeline_stages:
  # Parse JSON to extract labels only
  - json:
      expressions:
        level: level
        application: application
        timestamp: timestamp
  
  # Set timestamp
  - timestamp:
      source: timestamp
      format: RFC3339
  
  # Add minimal labels (keep cardinality low!)
  - labels:
      level:
      application:
  
  # NO template/output - keeps original JSON line!
```

This configuration:
- ✅ Keeps the complete original JSON in Loki
- ✅ Extracts labels for fast filtering
- ✅ Preserves ALL fields including `thread`
- ✅ You can still parse fields in Grafana with `| json`

## How to Use Both Approaches

### Viewing Original JSON
```logql
# See raw JSON logs
{job="spring-boot"}

# Parse and filter specific fields
{job="spring-boot"} | json | thread="http-nio-8080-exec-1"

# See all fields from JSON
{job="spring-boot"} | json | line_format "{{.}}"
```

### Working with Parsed Fields (Current Config)
```logql
# Filter by level (from labels)
{job="spring-boot", level="ERROR"}

# Search in message (formatted text)
{job="spring-boot"} |= "exception"

# Count by level
sum by (level) (count_over_time({job="spring-boot"}[5m]))
```

## Which Should You Use?

**For Learning Loki & Grafana:**
- Use raw JSON (Option A)
- You'll understand how parsing works
- You can experiment with different LogQL queries
- Nothing is hidden

**For Production:**
- Use parsed with labels (Option B or a hybrid)
- Balance between convenience and performance
- Only label high-value, low-cardinality fields
- Format messages for readability

## Switching Configurations

### 1. Edit the Config
Update [`config/promtail-config.yaml`](../config/promtail-config.yaml:1) with your preferred pipeline

### 2. Restart Promtail
```bash
docker-compose restart promtail
```

### 3. Generate Fresh Logs
```bash
python scripts/generate-logs.py batch 50
```

### 4. Query in Grafana
```logql
{job="spring-boot"}
```

Now you'll see the difference!

## Pro Tips

### 1. Preserve JSON But Add Parsed Fields
You can have BOTH! Store the original line AND extract fields:

```yaml
pipeline_stages:
  - json:
      expressions:
        level: level
        application: application
        # Extract fields...
  
  - labels:
      level:
      application:
  
  # NO output stage = keeps original JSON!
```

### 2. View Specific JSON Fields in Grafana
```logql
# Pretty-print a specific field
{job="spring-boot"} | json | line_format "Thread: {{.thread}}, Message: {{.message}}"

# Or see all extracted fields
{job="spring-boot"} | json | line_format "{{.thread}} - {{.logger}}: {{.message}}"
```

### 3. Debug What's Being Sent
Check what Promtail is actually sending to Loki:

```bash
# View Promtail logs
docker-compose logs promtail

# Check metrics
curl http://localhost:9080/metrics | grep promtail
```

## Summary

- **Original JSON is replaced** by the `template`/`output` stages in Promtail
- **To see JSON:** Remove the template/output stages from config
- **Best of both worlds:** Keep original JSON, parse in Grafana with `| json`
- **Thread field missing?** It wasn't included in the template formatter
- **Performance:** Labels = fast filtering, but use sparingly (low cardinality only)

Now you can decide: Do you want convenience (formatted) or completeness (raw JSON)?
