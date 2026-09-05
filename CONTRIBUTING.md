# Contributing

Thanks for considering a contribution. This file covers the practical basics;
the [docs](docs/getting-started/introduction.md) cover how the images work.

## Local setup

```bash
# Cbox Init binaries are not committed - download them once before building
./scripts/download-cbox-init.sh

# Build the multi-service image (standard tier)
docker build -f php-fpm-nginx/Dockerfile --target root --build-arg PHP_VERSION=8.4 -t cbox-dev .
```

All Dockerfiles build from the **repository root** (they copy from shared
`common/` directories), never from their own subdirectory.

## Where things live

| Change | Where |
|---|---|
| PHP extensions | `php-base/Dockerfile` only - downstream images copy from it |
| Entrypoint behavior | `{type}/common/docker-entrypoint.sh` |
| Nginx config | `php-fpm-nginx/common/default.conf.template` + entrypoint env wiring |
| Versions & lifecycle | `versions.json` (single source of truth for CI) |

One architectural rule to know: `php-fpm` and `php-fpm-nginx` **copy** from
php-base rather than building `FROM` it, so ENV does not propagate - build-time
state needs explicit ARG/ENV declarations in each Dockerfile.

## Testing

```bash
# Extension presence
./tests/unit/test-extensions.sh <image>

# Boot the image and exercise it - the minimum bar for entrypoint changes
docker run -d -p 8080:80 -v $PWD/test-app:/var/www/html cbox-dev
curl localhost:8080

# Config validation (runs automatically at container start too)
docker run --rm cbox-dev nginx -t
```

Entrypoint or config changes should be verified by actually booting the image
- CI runs E2E and integration suites on every PR, and images are only
promoted to their tags after a per-image smoke test and CVE gate pass.

## Pull requests

- Conventional commits (`feat:`, `fix:`, `docs:`, `ci:` ...) - the changelog
  is written from them
- Add a line to `docs/changelog.md` under `[Unreleased]` for user-visible
  changes
- New env vars must be documented in
  `docs/reference/environment-variables.md`

## Security issues

Please use
[private vulnerability reporting](https://github.com/cboxdk/php-baseimages/security/advisories/new)
- see [SECURITY.md](SECURITY.md).
