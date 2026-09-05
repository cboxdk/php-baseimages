# Security Policy

## Reporting a vulnerability

Report vulnerabilities through
[GitHub private vulnerability reporting](https://github.com/cboxdk/php-baseimages/security/advisories/new)
on this repository. Please do not open public issues for security problems.

This is an open-source project maintained by a small team. We read reports and
respond as fast as we realistically can, but we do not promise a formal SLA.

## How these images stay patched

- **Weekly rebuilds** (Mondays 03:00 UTC) pull the latest upstream PHP and
  Debian base layers, so OS and PHP security patches reach every rolling and
  release-channel tag automatically. `docker pull` weekly to receive them.
- **Release-channel tags** (`8.4-bookworm-v1`) receive the same weekly security
  rebuilds without ever crossing a tooling major — pin these in production.
- **Immutable digests / SHA tags** are never rebuilt and age by design.

## What every published image carries

- Cosign signature (keyless, GitHub OIDC) on the manifest list
- SLSA provenance attestation (BuildKit `mode=max`)
- SPDX SBOM attestation per platform

Verify with `cosign verify` or
`docker buildx imagetools inspect <image> --format '{{ json .Provenance }}'`.

## CI vulnerability gate

Every build fails before any production tag moves if a fixable CRITICAL/HIGH
CVE appears that is not in the repository's triaged [`.trivyignore`](.trivyignore)
baseline (each entry annotated with its fix path). Full unfiltered scan results
are published to this repository's Security tab.

## Supported versions

Images follow the upstream PHP lifecycle: versions receive weekly rebuilds
until six months after their php.net **security support** end date. Current
dates live in [`versions.json`](versions.json); the tagging and deprecation
policy is documented in
[docs/reference/tagging-strategy.md](docs/reference/tagging-strategy.md).
