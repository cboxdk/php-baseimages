# PHPeek Observability

Pre-configured monitoring dashboards and configurations for PHPeek Base Images.

## Grafana Dashboard

### PHPeek PM Process Manager Dashboard

Import `grafana-phpeek-pm-dashboard.json` into Grafana for comprehensive monitoring of:

- **Process Status**: PHP-FPM, Nginx, Horizon, Queue Workers
- **Resource Usage**: Memory and CPU per process
- **Queue Workers**: Scale tracking, restarts, health
- **Scheduled Tasks**: Execution history, success/failure rates
- **Health Checks**: TCP, HTTP, and exec health status

### Quick Import

1. Open Grafana → Dashboards → Import
2. Upload `grafana-phpeek-pm-dashboard.json`
3. Select your Prometheus data source
4. Click Import

### Requirements

- Grafana 10.0+
- Prometheus data source
- PHPeek PM metrics exposed on port 9090

## Prometheus Configuration

Add this scrape config to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'phpeek-pm'
    static_configs:
      - targets: ['your-app:9090']
    scrape_interval: 15s
    metrics_path: /metrics
```

### Available Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `phpeek_pm_process_up` | Gauge | Process running status (0/1) |
| `phpeek_pm_process_restarts_total` | Counter | Total process restarts |
| `phpeek_pm_process_cpu_seconds_total` | Counter | CPU time consumed |
| `phpeek_pm_process_memory_bytes` | Gauge | Memory usage in bytes |
| `phpeek_pm_health_check_status` | Gauge | Health check result (0/1) |
| `phpeek_pm_process_desired_scale` | Gauge | Desired instance count |
| `phpeek_pm_process_current_scale` | Gauge | Running instance count |
| `phpeek_pm_scheduled_task_last_run_timestamp` | Gauge | Last execution timestamp |
| `phpeek_pm_scheduled_task_next_run_timestamp` | Gauge | Next scheduled timestamp |
| `phpeek_pm_scheduled_task_last_exit_code` | Gauge | Most recent exit code |
| `phpeek_pm_scheduled_task_duration_seconds` | Gauge | Execution duration |
| `phpeek_pm_scheduled_task_total` | Counter | Total runs by status |

## Docker Compose Example

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    ports:
      - "80:80"
      - "9090:9090"  # PHPeek PM metrics
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

Example Prometheus alerting rules for PHPeek PM:

```yaml
groups:
  - name: phpeek-pm
    rules:
      - alert: ProcessDown
        expr: phpeek_pm_process_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Process {{ $labels.process }} is down"
          description: "Process {{ $labels.process }} on {{ $labels.instance }} has been down for more than 1 minute."

      - alert: HighRestartRate
        expr: increase(phpeek_pm_process_restarts_total[5m]) > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High restart rate for {{ $labels.process }}"
          description: "Process {{ $labels.process }} has restarted more than 5 times in the last 5 minutes."

      - alert: ScheduledTaskFailed
        expr: phpeek_pm_scheduled_task_last_exit_code != 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Scheduled task {{ $labels.task }} failed"
          description: "Scheduled task {{ $labels.task }} has a non-zero exit code."

      - alert: HealthCheckFailing
        expr: phpeek_pm_health_check_status == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Health check failing for {{ $labels.process }}"
          description: "Health check {{ $labels.check_type }} for {{ $labels.process }} has been failing for 2 minutes."
```

## Support

- [PHPeek Documentation](https://phpeek.com/docs)
- [PHPeek PM Integration Guide](../docs/phpeek-pm-integration.md)
- [GitHub Issues](https://github.com/phpeek/baseimages/issues)
