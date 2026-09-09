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

With only `/tmp` and `/run` writable, the container boots on the **baked
default config**: the entrypoint logs which runtime files it could not write
and continues, and any `NGINX_*`/`PHP_FPM_*` env overrides that would need
those files fail loud instead of being silently ignored.

For the full env-driven config surface under `readOnlyRootFilesystem: true`,
give the entrypoint its render targets as emptyDirs:

```yaml
securityContext:
  readOnlyRootFilesystem: true
volumes:
  - { name: tmp,       emptyDir: {} }
  - { name: run,       emptyDir: {} }
  - { name: nginxconf, emptyDir: {} }   # rendered nginx server config
  - { name: fpmd,      emptyDir: {} }   # pm-mode + env-override drop-ins
  - { name: phpconf,   emptyDir: {} }   # php ini env-overrides
  - { name: nginxtmp,  emptyDir: {} }   # nginx body/proxy temp buffers
volumeMounts:
  - { name: tmp,       mountPath: /tmp }
  - { name: run,       mountPath: /run }
  - { name: nginxconf, mountPath: /etc/nginx/conf.d }
  - { name: fpmd,      mountPath: /usr/local/etc/php-fpm.d }
  - { name: phpconf,   mountPath: /usr/local/etc/php/conf.d }
  - { name: nginxtmp,  mountPath: /var/lib/nginx }
```

Note that emptyDirs mounted over `/etc/nginx/conf.d`, `/usr/local/etc/php-fpm.d`
and `/usr/local/etc/php/conf.d` start EMPTY - the entrypoint re-renders the
nginx config, but the FPM pool files and php ini overlays baked into the image
are hidden by the mount. The practical production shape is therefore usually
the minimal one above (`/tmp` + `/run` + `/var/lib/nginx`, baked defaults,
overrides via a ConfigMap mounted as files) rather than emptyDirs over the
config directories. Anything unwritable is reported with the exact path at
boot rather than surfacing as a 500 later.

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
