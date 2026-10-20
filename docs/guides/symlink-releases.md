---
title: "Zero-Downtime Symlink Releases"
description: "Deploy Laravel and Statamic with releases/ and a current symlink on a single server, without dropping a request"
weight: 9
---

# Zero-Downtime Symlink Releases

The most common single-server layout for Laravel and Statamic: every deploy
unpacks into its own `releases/<id>` directory, shared state lives outside the
releases, and one atomic symlink swap makes a release live. It is what Envoyer,
Forge and Deployer do, and it works on this image — but it crosses several
things the image decides for you, and each one is silent when it goes wrong.

This page is the whole sequence, with the traps called out where you meet them.

**Use it when** one long-lived container serves the site and you want instant
rollback. **Don't** when you deploy a new image per release — that is
[baked mode](statamic-guide#baked-mode-production-kubernetes-immutable-deploys),
and it needs none of this.

## Layout

```text
/app
├── releases/
│   ├── 20261018-1142/        ← previous release (rollback target)
│   └── 20261020-0931/        ← new release
├── shared/
│   ├── storage/              ← Laravel storage, survives every deploy
│   └── .env
└── current -> releases/20261020-0931
```

Each release gets the shared state symlinked in, so `storage/` is the same
directory for every release and `.env` is deployed once:

```bash
RELEASE=/app/releases/20261020-0931
rm -rf "$RELEASE/storage"
ln -sfn /app/shared/storage "$RELEASE/storage"
ln -sfn /app/shared/.env    "$RELEASE/.env"
```

## Container configuration

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1
    ports:
      - "80:80"
    volumes:
      - /app:/app
    environment:
      - PUID=1000
      - PGID=1000
      # Point everything at the symlink, not at a release
      - WORKDIR=/app/current
      - NGINX_WEBROOT=/app/current/public
      # Production opcache: compile once, never stat the filesystem again
      - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
      - LARAVEL_QUEUE=true
      - LARAVEL_SCHEDULER=true
```

`WORKDIR` is the one that matters. It moves framework detection, the permission
fixes, the Laravel log tail **and** the working directory of every Cbox Init app
process — the queue workers, the scheduler, Horizon, Reverb. Set it and the
whole container follows the symlink.

> Before image 1.10 the app processes had `/var/www/html` hardcoded and
> crash-looped with `Could not open input file: artisan`
> ([#35](https://github.com/cboxdk/php-baseimages/issues/35)), and ran as root
> while php-fpm ran as your app user
> ([#34](https://github.com/cboxdk/php-baseimages/issues/34)). On an older
> image, set `CBOX_INIT_PROCESS_<NAME>_WORKING_DIR` and
> `CBOX_INIT_PROCESS_<NAME>_USER` per process as a workaround.

### What the image already handles

The nginx template passes `$realpath_root` — not `$document_root` — as
`SCRIPT_FILENAME` and `DOCUMENT_ROOT`, so every request carries the release's
*real* path. That is what makes a swap take effect immediately: with
`$document_root`, PHP resolves every include through the symlink, the opcache
key never changes, and with `opcache.validate_timestamps=0` the previous
release keeps being served until FPM is reloaded.

Nothing to configure — it is the default. `NGINX_USE_REALPATH_ROOT=false`
restores the old behaviour if you need it.

## The deploy

```bash
#!/usr/bin/env bash
set -euo pipefail

RELEASE_ID="$(date +%Y%m%d-%H%M%S)"
RELEASE="/app/releases/$RELEASE_ID"
CONTAINER=app

# 1. Build the release on disk
git clone --depth 1 git@github.com:you/site.git "$RELEASE"
rm -rf "$RELEASE/storage"
ln -sfn /app/shared/storage "$RELEASE/storage"
ln -sfn /app/shared/.env    "$RELEASE/.env"

# 2. Build it INSIDE the container, as the app user (see the trap below)
docker exec -u www-data -w "$RELEASE" "$CONTAINER" \
    composer install --no-dev --optimize-autoloader --no-interaction
docker exec -u www-data -w "$RELEASE" "$CONTAINER" \
    php artisan optimize          # config + routes + views, into THIS release

# 3. Migrate (still the old release serving traffic)
docker exec -u www-data -w "$RELEASE" "$CONTAINER" \
    php artisan migrate --force --no-interaction

# 4. Swap, atomically
docker exec "$CONTAINER" sh -c \
    "ln -sfn releases/$RELEASE_ID /app/current.new && mv -Tf /app/current.new /app/current"

# 5. Workers pick up the new release
docker exec -u www-data -w /app/current "$CONTAINER" php artisan queue:restart

# 6. Flush nginx's open_file_cache (static files only — see the trap below)
docker exec "$CONTAINER" nginx -s reload

# 7. Keep the last 5 releases
ls -1dt /app/releases/* | tail -n +6 | xargs -r rm -rf
```

Expected: the next request after step 4 is served by the new release, with no
FPM reload and no cache flush.

### Rollback

```bash
docker exec app sh -c \
    "ln -sfn releases/20261018-1142 /app/current.new && mv -Tf /app/current.new /app/current"
docker exec -u www-data -w /app/current app php artisan queue:restart
```

The previous release is still built and still has its own compiled caches, so a
rollback is the same atomic swap in reverse.

## The traps

### `docker exec` runs as root

Every step of the deploy that writes into the release — composer, `artisan
optimize`, `stache:warm`, view compilation into shared storage — leaves
root-owned files if you run it as root, and the php-fpm workers cannot write
them afterwards. The symptom arrives later, as a 500 from the framework on a
cache write, in a release that deployed cleanly.

❌ **Wrong:**

```bash
docker exec app php artisan optimize
```

✅ **Correct:**

```bash
docker exec -u www-data app php artisan optimize
```

To repair a tree that already has root-owned files:

```bash
docker exec app chown -R www-data:www-data /app/shared/storage /app/current/bootstrap/cache
```

### Why the atomic swap needs two commands

`ln -sfn` on an existing symlink unlinks and re-creates it, so there is a window
where `current` does not exist and nginx serves a 404. Create the new symlink
under a temporary name and `mv -Tf` it into place — that is a single `rename(2)`
and a request either sees the old release or the new one:

```bash
ln -sfn releases/$RELEASE_ID /app/current.new && mv -Tf /app/current.new /app/current
```

`mv -T` is GNU coreutils, which is what the container has. Run the swap inside
the container (as above) and it behaves the same on a macOS host.

### `PHP_FPM_MEMORY_LIMIT` and `PHP_FPM_REQUEST_TERMINATE_TIMEOUT` beat your php.ini

These two are **pool admin values** (`php_admin_value[memory_limit]` and
`request_terminate_timeout`), and `php_admin_value` cannot be overridden by
anything the application sets — including a `php.ini` you mounted.

Mount `memory_limit = 999M` and `max_execution_time = 777`, and a request still
reports the pool's defaults:

```bash
docker exec -u www-data app php -r 'echo ini_get("memory_limit"), " ", ini_get("max_execution_time");'
```

```text
256M 60
```

Raise the pool values instead:

```yaml
environment:
  - PHP_FPM_MEMORY_LIMIT=512M
  - PHP_FPM_REQUEST_TERMINATE_TIMEOUT=120s
```

(The CLI SAPI has no pool, so queue workers and `artisan` commands *do* see a
mounted `php.ini`. That asymmetry is why this one is hard to spot: the same
code works from the worker and dies under a web request.)

### nginx's `open_file_cache` can outlive the swap by 30s

`$realpath_root` fixes the PHP side. nginx's own file cache is keyed by the
*requested* path, so after a swap it can keep serving **static** files —
including a static page cache under `public/` — from the previous release for up
to `NGINX_OPEN_FILE_CACHE_VALID` (30s by default).

A reload is enough, because nginx's new workers start with an empty cache:

```bash
docker exec app nginx -s reload
```

If you cannot reload on every deploy, turn the cache off or shorten it:

```yaml
environment:
  - NGINX_OPEN_FILE_CACHE=off
  # or
  - NGINX_OPEN_FILE_CACHE_VALID=1s
```

### If you do need to reload PHP-FPM

You should not have to — that is the point of `$realpath_root` — but a php.ini
or pool change needs one. The image leaves `pid` unset in `php-fpm.conf`, so
there is no pid file; find the master and send it `USR2`:

```bash
docker exec app sh -c "kill -USR2 \$(pgrep -o -f '^php-fpm: master process')"
```

`USR2` re-execs the master and keeps the listening socket, so nothing is
dropped. Measured on this image under 8 concurrent clients, three reloads:

| | requests | non-200 |
|---|---|---|
| `kill -USR2 <master>` | 5,624 | **0** |
| `cbox-init restart php-fpm` | 4,232 | 37 × 502 |

`cbox-init restart` stops the process and starts it again — graceful for
in-flight requests, but there is a window with no FPM behind nginx. Use it when
you want a clean restart, not in a deploy that must not drop a request.

### Laravel caches belong to a release, not to shared storage

`artisan optimize` writes `bootstrap/cache/{config,routes,events}.php`, which
must be **inside the release** — that is what makes a rollback instant and
correct. Only `storage/` is shared. If you symlink `bootstrap/cache` into shared
storage, a rollback serves the new release's cached config from the old code.

Compiled views (`storage/framework/views`) do live in shared storage, which is
fine: they are keyed by a hash of the template.

## Statamic specifics

### Never share the Stache between releases

The Stache is Statamic's index of your content tree, and it is a *cache* —
which means it lands wherever your cache driver points. Share it between
releases and a release serves the other one's index. Statamic's own
[zero-downtime tip](https://statamic.dev/tips/zero-downtime-deployments) gives
the fix, and it is a config change in the app, not an environment variable:

**File cache** — give the Stache its own store inside the release, so it is
born empty with the release:

```php
// config/cache.php
'stache' => [
    'driver' => 'file',
    'path' => base_path('stache'),
    'lock_path' => base_path('stache'),
],
```

```php
// config/statamic/stache.php
'cache_store' => 'stache',
```

**Redis cache** — key it on the release directory instead:

```php
// config/database.php, under redis
'stache' => [
    // ...the usual connection settings...
    'prefix' => basename(base_path()).'_stache_',
],
```

Either way the point is the same: the cache namespace changes when the release
does. This matters more on this image than on a bare server, because
`storage/` is shared by design — so the default file cache *is* shared unless
you move it.

### Warm the Stache before the swap

```bash
docker exec -u www-data -w "$RELEASE" app php please stache:warm
docker exec -u www-data -w "$RELEASE" app php please search:update --all
```

Or let Cbox Init warm it before health checks pass, which is the shape you want
when the container restarts on its own rather than on a deploy:

```yaml
environment:
  - CBOX_INIT_HOOK_PRE_START_0_COMMAND=php,please,stache:warm
  - CBOX_INIT_HOOK_PRE_START_0_ALLOW_FAILURE=true
```

### Static caching

With full static caching, the `.html` files live under the release's `public/`,
so a new release starts with an empty page cache. Warm it after the swap:

```bash
docker exec -u www-data -w /app/current app php please static:warm
```

And let nginx serve those files before PHP boots:

```yaml
environment:
  - STATAMIC_STATIC_CACHING=full
  - STATAMIC_STATIC_IGNORE_QUERY_STRINGS=true   # match your Statamic config
```

See [Statamic Static Caching](../reference/environment-variables#statamic-static-caching)
for the full option list. Pair it with the `open_file_cache` note above — a
static page cache is exactly the kind of file that goes stale across a swap.

### The Control Panel needs `public/vendor/`

The CP loads its JavaScript and CSS from `public/vendor/statamic/cp/...`, which
`composer install` publishes into the release. The image serves that directory
and denies PHP under it; older images denied the whole directory, so every CP
asset 404'd and the panel never rendered —
[#37](https://github.com/cboxdk/php-baseimages/issues/37).

Worth asserting in the deploy, because a 404 here looks like a broken CP rather
than a missing file:

```bash
docker exec app test -d /app/current/public/vendor/statamic/cp || \
    { echo "CP assets missing from the release"; exit 1; }
```

## Verifying your own setup

Swap releases under constant load and count what the clients saw. Six swaps,
eight concurrent clients, `opcache.validate_timestamps=0`, no FPM reload:

```text
swap 1: serving r2 immediately
swap 2: serving r3 immediately
...
requests: 5698   non-200: 0
```

On an image before this was fixed, the same rehearsal reports every swap still
serving `r1` and no queue workers running at all — which is the pair of bugs
([#35](https://github.com/cboxdk/php-baseimages/issues/35),
[#38](https://github.com/cboxdk/php-baseimages/issues/38)) this layout used to
hit. If your own run shows that, check the image version first.

## Checklist

- [ ] `WORKDIR=/app/current` and `NGINX_WEBROOT=/app/current/public`
- [ ] `storage/` and `.env` symlinked from `shared/`, `bootstrap/cache` **not**
- [ ] Every build step run with `docker exec -u www-data`
- [ ] Swap is `ln -sfn` + `mv -Tf`, never `ln -sfn` alone
- [ ] `php artisan queue:restart` after the swap
- [ ] `nginx -s reload` after the swap, or `NGINX_OPEN_FILE_CACHE=off`
- [ ] Pool values (`PHP_FPM_MEMORY_LIMIT`, `PHP_FPM_REQUEST_TERMINATE_TIMEOUT`)
      set via env, not via a mounted `php.ini`
- [ ] Old releases pruned, at least two kept for rollback
- [ ] Statamic: Stache cache store is per-release, caches warmed

## Related

- [Queue Workers](queue-workers) — who the workers run as, and where
- [Statamic Guide](statamic-guide) — mount mode, baked mode, git integration
- [Production Deployment](production-deployment) — container-level rolling and
  blue-green deploys, for when a release is an image
- [Environment Variables](../reference/environment-variables) — every knob used
  on this page
