---
title: "Cbox vs ServerSideUp"
description: "An honest technical comparison of Cbox and ServerSideUp PHP Docker images"
weight: 8
---

# Cbox vs ServerSideUp

[serversideup/php](https://serversideup.net/open-source/docker-php/) is an
excellent, mature project — if you evaluate it and it fits, use it with
confidence. This page describes where the two projects genuinely differ, so
you can pick based on what you actually need. Both are production-ready,
both rebuild weekly with security patches, and both are maintained by teams
that run them in production.

## The short version

**Choose ServerSideUp when you want** a battle-tested, widely adopted PHP
image with a large community, Alpine and Debian bases, Apache and FrankenPHP
variants, and years of ecosystem content behind it.

**Choose Cbox when you want** a runtime control plane inside the container:
supervised multi-process orchestration with dependency ordering, live
capacity management for PHP-FPM, supervisor-owned readiness, metrics, and a
release contract that separates behavior pinning from security patching.

## At a Glance

| | Cbox | ServerSideUp |
|---|---|---|
| Process manager | Cbox Init (single Go binary: DAG dependencies, health-check-driven restarts, readiness, management API/CLI/TUI, Prometheus metrics) | S6 Overlay (proven, widely deployed init system) |
| PHP-FPM sizing | Boot-time calculation from cgroup limits **+ runtime autotuning** (live per-worker PSS measurement, graceful pool resizing) | Static configuration via env vars |
| Health checks | Built-in, drive supervised restarts and readiness | Built-in (native health checks) |
| Variants | FPM, CLI, FPM+Nginx, standalone Nginx | FPM, CLI, FPM+Nginx, FPM+Apache, FrankenPHP |
| OS bases | Debian 12 | Debian, Alpine |
| PHP versions | 8.2–8.5 | 8.1–8.5 |
| Image tiers | 4 (Slim / Standard / Chromium / Dev), all with rootless variants | Base / Full per variant |
| Framework startup automation | Laravel, Symfony, WordPress auto-detected (permissions, scheduler, queues, Horizon, Reverb) | Laravel-focused (opt-in automations) |
| Version pinning | Rolling, **release-channel (`-v1`: behavior pinned, security patches keep flowing)**, and immutable digests | Rolling (weekly rebuilds) and immutable version pins |
| Observability | Prometheus metrics, structured JSON logs, OpenTelemetry-aware supervisor, `fpm_tune_*` capacity metrics | Standard container logging |
| Community & maturity | Newer, smaller community | Large community, years of production use, extensive guides |

## Where ServerSideUp is ahead

Be honest about this list before choosing Cbox:

- **Maturity and ecosystem.** More users, more tutorials, more Stack Overflow
  answers, more third-party content. That matters when onboarding a team.
- **Alpine.** Cbox is Debian-only by design (glibc compatibility); if you
  need musl-based images, ServerSideUp has them.
- **Apache and FrankenPHP variants.** Cbox deliberately concentrates on
  PHP-FPM + Nginx (see below) and does not offer either.
- **PHP 8.1.** Cbox starts at 8.2.

## Where Cbox is ahead

- **Runtime capacity management.** ServerSideUp (like every other image) sets
  `pm.max_children` statically. Cbox seeds it from the container's actual
  cgroup memory/CPU limits at boot, then — optionally — measures live
  per-worker memory (PSS, which doesn't double-count shared OPcache) and
  resizes the pool at runtime via an atomic drop-in and graceful reload.
  No dropped connections, master PID unchanged. See
  [Runtime PHP-FPM tuning](../reference/environment-variables#runtime-php-fpm-tuning-fpm-tune-cbox-init-31).
- **A control plane, not just an init.** Cbox Init supervises processes as a
  dependency graph (queues wait for FPM, warmup hooks gate health checks),
  owns container readiness (`/readyz`, `/livez`, readiness file), exposes a
  management API/CLI/TUI for live scaling and reloads, and exports Prometheus
  metrics for all of it.
- **Behavior-pinned, security-patched tags.** The `-v1` release channel means
  "keep my runtime contract, keep patching the OS underneath" — a middle
  ground between rolling tags and immutable pins that age. See
  [Tagging Strategy](../reference/tagging-strategy).
- **Broader framework automation.** Symfony and WordPress get the same
  startup automation as Laravel.
- **A Chromium tier.** Browsershot/Dusk/PDF workloads without building a
  custom image.

## On PHP-FPM vs FrankenPHP

Cbox intentionally does not chase FrankenPHP. The classic PHP-FPM + Nginx
architecture still runs most of the PHP world, and Cbox's position is that
it deserves to be *operated properly*: supervised, measured, right-sized,
and reloaded gracefully. If you want FrankenPHP, ServerSideUp has a good
story there today.

## Sources

Comparison last verified 2026-09-05 against the
[ServerSideUp docs](https://serversideup.net/open-source/docker-php/docs).
If anything here is out of date, please open an issue — we intend this page
to stay honest.
