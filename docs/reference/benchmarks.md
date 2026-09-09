---
title: "Benchmarks"
description: "Measured performance across the PHP container field - and why static worker defaults break when your container grows"
weight: 15
---

# Benchmarks

The design promise of these images is simple: **no assumptions about your
container**. Worker sizing is derived from the container's actual CPU and
memory limits at boot, and `CBOX_FPM_TUNE=true` keeps correcting it from
live measurements while the workload runs. This page is the measured proof,
against the field: ServerSideUp, webdevops, trafex, a DIY vanilla
php-fpm + nginx pair, Apache mod_php, and FrankenPHP (classic and worker
mode) - all on PHP 8.5, all as shipped, all on identical resources.

## The scaling result

Same field, same fixtures, same load - only the container size changes
(2 CPU / 1 GiB vs 4 CPU / 4 GiB):

| Stack | hello rps 2c/1g | hello rps 4c/4g | scaling | workers @ 4 CPU |
|---|---|---|---|---|
| **Cbox (default)** | 13,299 | 23,139 | **1.74×** | 15 (boot-profiled) |
| **Cbox + fpm-tune** | 11,700 | 21,645 | **1.85×** | 24 (live-measured) |
| **Cbox (unix socket)** | 16,494 | 27,541 | **1.67×** | 16 |
| ServerSideUp | 11,948 | 22,330 | 1.87× | 22 |
| webdevops | 14,681 | 20,300 | 1.38× | **5 (static default)** |
| trafex | 15,424 | 28,361 | 1.84× | 75 (ondemand) |
| **Vanilla fpm+nginx (DIY)** | 20,884 | 17,040 | **0.82×** | **4 (static default)** |
| Apache mod_php | 9,458 | 28,735 | 3.04× | prefork |
| FrankenPHP (worker) | 15,555 | 20,470 | 1.32× | 5 threads (static) |

Two stacks got **twice the hardware and gained nothing - or lost**. The
DIY pair that leads the small-container hello test *drops 18%* when the
container doubles, because the official image's pool default is
`pm.max_children = 5` regardless of what it runs on. webdevops ships the
same assumption. On the CPU-bound endpoint the pattern repeats: FrankenPHP
worker mode scales 0.98× (five threads, whatever the hardware).

Cbox images size the pool from the container's real limits at boot and,
with the runtime tuner on, keep adjusting from per-worker PSS measurements
- 24 workers at 4 CPU / 4 GiB, chosen by measurement, not by a constant
someone wrote years ago.

## Where the images stand (2 CPU / 1 GiB, as shipped)

- **Static files: #1** - 52,375 rps, 1.7× the DIY/ServerSideUp/webdevops
  cluster, 4.5× FrankenPHP.
- **PHP throughput: #1 among single-container images** with
  `PHP_FPM_LISTEN=unix` - 16,494 rps (+24% over TCP mode), with CPU-work
  p99 down 28%.
- **Cold start: 1.15 s** median from `docker run` to first HTTP 200 -
  ahead of ServerSideUp (1.59 s), the DIY pair (1.86 s), trafex (2.02 s)
  and webdevops (2.13 s). Only single-process architectures (Apache,
  FrankenPHP) boot faster, and only by ~0.2 s.
- **Idle memory with the tuner: 35 MiB** settled - the pool shrinks to
  what the workload needs.
- **Zero errors** across millions of requests per configuration; any
  battery with more than 1% non-2xx responses is invalidated by the
  harness rather than charted.

## A real application (Laravel 12, 2 CPU / 1 GiB)

Synthetic endpoints flatter every stack, so the field also ran a Laravel 12
API endpoint - Eloquent query, 50 rows, JSON response - with byte-identical
fixtures and OPcache verified through the web runtime (medians of 4 runs):

