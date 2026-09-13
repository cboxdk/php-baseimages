---
title: "Statamic Guide"
description: "Run Statamic on the multi-service image, including working git integration over SSH"
weight: 24
---

# Statamic Guide

Statamic is a Laravel application, and the entrypoint detects it as one: you
get storage permission fixes, the scheduler, queue workers and the optimize
hooks without configuration. This guide covers the part that is
Statamic-specific and historically painful in containers: **git integration**.

## Quick start

```yaml
services:
  statamic:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1
    ports:
      - "8080:80"
    volumes:
      - ./:/var/www/html
    environment:
      - PUID=1000
      - PGID=1000
      - LARAVEL_SCHEDULER=true
```

Expected startup log:

```text
[INFO] Framework detected: laravel
[INFO] PHP-FPM listening on unix socket: /run/php/php-fpm.sock
```

## Git integration

Statamic's git automation commits (and optionally pushes) content changes
after every save. Three things have to be true inside the container, and all
three ship in the image since 1.6.2:

1. **`git` is installed** (all tiers).
2. **`openssh-client` is installed** - `git push` to an SSH remote needs
   `ssh`, and pinning GitHub's host key needs `ssh-keyscan`.
3. **git trusts the mounted repo.** git 2.35+ refuses to operate on a
   directory owned by another UID (`fatal: detected dubious ownership`),
   which is the *normal* state for a bind-mounted site. The image bakes
   `safe.directory = *` into `/etc/gitconfig`, so this never bites - in
   root, rootless and read-only-rootfs modes alike.

❌ **Wrong** (the classic failure on generic images):

```text
fatal: detected dubious ownership in repository at '/var/www/html'
ssh: not found
```

✅ **Correct** (this image): both problems are handled at build time. You
only supply the key and the remote.

### 1. Create a deploy key

```bash
ssh-keygen -t ed25519 -N "" -C "statamic deploy" -f ./deploy_key
ssh-keyscan -t ed25519 github.com > ./known_hosts
```

Add `deploy_key.pub` as a **deploy key with write access** on the repository
(GitHub: Settings → Deploy keys → Allow write access).

### 2. Wire it into the container

```yaml
services:
  statamic:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1
    volumes:
      - ./:/var/www/html
      - ./deploy_key:/run/secrets/git_key:ro
      - ./known_hosts:/etc/ssh/ssh_known_hosts:ro
    environment:
      - PUID=1000
      - PGID=1000
      - LARAVEL_QUEUE=true            # Statamic commits async via the queue
      - GIT_SSH_COMMAND=ssh -i /run/secrets/git_key -o IdentitiesOnly=yes
      - STATAMIC_GIT_ENABLED=true
      - STATAMIC_GIT_PUSH=true
      - STATAMIC_GIT_USER_NAME=Statamic Bot
      - STATAMIC_GIT_USER_EMAIL=bot@example.com
```

Notes:

- **The key must be `0400` and owned by the runtime user.** ssh refuses
  group- or world-readable private keys outright (`bad permissions ...
  This private key will be ignored`) - `0444` does NOT work, we tested. On
  Linux: `chown 33:33 deploy_key && chmod 400 deploy_key` (or set
  `PUID`/`PGID` to your host UID and keep the key `0400` under your own
  ownership - then `www-data` runs as that UID and reads it as the owner).
- `/etc/ssh/ssh_known_hosts` is the system-wide known-hosts file, so no
  per-user `~/.ssh` setup is needed for `www-data`.
- Statamic runs git through the queue when a worker is available
  (`LARAVEL_QUEUE=true`), keeping saves fast in the control panel.

### 3. Verify from inside the container

```bash
docker compose exec -u www-data statamic php please git commit
```

Expected output:

```text
Committing changes...
[main abc1234] Content saved
Changes committed.
```

And with push enabled the commit lands on the remote immediately after.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Host key verification failed` | No known_hosts for the remote | Mount the `ssh-keyscan` output at `/etc/ssh/ssh_known_hosts` |
| `Permission denied (publickey)` | Key unreadable for `www-data`, or deploy key lacks write access | Check mount ownership/mode; enable "Allow write access" on the deploy key |
| `dubious ownership` | You are on an image without the baked `safe.directory` (pre-1.6.2) | Upgrade, or `git config --system --add safe.directory '*'` in a derived image |
| Saves are slow in the control panel | Git runs synchronously | Set `LARAVEL_QUEUE=true` so commits go through the worker |
| Nothing commits | Git integration is a Statamic Pro feature | Enable Pro (`config/statamic/editions.php`); trial mode works locally |

## What the Laravel detection gives Statamic for free

- `storage/` and `bootstrap/cache/` permissions fixed at boot (PUID-aware)
- `LARAVEL_SCHEDULER=true` runs `schedule:work` (Statamic uses it for
  scheduled entries)
- `LARAVEL_QUEUE=true` runs queue workers with graceful stop contracts
  (SIGTERM + 60s, so an in-flight git commit finishes on `docker stop`)
- `LARAVEL_OPTIMIZE_ENABLED=true` caches config/routes/views at startup

For the general Laravel features, see the [Laravel Guide](laravel-guide).
