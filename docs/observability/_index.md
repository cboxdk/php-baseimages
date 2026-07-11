---
title: "Observability & Health"
description: "Health checks, readiness probes, metrics, structured logs, and the Cbox Init management API for Cbox containers"
weight: 40
---

# Observability & Health

Everything for knowing what your containers are doing and whether they're
healthy — in one place.

- **[Overview](overview)** — how health, readiness, metrics, and logging fit
  together in Cbox images.
- **[Health Checks](health-checks)** — the container health model, endpoints,
  and how `HEALTHCHECK` is wired.
- **[Health Checks & CI](healthchecks-ci)** — ready-to-copy Docker Compose,
  Kubernetes, and CI health-check templates.
- **[Cbox Init Integration](cbox-init-integration)** — the process manager
  inside multi-service images: metrics (`:9090`), management API (`:9180`),
  readiness (`/readyz`/`/livez`), and structured logging.

For the Grafana dashboard and Prometheus wiring, see
[`observability/`](https://github.com/cboxdk/php-baseimages/tree/main/observability)
in the repository.