| Stack | rps | p99 | workers | settled memory |
|---|---|---|---|---|
| Vanilla fpm+nginx (DIY) | 553 | **219 ms** | 5 (static) | 12 MiB* |
| ServerSideUp + OPcache enabled manually | 441 | 387 ms | 20 | 92 MiB |
| FrankenPHP | 382 | 487 ms | threads | 63 MiB |
| **Cbox (default)** | 362 | 285 ms | 7 | 76 MiB |
| **Cbox (unix socket)** | 353 | 332 ms | 6 | 75 MiB |
| **Cbox + fpm-tune** | 328 | 299 ms | 11 | 150 MiB |
| ServerSideUp **as shipped** | **14** | 930 ms | 20 | 456 MiB |

\* nginx container only; the FPM container's pool is separate in the DIY pair.

Two results matter more than the ordering:

- **The single largest performance decision in PHP hosting is OPcache, not
  the image.** ServerSideUp ships with OPcache off: 14 rps as shipped
  against its own 441 with the cache enabled - a 31× penalty that is
  invisible on hello-world and catastrophic on a real framework. Cbox
  images ship OPcache and JIT enabled, and the harness verifies it through
  the web runtime because the CLI lies about it.
- **The DIY pair wins this table *because of* its low static worker count,
  not despite it** - this endpoint is CPU-bound and the optimum on 2 cores
  is ~2 workers (next section). The same static 5 is what loses 18% when
  the container doubles and collapses to ~150 rps territory on I/O-shaped
  load. A constant can only be lucky on one workload shape.

## Why there is no correct worker constant

Same container (2 CPU / 1 GiB), same Laravel app, `pm.max_children` forced
to fixed values (medians of 3 runs):

| workers | CPU-bound endpoint | I/O-bound endpoint (~75% wait) |
|---|---|---|
| 2 | **824 rps / p99 111 ms** | 151 rps / p99 695 ms |
| 4 | 701 rps / 160 ms | 312 rps / 286 ms |
| 10 | 617 rps / 206 ms | **668 rps / 191 ms** |
| 20 | 570 rps / 189 ms | 582 rps / 282 ms |
| 32 | - | 540 rps / 293 ms |

The optimum spans **2 to 10 workers on the same hardware, same
application**, purely as a function of how much of each request is spent
waiting. The rule the data validates is
`workers ≈ cores × (wait + cpu) / cpu`: a CPU-bound endpoint wants exactly
the core count, an endpoint that waits 75% of the time wants ~4-5× that.
Every static default in the field - 5, 20, whatever - is on the wrong side
of this table for at least one of the two columns. Sizing has to be
measured, per workload, over time; that is the entire premise of these
images.

The sweep also caught our own regression, in public: fpm-tune sized this
CPU-bound pool at 11 because per-request CPU sampling is structurally
blind below 50 ms request cost
([fpm-tune#14](https://github.com/cboxdk/fpm-tune/issues/14)). The fix -
an aggregate CPU shape computed from kernel tick deltas, which fast
requests cannot hide from -
is [upstream](https://github.com/cboxdk/fpm-tune/pull/17) and converges
the pool toward `cores × headroom` on exactly this workload. Benchmarks
that only report wins are marketing; this page reports the sweep that
found our bug.

## Methodology (summary)

Sequential local runs, machine otherwise idle; every container capped
identically (`--cpus`, `--memory`); `wrk -t4 -c64`, 8×15 s measured runs
per endpoint after warmup (4×10 s on the large tier), medians with 95%
t-CIs; cold start is the whole stack from `docker run` to first HTTP 200,
30 runs; OPcache status measured through the web runtime, never the CLI.
Fixtures are byte-identical across stacks. The Laravel battery is a
Laravel 12 app on SQLite with route caching; the worker sweep forces
`pm.max_children` via env on the Cbox image, all else identical. Numbers
date from 2026-09-09 on the published `8.5-bookworm-v1` images
(cbox-init 3.3.0); the unix-socket row ran the then-pre-release transport
feature on the same base.

Full harness, raw data and the complete report are produced by the
benchmark suite in this repository's tooling; rerun it yourself - the
honest caveat is that absolute numbers vary by host, while the relative
positions and the scaling behavior are the point.
