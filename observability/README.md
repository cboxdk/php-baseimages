# Cbox Observability

Pre-configured monitoring dashboards and configurations for Cbox PHP Base Images.

## Grafana Dashboard

### Cbox Init Process Manager Dashboard

Import `grafana-cbox-init-dashboard.json` into Grafana for comprehensive monitoring of:

- **Process Status**: PHP-FPM, Nginx, Horizon, Queue Workers
- **Resource Usage**: Memory and CPU per process (needs resource metrics, see below)
- **Queue Workers**: Scale tracking and restarts
- **Health Checks**: TCP, HTTP, and exec health status

Scheduled tasks are not on the dashboard: cbox-init exports no Prometheus
metrics for them. Use its schedule API
(`GET /api/v1/processes/{name}/schedule` and `/schedule/history`).

### Quick Import

1. Open Grafana → Dashboards → Import
2. Upload `grafana-cbox-init-dashboard.json`
3. Select your Prometheus data source
4. Click Import

### Requirements

- Grafana 10.0+
- Prometheus data source
- Cbox Init metrics exposed on port 9090
- For the memory and CPU panels: resource metrics enabled
  (`CBOX_INIT_GLOBAL_RESOURCE_METRICS_ENABLED=true`; off by default)
- Prometheus' default `honor_labels: false`. The dashboard's Instance
  variable then selects the scrape target (the container); cbox-init's own
  per-instance ID is available as `exported_instance`

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

The process name is under `name` on the process and health check metrics
and under `process` on the resource metrics. Selectors must use the right
key: `cbox_init_process_up{process="php-fpm"}` matches nothing.

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cbox_init_process_up` | Gauge | `name`, `instance` | Process running status (0/1) |
| `cbox_init_process_restarts_total` | Counter | `name`, `reason` | Total process restarts |
| `cbox_init_process_start_time_seconds` | Gauge | `name`, `instance` | Instance start timestamp |
| `cbox_init_process_last_exit_code` | Gauge | `name`, `instance` | Last exit code |
| `cbox_init_process_desired_scale` | Gauge | `name` | Desired instance count |
| `cbox_init_process_current_scale` | Gauge | `name` | Running instance count |
| `cbox_init_health_check_status` | Gauge | `name`, `type` | Health check result (0/1) |
| `cbox_init_process_cpu_percent` | Gauge | `process`, `instance` | CPU, percent of one core (resource metrics) |
| `cbox_init_process_memory_bytes` | Gauge | `process`, `instance`, `type` | Memory in bytes, `type` = `rss`/`vms` (resource metrics) |

`instance` above is cbox-init's instance ID (`php-fpm-0`). Under the default
`honor_labels: false`, Prometheus stores it as `exported_instance` and uses
`instance` for the scrape target. Full list with every label: the cbox-init
[metrics reference](https://github.com/cboxdk/init/blob/main/docs/observability/metrics.md).

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
          summary: "Process {{ $labels.name }} is down"
          description: "Process {{ $labels.name }} ({{ $labels.exported_instance }}) on {{ $labels.instance }} has been down for more than 1 minute."

      - alert: HighRestartRate
        expr: increase(cbox_init_process_restarts_total[5m]) > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High restart rate for {{ $labels.name }}"
          description: "Process {{ $labels.name }} has restarted more than 5 times in the last 5 minutes."

      - alert: HealthCheckFailing
        expr: cbox_init_health_check_status == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Health check failing for {{ $labels.name }}"
          description: "Health check {{ $labels.type }} for {{ $labels.name }} has been failing for 2 minutes."
```

## Support

- [Cbox Documentation](https://cbox.dk/docs)
- [Cbox Init Integration Guide](../docs/observability/cbox-init-integration.md)
- [GitHub Issues](https://github.com/cboxdk/php-baseimages/issues)
