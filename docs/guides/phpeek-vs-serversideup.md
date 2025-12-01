---
title: "PHPeek vs ServerSideUp"
description: "Side-by-side comparison of PHPeek and ServerSideUp PHP base images focusing on developer experience, documentation quality, and built-in features"
weight: 60
---

# PHPeek vs ServerSideUp

Objective comparison of PHPeek base images with ServerSideUp (SSUp) images across the three areas teams ask most about: developer experience (DX), documentation, and built-in features.

## TL;DR Scores

| Category | PHPeek | ServerSideUp | Notes |
|----------|:------:|:------------:|-------|
| Developer Experience | **4.5 / 5** | 3.5 / 5 | PHPeek bundles framework-aware toggles and ready-to-run Compose stacks; SSUp expects more manual wiring |
| Documentation | **4.5 / 5** | 3.0 / 5 | PHPeek ships per-framework guides, troubleshooting matrices, and copy-paste snippets; SSUp docs are thinner and scattered |
| Features | **4.7 / 5** | 3.5 / 5 | PHPeek adds schedulers, queues, image tooling, and production hardening out of the box; SSUp focuses on hardened PHP images only |

## Developer Experience

- **PHPeek strengths**
  - Framework toggles (`LARAVEL_SCHEDULER`, `LARAVEL_QUEUE`, `LARAVEL_HORIZON`, etc.) with default processes handled by PHPeek PM (`docs/reference/environment-variables.md`).
  - Curated Compose stacks for Laravel, Symfony, WordPress, and queue workers with DB/Redis baked in (`docs/guides/laravel-guide.md`, `docs/guides/symfony-guide.md`, `docs/guides/queue-workers.md`).
  - Dev vs prod image split (`-dev` with Xdebug/MailHog) plus “Common Mistakes” callouts to unblock juniors fast.
- **ServerSideUp gaps**
  - Provides great PHP runtimes, but devs must wire scheduler cron, queue processes, Redis, and DB containers manually.
  - No built-in MailHog/Xdebug variants; requires Dockerfile layering.
- **Actionable follow-ups**
  1. Keep tightening PHPeek’s DX loops (e.g., ship `docker compose up` healthcheck templates + GitHub Actions starters).
  2. Capture more framework-specific env presets (e.g., Drupal, Magento) to widen the lead.

## Documentation Quality

- **PHPeek strengths**
  - Dedicated guide per framework + workflow, complete with quick starts, production checklists, and verification commands (`docs/guides/laravel-guide.md:139-214`, `docs/guides/production-deployment.md:198-241`).
  - Troubleshooting includes wrong/right patterns and ready-to-run commands (`docs/troubleshooting/common-issues.md:320-344`).
  - Advanced content covers topics like image processing and testing, reducing the need for external blogs.
- **ServerSideUp gaps**
  - Documentation split between repo README and disparate blog posts; lacks per-framework structure or troubleshooting matrices.
  - Minimal coverage for non-Laravel frameworks.
- **Actionable follow-ups**
  1. Publish this comparison prominently (Guides index + landing page) so evaluators see documentation depth instantly.
  2. Add short video walkthroughs or GIFs to key guides to push the DX story even further.

## Feature Comparison

- **PHPeek strengths**
  - Built-in process manager enabling cron, queues, Horizon, Reverb, Octane, etc., via env toggles.
  - First-class image tooling: GD, Imagick, libvips, Browsershot with working PHP examples (`docs/guides/image-processing.md`).
  - Production deployment checklist covering secrets, OPcache tuning, health checks, monitoring, and zero-downtime strategies (`docs/guides/production-deployment.md`).
  - Prebuilt stacks for Redis, MySQL/Postgres, MailHog, and workers.
- **ServerSideUp gaps**
  - Ships excellent base runtimes but leaves process orchestration, schedulers, and ancillary services to the user.
  - Fewer turnkey recipes for monitoring/logging or zero-downtime rollouts.
- **Actionable follow-ups**
  1. Surface observability add-ons (Prometheus exporters, log forwarding) to reinforce PHPeek’s production story.
  2. Offer Kubernetes/Helm blueprints to capture teams scaling beyond Compose.

## Conclusion

PHPeek already leads ServerSideUp in DX, docs, and built-in features thanks to framework-specific guidance, strong troubleshooting content, and opinionated defaults. To widen the gap, double down on automated health checks, CI templates, and platform-specific examples (Kubernetes, ECS). This comparison page should be linked from marketing/README so prospects quickly understand why PHPeek is the higher-level choice.
