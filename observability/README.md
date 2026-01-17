# Cbox Observability

Pre-configured monitoring dashboards and configurations for Cbox Base Images.

## Grafana Dashboard

### Cbox Init Process Manager Dashboard

Import `grafana-cbox-init-dashboard.json` into Grafana for comprehensive monitoring of:

- **Process Status**: PHP-FPM, Nginx, Horizon, Queue Workers
- **Resource Usage**: Memory and CPU per process
- **Queue Workers**: Scale tracking, restarts, health
- **Scheduled Tasks**: Execution history, success/failure rates
- **Health Checks**: TCP, HTTP, and exec health status

### Quick Import

1. Open Grafana → Dashboards → Import
2. Upload `grafana-cbox-init-dashboard.json`
3. Select your Prometheus data source
4. Click Import

### Requirements

- Grafana 10.0+
- Prometheus data source
- Cbox Init metrics exposed on port 9090

## Prometheus Configuration

Add this scrape config to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'cbox-init'
    static_configs:
      - targets: ['your-app:9090']
    scrape_interval: 15s
    metrics_path: /metrics
```

### Available Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `cbox_init_process_up` | Gauge | Process running status (0/1) |
| `cbox_init_process_restarts_total` | Counter | Total process restarts |
| `cbox_init_process_cpu_seconds_total` | Counter | CPU time consumed |
| `cbox_init_process_memory_bytes` | Gauge | Memory usage in bytes |
| `cbox_init_health_check_status` | Gauge | Health check result (0/1) |
| `cbox_init_process_desired_scale` | Gauge | Desired instance count |
| `cbox_init_process_current_scale` | Gauge | Running instance count |
| `cbox_init_scheduled_task_last_run_timestamp` | Gauge | Last execution timestamp |
| `cbox_init_scheduled_task_next_run_timestamp` | Gauge | Next scheduled timestamp |
| `cbox_init_scheduled_task_last_exit_code` | Gauge | Most recent exit code |
| `cbox_init_scheduled_task_duration_seconds` | Gauge | Execution duration |
| `cbox_init_scheduled_task_total` | Counter | Total runs by status |

## Docker Compose Example

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "80:80"
      - "9090:9090"  # Cbox Init metrics
    environment:
      LARAVEL_HORIZON: "true"
      LARAVEL_QUEUE: "true"

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9091:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
```

## Alerting Rules

Example Prometheus alerting rules for Cbox Init:

```yaml
groups:
  - name: cbox-init
    rules:
      - alert: ProcessDown
        expr: cbox_init_process_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Process {{ $labels.process }} is down"
          description: "Process {{ $labels.process }} on {{ $labels.instance }} has been down for more than 1 minute."

      - alert: HighRestartRate
        expr: increase(cbox_init_process_restarts_total[5m]) > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High restart rate for {{ $labels.process }}"
          description: "Process {{ $labels.process }} has restarted more than 5 times in the last 5 minutes."

      - alert: ScheduledTaskFailed
        expr: cbox_init_scheduled_task_last_exit_code != 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Scheduled task {{ $labels.task }} failed"
          description: "Scheduled task {{ $labels.task }} has a non-zero exit code."

      - alert: HealthCheckFailing
        expr: cbox_init_health_check_status == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Health check failing for {{ $labels.process }}"
          description: "Health check {{ $labels.check_type }} for {{ $labels.process }} has been failing for 2 minutes."
```

## Support

- [Cbox Documentation](https://cbox.com/docs)
- [Cbox Init Integration Guide](../docs/cbox-init-integration.md)
- [GitHub Issues](https://github.com/cboxdk/baseimages/issues)
