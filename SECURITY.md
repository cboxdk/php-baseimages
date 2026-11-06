# Security Policy

## Reporting a vulnerability

Report vulnerabilities through
[GitHub private vulnerability reporting](https://github.com/cboxdk/php-baseimages/security/advisories/new)
on this repository. Please do not open public issues for security problems.

This is an open-source project maintained by a small team. We read reports and
respond as fast as we realistically can, but we do not promise a formal SLA.

## How these images stay patched

The v2 changes described here are an unpublished local candidate. They become
active only after an authorized merge and workflow rollout; existing v1
publications are unchanged.

- **Hourly PHP checks** update verified source locks when php.net releases a patch.
- **Debian security changes** bypass the normal six-hour OS cadence at the next
  hourly check. Unchanged package indexes skip builds; eligible images receive
  APT-only patches or digest reuse. A fresh full build is required after 30 days
  or 16 patch layers, and whenever source/configuration/tooling changes.
- **Hourly CVE watch** scans both architectures of each stable PHP series' dev
  CLI and FPM/Nginx images and standalone Nginx. These representatives cover the bundled
  OS, browser and application tooling; promotion gates still scan each published
  image. Inventories are cached by digest, vulnerability results are not.
- **Mitigation** requests an APT build for OS findings and a dependency-update
  review for non-OS findings. Repeated identical findings back off for six hours;
  new findings can trigger immediately. Dependency proposals also run daily.
- **Release-channel tags** (`8.5-trixie-v2`) receive these updates without crossing
  the image major. Consumers must pull/redeploy to adopt a changed tag.
- **Immutable digests / SHA tags** are never rebuilt and age by design.

Source-built PHP follows php.net, not APT. APT cannot update compiled extensions
or embedded Go/npm dependencies. Inventory scans are not a complete advisory
feed for every native extension, so source/tool pin updates and review remain
necessary. No timing here is a guaranteed remediation SLA.

## What every published image carries

- Cosign signature (keyless, GitHub OIDC) on the manifest list
- SLSA provenance attestation (BuildKit `mode=max`)
- SPDX SBOM attestation per platform

Retrieve the SBOM straight from any image — no registry login needed for
public images:

```bash
# Full SPDX document for one platform
docker buildx imagetools inspect ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-trixie-v2 \
  --format '{{ json (index .SBOM "linux/amd64").SPDX }}' > sbom.spdx.json

# Provenance (SLSA)
docker buildx imagetools inspect ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-trixie-v2 \
  --format '{{ json .Provenance }}'
```

Signature verification:
`cosign verify ghcr.io/cboxdk/php-baseimages/<image>:<tag>`.

## CI vulnerability gate

Every build fails before any production tag moves if a fixable CRITICAL/HIGH
CVE appears that is not in the repository's triaged [`.trivyignore`](.trivyignore)
policy. V2 currently has no ignored CVEs. PHP scan results are uploaded to
the Security tab; the published-image watch retains per-platform reports and
a workflow summary. Scanner errors fail visibly rather than reporting a clean
image. Standalone Nginx now passes both architecture gates before promotion.

## Supported versions

Images follow the upstream PHP lifecycle: versions receive update checks
until six months after their php.net **security support** end date. Current
dates live in [`versions.json`](versions.json); the tagging and deprecation
policy is documented in
[docs/reference/tagging-strategy.md](docs/reference/tagging-strategy.md).
