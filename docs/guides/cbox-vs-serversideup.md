---
title: "Cbox vs ServerSideUp"
description: "Honest comparison to help you choose the right PHP Docker images for your project"
weight: 60
---

# Cbox vs ServerSideUp

Both Cbox and ServerSideUp provide production-ready PHP Docker images. This guide helps you choose based on your specific needs.

## Quick Comparison

| Aspect | Cbox | ServerSideUp |
|--------|--------|--------------|
| Process Manager | Cbox PM (Go) | S6 Overlay |
| Community | Newer project | Established, active community |
| PHP Versions | 8.2, 8.3, 8.4, 8.5 | 8.1, 8.2, 8.3, 8.4, 8.5 |
| Image Tiers | Slim, Standard, Full | Base, Full |
| Framework Focus | Laravel, Symfony, WordPress | Laravel-focused |

## When to Choose ServerSideUp

ServerSideUp is an excellent choice when:

- **You want established community support** - ServerSideUp has a larger user base and more community resources
- **You're comfortable with S6 Overlay** - Their S6-based process management is battle-tested
- **You primarily use Laravel** - Their Laravel integration is mature and well-documented
- **You prefer a proven solution** - They've been around longer with more production deployments

## When to Choose Cbox

Cbox may be better when:

- **You want built-in Prometheus metrics** - Cbox PM includes observability features
- **You need Symfony or WordPress** - We have framework-specific optimizations
- **You prefer a single-binary approach** - Cbox PM is a single Go binary
- **You want three image tiers** - Slim, Standard, and Full for different use cases

## Process Management Comparison

### ServerSideUp (S6 Overlay)
- Mature, widely-used init system
- More configuration options
- Different learning path from traditional Docker
- Well-documented in the S6 ecosystem

### Cbox (Cbox PM)
- Lightweight Go binary
- Built-in Prometheus metrics
- Simpler configuration
- Newer, less battle-tested

## Honest Assessment

**ServerSideUp advantages:**
- More mature project with proven track record
- Larger community for support
- More third-party tutorials and resources
- S6 Overlay is a known quantity in the Docker ecosystem

**Cbox advantages:**
- Built-in Prometheus metrics and health checks
- Single Go binary for process management
- Multi-framework support (Laravel, Symfony, WordPress)
- Three image tiers (Slim, Standard, Full)

## Recommendation

**Start with ServerSideUp if:**
- This is your first time with PHP Docker images
- You need community support and resources
- You're building a Laravel application

**Consider Cbox if:**
- You want built-in observability (Prometheus metrics)
- You're using Symfony or WordPress
- You prefer a single-binary process manager
- You need flexible image tiers (Slim/Standard/Full)

Both are good choices. Pick based on your specific needs, not marketing claims.
