# Logging and Monitoring Your Application

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

## Why Logging Matters

Effective logging is crucial for:

- Troubleshooting problems
- Understanding user behavior
- Monitoring application performance
- Detecting security issues
- Analyzing usage patterns

Jac Cloud includes a comprehensive logging system that automatically tracks requests and responses, making your development experience smoother.

## Quick Start: Check Your Logs

By default, Jac Cloud logs everything to the `/tmp/jac_cloud_logs/` directory. To check your logs:

```bash
# View the latest log entries
tail -f /tmp/jac_cloud_logs/jac-cloud.log

# Search for errors
grep "ERROR" /tmp/jac_cloud_logs/jac-cloud.log
```

All logs are in JSON format, making them easy to parse and analyze.

## Setting Up Visualization with Elastic Stack

For a better logging experience, connect Jac Cloud to Elastic Stack (Elasticsearch + Kibana) in three easy steps:

### Step 1: Install Filebeat

[Download and install Filebeat](https://www.elastic.co/downloads/beats/filebeat) on your server.

### Step 2: Create Configuration File

Create a file named `filebeat.yml` with this content:

```yml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /tmp/jac_cloud_logs/*-jac-cloud-*.log
    - /tmp/jac_cloud_logs/jac-cloud.log
  json:
    keys_under_root: true
    overwrite_keys: true
    add_error_key: true
    expand_keys: true

output.elasticsearch:
  hosts: ["localhost:9200"]  # Replace with your Elastic URL
  protocol: https
  api_key: "id:api_key"      # Replace with your API key
  index: "jac-cloud-logs"

setup.template.name: "filebeat"
setup.template.pattern: "filebeat-*"
```

### Step 3: Run Filebeat

```bash
filebeat -e -c filebeat.yml
```

For more detailed documentation:

- [Getting Started](https://www.elastic.co/guide/en/cloud/current/ec-getting-started-search-use-cases-python-logs.html)
- [Configure filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/configuring-howto-filebeat.html)

Now you can view your logs in Kibana with powerful filtering, visualization, and alerting capabilities!

!!! warning "Port Configuration"
    If your Elastic instance is behind a load balancer with a URL that doesn't include a port, add either `:80` or `:443` to the hosts config:
    ```
hosts: ["https://my_elastic_instance.me.com:443"]
    ```

## Customizing Your Logging

Adjust logging behavior by setting these environment variables:

| **Setting** | **Environment Variable** | **Description** | **Default** |
|-------------|--------------------------|-----------------|-------------|
| Logger Name | `LOGGER_NAME` | Name for your logger | `app` |
| Log Level | `LOGGER_LEVEL` | Level of detail (debug, info, warning, error) | `debug` |
| File Path | `LOGGER_FILE_PATH` | Where logs are stored | `/tmp/jac_cloud_logs/jac-cloud.log` |
| Rotation | `LOGGER_ROLLOVER_INTERVAL` | How often to create new log files (M=minute, H=hour, D=day, W=week) | `D` (daily) |
| Backup Count | `LOGGER_MAX_BACKUP` | Number of old logs to keep (-1 = unlimited) | `-1` |
| File Size | `LOGGER_ROLLOVER_MAX_FILE_SIZE` | Maximum log file size in bytes | `10000000` (10MB) |
| UTC Time | `LOGGER_USE_UTC` | Whether to use UTC time | `false` |

### Example: Production Settings

For a production environment, you might want to:

1. Use `info` level to reduce log size
2. Keep logs for 30 days
3. Use UTC time for consistency

```bash
export LOGGER_LEVEL=info
export LOGGER_MAX_BACKUP=30
export LOGGER_USE_UTC=true
```

## Understanding Log Structure

Jac Cloud logs contain these key components:

```json
{
  "timestamp": "2024-04-10T14:25:36.789Z",
  "level": "INFO",
  "message": "Request processed successfully",
  "request": {
    "method": "POST",
    "path": "/walker/create_user",
    "headers": {"authorization": "Bearer ***", "content-type": "application/json"},
    "body": {"username": "example_user", "email": "user@example.com"}
  },
  "response": {
    "status_code": 200,
    "body": {"status": 200, "reports": ["User created successfully"]}
  },
  "duration": 125,
  "client_ip": "192.168.1.1"
}
```

This format makes it easy to filter and search for specific information.

## Common Log Analysis Tasks

### Finding Errors

```bash
grep '"level":"ERROR"' /tmp/jac_cloud_logs/jac-cloud.log
```

### Tracking Slow Requests

```bash
grep -v '"level":"DEBUG"' /tmp/jac_cloud_logs/jac-cloud.log |
  jq 'select(.duration > 1000) | {path: .request.path, duration: .duration, time: .timestamp}'
```

### Monitoring User Activity

```bash
grep '/walker/login' /tmp/jac_cloud_logs/jac-cloud.log |
  jq '.request.body.username'
```

## Logging Best Practices

### 1. **Use appropriate log levels**:

- `debug`: Detailed information for debugging
- `info`: Confirmation that things are working
- `warning`: Something unexpected but not critical
- `error`: Something failed but the application continues
- `critical`: Application cannot continue

### 2. **Be careful with sensitive data**:

- Passwords, tokens, and personal information should never be logged
- Jac Cloud automatically masks Authorization headers

### 3. **Establish log retention policies**:

- Configure `LOGGER_MAX_BACKUP` based on your needs
- Consider compliance requirements (GDPR, HIPAA, etc.)

### 4. **Set up alerts**:

- Configure alerts in Kibana for error spikes
- Monitor for unusual patterns or security issues

## Troubleshooting Common Issues

### Missing Logs

If logs aren't appearing:

1. Check directory permissions:

   ```bash
   sudo mkdir -p /tmp/jac_cloud_logs
   sudo chmod 777 /tmp/jac_cloud_logs
   ```

2. Verify the logger configuration:

   ```bash
   echo $LOGGER_FILE_PATH
   ```

### Filebeat Connection Issues

If Filebeat isn't sending logs to Elasticsearch:

1. Check connection:

   ```bash
   curl -k https://your-elastic-instance:9200
   ```

2. Verify API key:

   ```bash
   filebeat test output
   ```

### High Disk Usage

If logs are consuming too much space:

1. Adjust rotation settings:

   ```bash
   export LOGGER_ROLLOVER_INTERVAL=D
   export LOGGER_MAX_BACKUP=7
   ```

2. Manually clean old logs:

   ```bash
   find /tmp/jac_cloud_logs -name "*.log.*" -type f -mtime +7 -delete
   ```

## Next Steps

- Learn about [WebSocket Communication](websocket.md) for real-time features
- Explore [Webhook Integration](webhook.md) for third-party service integration
- Set up [Environment Variables](env_vars.md) for application configuration
