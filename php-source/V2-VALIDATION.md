# V2 local validation

Candidate: Debian 13 Trixie, PHP 8.2–8.5 stable source locks and a separate
PHP 8.6 preview lane. Validation date: 2026-11-06. Nothing was pushed,
released, tagged in Git, or dispatched to remote CI. Docker image tags below
are local test artifacts only.

Follow-up CI/security work, v1 parity measurements and constrained FPM tests
are recorded in [V2-POLISH.md](V2-POLISH.md).

## Scope and migration

- CLI and FPM compile the same signed, SHA256-verified php.net archive per
  series; upstream configure flags and the preview's ZTS ABI are retained.
- All image families move to Trixie. Native extension dependencies, t64
  packages, ImageMagick 7 policy paths and Debian-packaged Brotli are updated.
- HEIC/AVIF encoders are explicit dependencies: Debian now recommends them
  separately, so `--no-install-recommends` otherwise breaks image writes.
- Composer, Node, npm, Bun and Playwright are pinned. npm 12 is installed
  separately from Node 22 because its bundled npm 10 retained ten fixable
  HIGH findings in a direct Trivy rootfs scan. npm 12 had zero in that scan;
  empty-project install, ci and script execution passed as UID 0 and 33.
- `SSL_MODE=full` redirects through the existing HTTP server, keeps the
  health endpoint usable and handles forwarded HTTPS without a loop.
- Existing removal of PHP vips is documented as a v2 breaking change.

## Update and promotion safeguards

The hourly source checker checks stable patches and the separate preview.
Stable OS checks run at a six-hour cadence, skip unchanged package indexes,
and select full build / apt-only patch / byte-identical reuse per platform.
A new PHP lock bypasses the cadence. Patch history is bounded to 16 layers
and 30 days. APT-held packages force a full build instead of silent reuse.
Input, suite, source, lifecycle or tooling changes force a full
build. Missing labels cannot authorize patching an old v1 image into v2.

Downstream parents are verified against the same source commit and pinned to
platform digests. Failed or missing children are retried; an already running
chain is not duplicated. Repeated base failures back off. Both architectures
must pass before production tags move. Native runtime checks verify the exact
PHP version, the required core extension set, image format roundtrips and the running FPM/Nginx health checks.
Fixable HIGH/CRITICAL CVEs block promotion, with no inherited ignore entries.
An unchanged, already validated publication can be reused without re-signing,
re-scanning or re-uploading its layers.

These workflows are prepared locally, not activated. Their dispatch/token,
registry-attestation and promotion behavior has unit coverage but has not
been exercised against a live registry in this task.

## Recorded results

| Check | Result |
| --- | --- |
| Native runtime gate rejects missing extensions | Passed against a raw PHP image without Redis |
| Source renderer / patch planner / scheduler / parent pinning | 26 unit tests passed, including held-back APT packages |
| actionlint, ShellCheck, hadolint, docs/env/ARG/runtime-dependency checks | Passed |
| ARM64 PHP 8.2.35 CLI and FPM, shared bcmath extension, real FastCGI | Passed |
| ARM64 PHP 8.3.36 CLI and FPM, shared bcmath extension, real FastCGI | Passed |
| ARM64 PHP 8.4.27 CLI and FPM, shared bcmath extension, real FastCGI | Passed |
| ARM64 PHP 8.5.12 CLI and FPM, shared bcmath extension, real FastCGI | Passed |
| ARM64 PHP 8.6.0RC5 CLI and FPM, shared bcmath extension, real FastCGI | Passed, preview/ZTS |
| Trixie 8.6 preview FPM slim with Redis/APCu/msgpack development fallbacks | Passed: ZTS, loaded modules and real FastCGI |
| AMD64 PHP 8.5.12 CLI and FPM, shared bcmath extension, real FastCGI | Passed under emulation |
| Trixie apt patch, rootless user, unchanged PHP binary, real FPM request | Passed; patch build step 20–47 seconds across two runs |
| Second apt probe after that patch | No changes; reuse |
| Standalone Trixie Nginx config and HTTP health endpoint | Passed |
| Trixie SSL on/full/off, redirects, health and forwarded HTTPS | 12 checks passed as root; 12 as rootless |
| ImageMagick PNG/JPEG/WebP/AVIF/HEIC encode/decode | Passed on PHP 8.5 standard |
| npm 12 install/ci/scripts | Passed as root and rootless |
| Trivy raw PHP 8.5 CLI; 8.5 base slim/standard/dev; 8.5 FPM-Nginx dev rootless; 8.2 base standard; standalone Nginx | Zero fixable HIGH/CRITICAL, no exceptions |

The complete ARM64 production matrix passed: PHP 8.5 across all four image
families (base, CLI, FPM, FPM-Nginx), all four tiers and both users: **32 images**.
PHP 8.2 passed the same four families with slim/standard and both users:
**16 images**. All FPM variants served a real FastCGI request. All FPM-Nginx
variants passed startup and health checks. Both matrices check exact PHP,
required core extensions, Composer, UID and Debian suite; standard and above
also check Node/npm pins and PNG/JPEG/WebP/AVIF/HEIC roundtrips.

PHP 8.3 and 8.4 received the raw CLI/FPM source and shared-extension tests,
not the entire production-tier matrix. AMD64 received the PHP 8.5 source/ABI
smoke under emulation, not the full production matrix.

## Performance observation

Five alternating SHA256-loop samples compared the old Bookworm PHP 8.5.12
base-slim with the Trixie source-built equivalent, both NTS with CLI opcache
off. Checksums matched. The Trixie median was 0.362 seconds, a ratio of 0.860
to Bookworm. This is a small CPU smoke test on a heavily shared ARM64 Docker
host, not an application benchmark or a prediction of CI spend.

The apt-patch build took 20 seconds in the first run and 47 seconds in the
final regression run on the loaded host. These timings exclude registry inspection, package probing,
security scans and signing. It demonstrates PHP was not recompiled; production
CI savings must be measured once the future pipeline is deliberately enabled.

## Reproduce locally

```sh
python3 tests/test-php-source.py
python3 tests/test-image-patch.py
python3 tests/test-source-dispatch.py
python3 tests/test-source-parents.py
python3 scripts/sync-build-defaults.py --check
DOCKER_CONTEXT=orbstack PLATFORM=linux/arm64 bash scripts/test-php-source.sh 8.5
DOCKER_CONTEXT=orbstack PLATFORM=linux/amd64 bash scripts/test-php-source.sh 8.5
python3 scripts/test-v2-images.py --series 8.5
DOCKER_CONTEXT=orbstack bash scripts/test-image-patch.sh cbox-php-source:8.5.12-arm64-smoke
```

The local matrix checks all four image families and tiers as root/rootless,
including real FPM requests. Generated Dockerfiles and scan reports are
ignored under `.build/`; command logs are local under `/tmp/cbox-v2-*`.

## Limits before a future release

No release is authorized. Eventual v2 rollout still needs a deliberate
registry/promotion rehearsal, application testing, and activation of the
previous major's maintenance window. The old-RHEL-host xz/Landlock behavior
from issue #52 cannot be certified on this Apple Silicon/OrbStack host.
PHP 8.6 remains an explicitly unsupported preview; development-branch
extension fallbacks do not constitute production support.
