# V2 compatibility and security follow-up

Local validation on 2026-11-06, ARM64 OrbStack. Nothing was pushed, published,
tagged or dispatched to GitHub Actions. This supplements [initial V2 validation](V2-VALIDATION.md).

## Compatibility with published Bookworm images

The comparison checks every existing PHP INI value and extension, runtime ENV,
user, work directory, entrypoint, command, ports, healthcheck, stop signal and
volumes. PHP patch versions and lifecycle/build metadata are reported separately.

| Published FPM/Nginx baseline | Extensions | INI values | CLI/container parity | HTTP/FPM parity |
| --- | ---: | ---: | --- | --- |
| PHP 8.5 standard | 64 | 344 | Pass | Pass |
| PHP 8.5 standard rootless | 64 | 344 | Pass | Pass |
| PHP 8.5 dev | 67 | 440 | Pass | Not run |
| PHP 8.5 slim rootless | 52 | 329 | Pass | Not run |
| PHP 8.2 standard | 62 | 337 | Pass | Pass |

Baseline digests, in table order:

- `sha256:e3c1753f2f5a5d3a4502a229da38f62e13b0b473cfabca5114d55518bace4eb4`
- `sha256:b4d7228dc08320fa8464f961725ae06f0216dcf8f547e8c7e0d9430dede63c20`
- `sha256:9539e907c16118c2b4fb336b63303d29151075c6fa3f3823f69c94ea85e7c0fd`
- `sha256:afba848537756aef2a4b70780acc9169344cd265dde5d5033a2ea7dd905c2c2a`
- `sha256:9daeb130d4f74da74a14b1246997722d37eff3e3bc1ee703b1ee86d89a90a9de`

Raw local evidence: `.build/v2-parity-initial.json`, `.build/parity-http-85.json`,
`.build/parity-http-85-rootless.json`, `.build/parity-http-82.json`.
The reusable comparison is `scripts/test-image-parity.py`.

HTTP parity uses an explicit `PHP_FPM_MAX_CHILDREN=10` for both images: the old
published image otherwise fails under the test's 512 MiB limit. Its entrypoint
writes a literal `pm.max_spare_servers=6`, then cbox-init autotunes max_children
to four. FPM refuses that configuration. V2 now lets FPM read the final autotuned
environment, bounds implicit defaults to the pool size, and retains explicit
user settings. This is an intentional correction to the old startup behavior.

Separate actual HTTP tests pass with automatic sizing and an explicit one-worker
pool at 512 MiB/one CPU, both root and rootless. Standalone PHP 8.2 FPM root and
8.5 FPM rootless also serve requests at 256 MiB with one worker. All 24 SSL checks
pass after the entrypoint fix. These targeted tests use runtime overlays on the
previously built source images. PHP 8.2 FPM/Nginx slim root/rootless were also rebuilt
through the actual Dockerfile to verify lifecycle metadata matches CI:
`deprecated`, EOL `2026-12-31`, removal `2027-07-01`. Local date arithmetic now
matches GNU/Linux overflow semantics on macOS.

The migration still intentionally changes Debian 12 to 13, ImageMagick 6 to 7,
and npm 10 to 12. PHP 8.6 remains a separate ZTS preview. Native extensions built
outside these images may need rebuilding. Representative parity is not proof
that every application, architecture or custom configuration is compatible.
See the [migration guide](../docs/getting-started/migration-guide.md).

## Faster security mitigation with bounded CI work

- Hourly PHP checks distinguish Debian security-index changes from ordinary
  repository changes. Security updates bypass the normal six-hour cadence.
  Matching source inputs use APT-only patches or unchanged-digest reuse;
  changed PHP locks/build inputs still require full builds.
- Multiple due stable PHP versions dispatch together. This avoids GitHub's
  single pending-run slot replacing earlier version-specific requests.
  Active child chains are respected; repeated unchanged failures back off for
  six hours, while new revisions bypass the backoff.
