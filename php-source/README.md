# Locked PHP builds and fast OS updates

CLI and FPM use one verified php.net source archive per PHP series. The table
records the initial v2 candidate; the lock files are authoritative after
automatic patch updates:

| Series | Locked version | Channel |
| --- | --- | --- |
| 8.2 | 8.2.35 | Stable |
| 8.3 | 8.3.36 | Stable |
| 8.4 | 8.4.27 | Stable |
| 8.5 | 8.5.12 | Stable |
| 8.6 | 8.6.0RC5 | Preview, never promoted automatically to stable |

Each `phpNN-trixie.lock.json` records the series, channel, exact version,
archive URL, SHA256 and upstream recipe commit. Builds verify both SHA256 and
the PHP release's GPG signature before compilation. Stable patches cannot
cross series, downgrade, or select a prerelease. The 8.6 lane follows only
8.6.0 alpha/beta/RC releases, ordered numerically (RC10 follows RC9). GA adoption
is a separate change.

The recipes in `upstream/<series>/` and shared helper scripts come from
[docker-library/php](https://github.com/docker-library/php/tree/edf9e498995663d335b093735cb527b05bbd2bff).
The license is retained. Recipe and signing-key changes require review.
The renderer keeps each version's configure flags: for example, the 8.6
recipes enable ZTS for both CLI and FPM. It removes the unnecessary PECL channel
refresh, changes the build-provider label, and prefixes helper COPY paths.

## Full build, OS patch, or no build

The stable image workflow selects one of three paths for each architecture:

1. **Full build:** no previous publication, changed PHP lock or other build
   input, missing/untrusted metadata, a lifecycle transition, 16 accumulated
   patch layers, a full build older than 30 days, packages held back by APT, or an explicit `force_full`.
2. **OS patch:** build inputs match and APT finds packages to upgrade. Build
   `FROM` the previous publication's exact platform digest; run
   `apt-get update` and `apt-get upgrade --with-new-pkgs`, remove package
   indexes, and restore the original image user. PHP, extensions, Node, Bun,
   Composer, configuration, entrypoint and command are inherited unchanged.
3. **Reuse:** inputs match and APT finds no packages to upgrade. Reuse the
   existing platform digest and its SBOM/provenance manifests. No Docker build,
   new filesystem layer, or new image upload is needed. When both platforms
   are unchanged on main, skip the merge/sign/scan job and retain the existing
   multi-arch publication. A mixed reuse/patch build still gates both platforms.

`image-patch.py` computes a fingerprint of relevant repository files, the
series' source lock, tool/extension versions, caller build arguments, target,
platform and effective lifecycle state. Unrelated PHP patch inventory and
metadata timestamps are excluded. Changes to the build workflow itself are
conservatively treated as full-build changes. The CVE policy file also
participates, so tightening it cannot be skipped by the no-op path. V2 removes
the old accepted OS/Go/npm backlog; fixable HIGH/CRITICAL findings block
promotion without those inherited exceptions.

These labels record the decision's inputs and history:

- `io.cbox.build.debian-suite` (must be `trixie`; Bookworm never patches into v2)
- `io.cbox.build.fingerprint`
- `io.cbox.build.php-version`
- `io.cbox.build.patch-depth`
- `io.cbox.build.full-built-at`

Full downstream builds validate reachable Cbox parent fingerprints against
the same checkout and lock, then replace their tags with platform digests.
This prevents a concurrent source/tool update from changing a parent between
validation and build. Missing or mismatched parents fail until the matching
base chain succeeds.

The planner reads registry configuration without downloading layers. Only an
eligible candidate needs the APT probe. Missing old labels cause a first full
build; existing publications are never assumed compatible. APT index errors
fail the job, including partial mirror failures, rather than being reported as
"no updates". An OS patch does not fix vulnerabilities in source-built PHP or
extensions: those require a new source/tool version and a full build.

Both architecture digests pass the existing fixable HIGH/CRITICAL CVE gate
before any production tags move. Smoke tests, the baseline policy, signing,
SBOM and provenance remain in the publication path, including a reused
platform when its sibling architecture changes.
The fast paths skip build-only prerequisite downloads and full-build disk
cleanup. The local Trixie ARM64 rootless patch tests took 20–47 seconds for the build
step; this excludes the probe and CI scanning and is not a production CI
estimate. See [the v2 validation record](V2-VALIDATION.md) for measured scope.

## Scheduling

`check-php-source.yml` runs hourly at minute 17 on `main`:

- Check php.net for stable 8.2/8.3/8.4/8.5 patches and its prerelease API for 8.6.
- Commit changed source locks together and explicitly dispatch builds
  (`GITHUB_TOKEN` pushes do not trigger push workflows).
- Read the amd64/arm64 package-index hashes for Debian Trixie, updates and
  security, plus effective lifecycle transitions. The scheduler ignores
  rotating signature dates and daily EOL countdowns.
- For stable lanes, ordinary OS changes use a six-hour cadence. A changed
  Debian security index bypasses that delay on the next hourly check. If the last
  successful check used the same source commit and package-index revision,
  skip the matrix entirely (with a 30-day maximum interval). If an individual
  image has no installed package updates, its planner also reuses its digest.
- Retry failed/cancelled or missing downstream chains, not just base builds;
  do not duplicate queued/running builds. Multiple due PHP versions are
  dispatched as one `all` run: GitHub concurrency only retains one pending run.
  Run titles distinguish PHP series, so one version cannot suppress another.

New source locks trigger builds regardless of the previous OS-check interval.
A successful stable base build dispatches the matching CLI and FPM series;
FPM then dispatches Nginx. The source commit is carried through that chain.
The old independent weekly downstream schedules are removed to avoid duplicate
and racing work. The old weekly base matrix is also replaced by this hourly controller; a
30-day maximum age still forces a fresh full build. The checker matches downstream runs to the source SHA and base start time.
A missing child receives a one-hour dispatch grace period; failures retry on
the next hourly check. After three failed base builds against unchanged
inputs, retries back off to six hours; a new source commit or package-index
revision resets that delay. Preview API failure does not prevent stable updates.
Manual `force_full` propagates through the stable chain. Standalone Nginx also
tracks its official parent manifest, so upstream Nginx updates do not wait for
a Debian package-index change. Repeated unchanged child failures back off,
and active sibling jobs take precedence over retrying an earlier failed child.

`security-watch.yml` separately scans current publications hourly, even when
builds are skipped. It generates Trivy CycloneDX inventories once per immutable
platform digest, caches them, and re-scans with the current vulnerability DB.
The richer CLI and FPM/Nginx dev tiers are watched for each stable series and architecture,
plus standalone Nginx. OS findings request APT builds; non-OS findings request
reviewed dependency updates. Identical findings retry at most every six hours.
This does not replace the full-image CVE gates before every promotion.
[Trivy documents](https://trivy.dev/docs/dev/docs/target/sbom/) why inventories
from the same scanner preserve the metadata needed for accurate matching.

The preview lane builds both CLI-based and FPM tiers under explicit beta tags.
It refreshes on new source locks and weekly, rather than using the stable
OS-only shortcut: its intentionally unpinned extension attempts are also an
upstream compatibility monitor. It never enters the stable release matrix. The local 8.6.0RC5 slim test passed,
but Redis, APCu and msgpack currently need the preview lane's existing dev-branch
fallbacks; their stable package releases failed to install. This is not a
production-support claim for 8.6.

The checker requires permission to push locks to `main`; a rejected push fails
before dispatch. The future workflows publish images through the existing
pipeline, but create no Git tags or GitHub releases. Local files do not activate
these schedules; nothing is published until the work is pushed/merged and run.

## Local validation (no publishing)

```sh
python3 tests/test-php-source.py
python3 tests/test-image-patch.py
DOCKER_CONTEXT=orbstack PLATFORM=linux/arm64 bash scripts/test-php-source.sh 8.2
DOCKER_CONTEXT=orbstack PLATFORM=linux/arm64 bash scripts/test-php-source.sh 8.3
DOCKER_CONTEXT=orbstack PLATFORM=linux/arm64 bash scripts/test-php-source.sh 8.4
DOCKER_CONTEXT=orbstack PLATFORM=linux/arm64 bash scripts/test-php-source.sh 8.5
DOCKER_CONTEXT=orbstack PLATFORM=linux/arm64 bash scripts/test-php-source.sh 8.6
DOCKER_CONTEXT=orbstack bash scripts/test-image-patch.sh cbox-php-source:8.5.12-arm64-smoke
```

The source smoke test compiles bcmath with CLI's headers, copies it into FPM,
and verifies a real FastCGI request. The OS-patch test verifies the unchanged
PHP binary, restored rootless user and a successful FPM request after patching.
These scripts never push or dispatch CI. AMD64 can be tested locally by setting
`PLATFORM=linux/amd64` in the source test (through emulation on Apple Silicon).

For a full Cbox image, render the combined Dockerfile and use the normal local
build prerequisites:

```sh
python3 scripts/php-source.py --series 8.3 render php-base --output .build/php-source/8.3/base.Dockerfile
docker build -f .build/php-source/8.3/base.Dockerfile \
  --build-arg PHP_VERSION=8.3 --target slim-root -t cbox-source-base:local .

python3 scripts/php-source.py --series 8.6 render php86-fpm --output .build/php-source/8.6/preview.Dockerfile
docker build -f .build/php-source/8.6/preview.Dockerfile \
  --target beta-fpm-slim -t cbox-source-preview:local .
```

Original Dockerfiles still support their old direct-build path. The renderer
selects the source path, writes only to ignored `.build/`, and checks imported
stable Cbox stages against the locked PHP version before copying extensions.
`versions.json` retains the advisory latest-patch inventory; the source locks
are authoritative for the compiler inputs and source-built image patch tags.
