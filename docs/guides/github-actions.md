---
title: "GitHub Actions"
description: "Run CI inside the exact image you deploy - job containers, service containers, and zero-download browser tests"
weight: 27
---

# GitHub Actions

The strongest reason to run CI in these images: **your tests run in the exact
environment you deploy** - same PHP build, same extensions, same php.ini,
same OS packages. No `setup-php` drift between the runner and production.

Everything on this page is continuously verified by a workflow in this
repository (`.github/workflows/verify-actions-usage.yml`) that runs right
after the weekly image rebuilds.

## Job containers: test in the deploy image

```yaml
jobs:
  test:
    runs-on: ubuntu-24.04
    container:
      image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
    steps:
      - uses: actions/checkout@v5
      - run: composer install --no-interaction
      - run: vendor/bin/pest
```

Expected: every step runs inside the image with `php`, `composer`, `node`
and `git` on PATH. No setup actions needed.

What makes this work (and what to know):

- **Use the root variants for CI.** GitHub's runner requires the container
  user to be able to write the mounted workspace; the root images (the
  default tags) comply. The `-rootless` variants run as `www-data` and will
  hit permission errors against the runner-owned workspace - they are for
  production, not runners.
- **`actions/checkout` just works.** The workspace is owned by the runner
  user while git runs as root in the container - the classic
  `dubious ownership` failure on other images. `safe.directory` is baked
  into `/etc/gitconfig` here, so there is nothing to configure.
- **The entrypoint does not run.** GitHub overrides it for job containers,
  so cbox-init, autotune and framework detection are not involved - your
  steps get a plain toolchain. That is correct for CI: those features manage
  a *serving* container.
- **Pick the tier by what CI needs**: `-v1` (standard) for most suites,
  `-chromium-v1` for browser tests, `-dev-v1` when coverage needs
  PCOV/Xdebug.

### With databases

Service containers share the job's network; from inside a job container you
reach them by service name:

```yaml
jobs:
  test:
    runs-on: ubuntu-24.04
    container:
      image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: secret
          MYSQL_DATABASE: testing
        options: >-
          --health-cmd "mysqladmin ping -h localhost"
          --health-interval 5s --health-timeout 3s --health-retries 10
      redis:
        image: redis:7-alpine
    steps:
      - uses: actions/checkout@v5
      - run: composer install --no-interaction
      - run: vendor/bin/pest
        env:
          DB_HOST: mysql
          REDIS_HOST: redis
```

### Composer and npm caching

```yaml
      - uses: actions/cache@v4
        with:
          path: |
            ~/.composer/cache
            ~/.npm
          key: deps-${{ runner.os }}-${{ hashFiles('composer.lock', 'package-lock.json') }}
```

## Browser tests with zero downloads

On the chromium tier, Pest v4/v5 browser tests run against the Playwright
Chromium already baked into the image - the browser download (~150 MB) that
costs other setups one to two minutes per workflow run simply does not
happen:

```yaml
jobs:
  browser:
    runs-on: ubuntu-24.04
    container:
      image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-chromium-v1
    steps:
      - uses: actions/checkout@v5
      - run: composer install --no-interaction
      - run: npm ci
      - run: vendor/bin/pest   # browser tests included - no playwright install step
```

The one rule: the image bakes the browser matching `playwright@latest` at
its weekly rebuild, so keep your npm `playwright` current (see the
[Browser Testing guide](browser-testing) for the version-skew symptom and
fix). Laravel Dusk works the same way via the image's version-matched
`chromedriver` - no `dusk:chrome-driver` step.

## Service containers: integration-test against the running image

The multi-service image also works on the other side of the fence - as the
thing your tests talk to:

```yaml
jobs:
  smoke:
    runs-on: ubuntu-24.04
    services:
      app:
        image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1
        ports:
          - 8080:80
    steps:
      - run: curl -sf http://localhost:8080/healthz
```

The runner waits for the image's built-in `HEALTHCHECK` before your steps
start - no sleep loops. Note that service containers cannot mount your
checkout, so this pattern fits smoke/contract tests against a published app
image (your app baked into a derived image), not "mount my code" testing -
that is what job containers are for.

## Multi-arch runners

The images are `linux/amd64` + `linux/arm64`, so the same workflow runs
unchanged on `ubuntu-24.04` and `ubuntu-24.04-arm` runners.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Permission errors writing the workspace | `-rootless` image in a job container | Use the root variant (default tags) for CI |
| `dubious ownership` from git | You are on a pre-1.6.2 image | Upgrade; `safe.directory` is baked since 1.6.2 |
| Playwright downloads a browser anyway | npm `playwright` newer than the image's weekly bake | `docker pull` the current image, or pin `playwright` to the image week; see [Browser Testing](browser-testing) |
| Service container never becomes ready | Health options missing on third-party images | Our images ship a `HEALTHCHECK`; for others add `options: --health-cmd ...` |
