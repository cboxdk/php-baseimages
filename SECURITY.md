# Security Policy

Cbox PHP Base Images ship production PHP runtimes (PHP-FPM, CLI, Nginx, and the
multi-service PHP-FPM + Nginx image) used as the base for many applications. A
vulnerability here can affect every downstream image, so we take reports
seriously and rebuild weekly to pick up upstream security patches.

## Supported Versions

Security-patched, rolling tags are published for all currently-supported PHP
versions (see `versions.json` → `php.supported`). EOL PHP versions are removed
per the deprecation policy in `versions.json`.

| PHP | Status |
|-----|--------|
| 8.4, 8.5 | ✅ supported (rolling `8.x-bookworm` tags rebuilt weekly) |
| 8.2, 8.3 | ✅ supported until EOL (see `versions.json`) |
| < 8.2 | ❌ end of life |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report privately via:

- GitHub [private vulnerability reporting](https://github.com/cboxdk/php-baseimages/security/advisories/new) (preferred), or
- Email **security@cbox.dk**.

Include: affected image(s) and tag(s), tier (slim/standard/chromium/dev, root or
rootless), a description and impact, and reproduction steps.

We aim to acknowledge within 3 business days and to ship a fix or mitigation
prioritised by severity, credited in the release notes unless you prefer
anonymity.

## Verifying Image Integrity

Images (php-base, php-fpm, php-fpm-nginx) are signed with
[cosign](https://github.com/sigstore/cosign) using keyless (OIDC) signing:

```bash
cosign verify \
  --certificate-identity-regexp 'https://github.com/cboxdk/php-baseimages/.github/workflows/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/cboxdk/php-baseimages/php-fpm:8.4-bookworm
```

Every published tag is also scanned with Trivy (CRITICAL/HIGH); results appear
in the repository's Security tab and gate the build on fixable findings.

## Hardening Guidance

- **Run rootless where possible** — use the `-rootless` image variants; they run
  as `www-data` and listen on port 8080.
- **Drop capabilities** — run with `--cap-drop=ALL --security-opt=no-new-privileges`
  and add back only what you need.
- **Pin by digest** for reproducibility (`...@sha256:...`) and use rolling tags
  for automatic weekly security updates.
- **Protect the cbox-init management API** — it is disabled by default; if you
  enable it, set a bearer token and bind it to a trusted interface.

See `docs/` for full guidance.
