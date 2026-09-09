---
title: "Restricted Runtimes"
description: "Running on Cloud Run, GKE Autopilot and other sandboxed or read-only container platforms"
weight: 60
---

# Restricted Runtimes

Cloud Run, GKE Autopilot/COS, and hardened Kubernetes policies constrain
containers in ways a plain `docker run` never shows: gVisor syscall filtering,
CPU throttled to request-time only, read-only root filesystems, arbitrary UIDs.
This page is the known-good configuration.

## Cloud Run

```yaml
# Recommended env for php-fpm-nginx on Cloud Run
PHP_FPM_LISTEN: tcp                 # keep the FPM hop on loopback TCP
NGINX_FASTCGI_KEEP_CONN: "on"       # pooled connections ride out CPU throttling
LARAVEL_MIGRATE_ENABLED: "false"    # run migrations as a Cloud Run job, not at boot
```

Why these matter:

- **CPU is throttled to ~zero outside requests** on the default (non-always-on
  CPU) tier. Cold starts that fork processes suffer; the 100 ms fast-start
  probing in cbox-init keeps readiness quick, and pooled FastCGI connections
  (`NGINX_FASTCGI_KEEP_CONN=on`) avoid re-handshaking the FPM hop under
  throttling. Other stacks' supervisors are a known casualty here; cbox-init's
  readiness gate means the instance only receives traffic when FPM actually
  accepts connections.
- **Boot-time migrations** race when several instances start at once and burn
  throttled CPU; use a Cloud Run *job* for `php artisan migrate` instead.

## Read-only root filesystem (Kubernetes)

The images run with `readOnlyRootFilesystem: true` when the writable paths are
tmpfs mounts:

```yaml
securityContext:
  readOnlyRootFilesystem: true
volumes:
  - name: tmp
    emptyDir: {}
  - name: run
    emptyDir: {}
volumeMounts:
  - { name: tmp, mountPath: /tmp }
  - { name: run, mountPath: /run }
```

The entrypoint renders runtime config under paths that are writable in this
layout; anything it cannot write is reported with the exact path at boot
rather than surfacing as a 500 later.

## Arbitrary UIDs (OpenShift, PSP/PSS restricted)

Use the rootless image variants - they are built for a non-root runtime user.
When a bind mount is not writable by the runtime UID, the entrypoint's
preflight names the offending path, its owner, and the UID it needed
(`CBOX_PREFLIGHT_STRICT=true` turns that warning into a boot failure).
The images never rely on setuid helpers (no gosu/su-exec), so there is no
"failed switching to root" class of restart failure.

## Readiness on all of the above

Probe cbox-init's readiness file, not an HTTP path:

```yaml
readinessProbe:
  exec:
    command: ["test", "-f", "/tmp/cbox-ready"]
```

It flips only when every supervised process is healthy, which is the signal
sandboxed platforms actually need.