- The hourly CVE watch covers CLI/dev and FPM/Nginx/dev for PHP 8.2–8.5 plus
  standalone Nginx, on AMD64 and ARM64: 18 immutable image inventories.
  Inventories are cached by digest and Trivy version; vulnerability results are
  rescanned against current advisories. Missing inventories or scan failures fail
  visibly. OS fixes request rebuilds; bundled-tool fixes request dependency-update
  proposals, which still need review. Duplicate findings are throttled, while new
  findings bypass the delay. Local invocation defaults to report-only.
- Standalone Nginx also watches its parent digest. Every requested rebuild busts
  the APT layer. Both architectures must pass CVE and HTTP checks before tag
  promotion; candidate signing and provenance precede publication of final tags.
- Dependency proposals run daily. Trivy actions are pinned by commit and scanner
  version. Browser tests use the installed Playwright version. Runtime CI now
  exercises constrained-memory FPM startup rather than only large runners.

The monitor uses Trivy-generated CycloneDX because Trivy documents potential
matching inaccuracies with [other generators' SBOMs](https://trivy.dev/docs/dev/docs/target/sbom/).
A real local PHP 8.5 dev/rootless inventory includes 405 Debian packages and
Go/Node package analysis: zero fixable HIGH/CRITICAL findings. Reusing its
1,164,286-byte inventory and rescanning took **1.64 seconds** locally, with no
inventory rewrite. This is not a GitHub runner benchmark. A positive control
using the old vulnerable npm inventory retained all ten HIGH findings after
SBOM conversion and rescan; the cache does not conceal those findings.

The watch complements per-image promotion gates. It does not provide exhaustive
advisory coverage for every source-built PHP extension. Published image fixes
also require consumers to pull and redeploy. The new remote jobs have not run:
their v2 tag watch becomes usable only after a separately authorized publication.

## Local verification

- 44 regression methods cover source locks, patch selection, dispatch/backoff,
  parent pinning, security scans/cache, FPM defaults and parity comparisons.
- Workflow lint, shell error checks, Dockerfile error checks, build-default sync,
  environment/documentation contracts, links, runtime dependencies and whitespace.
- Five CLI/container comparisons and three real HTTP/FPM comparisons above;
  four constrained FPM/Nginx cases, two standalone FPM cases, and 24 SSL checks.
- Updated standalone Nginx Dockerfile builds locally, passes config/HTTP health,
  and has zero fixable HIGH/CRITICAL findings in the fresh Trivy scan.

Evidence is retained under ignored `.build/` and `/tmp/cbox-*` paths. The initial
48-image ARM64 matrix and limited AMD64 source validation are documented in the
initial report; they were not all rebuilt again for these shell/workflow changes.
Actual GitHub concurrency, signing and registry promotion remain untested locally.

## Preparation for review

Integrated `main` through `2b1e955`, including approved cbox-init 3.9.0,
QEMU action v4, Statamic control-panel asset publication and upstream
memory-limit regression coverage. The overlapping FPM fix retains V2's policy
of bounding implicit defaults while preserving explicit user settings.
All 44 regression methods and contract checks passed again after integration;
a runtime overlay with checksum-verified cbox-init 3.9.0 passed both automatic
and one-worker HTTP tests at 512 MiB.

Preview publication and published-image usage checks now restrict push triggers
to main. Draft PRs skip the PR dev-image publisher. This permits branch review
without image publication. Merging to main still activates publishing workflows
and must be treated as a separate deployment decision.

## cbox-init security release follow-up

The first remote integration scan caught CVE-2026-78661 in cbox-init 3.9.0's
embedded x/net v0.60.0. cbox-init 3.9.1 updates x/net to v0.62.0 with its required
x/sys and x/text versions. The upstream fix passed the full local check suite
and CI before release. Both published Linux binaries were downloaded, verified
against release checksums and scanned with Trivy 0.76.2: zero fixable
HIGH/CRITICAL findings. No vulnerability exception was added.

The PHP images now pin 3.9.1. The integration scanner also uses the same pinned
Trivy 0.76.2 setup as promotion instead of its previous standalone 0.70.0 install.
