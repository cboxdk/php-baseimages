# Comprehensive Base Images Refresh

**Date**: 2026-03-19
**Status**: Approved
**Approach**: Single PR, parallel agent execution

## Context

PHP 8.5 has been stable since late 2025 (latest patch: 8.5.2). PHP 8.2 reached EOL on December 8, 2025. Several documentation files and Dockerfile defaults still carry stale beta/preview references and outdated version numbers.

## Changes

### 1. Xdebug Version Default Fix (4 files)

All php-base Dockerfiles have `ARG XDEBUG_VERSION=3.4.0` but versions.json specifies `3.5.0`. CI overrides the ARG, so published images are correct — but local builds get the wrong version.

**Files**: `php-base/{8.2,8.3,8.4,8.5}/debian/bookworm/Dockerfile`
**Change**: `ARG XDEBUG_VERSION=3.4.0` → `ARG XDEBUG_VERSION=3.5.0`

### 2. versions.json Cleanup (1 file)

Remove Alpine and Trixie OS entries — both removed in commit `addda9a` but metadata was left behind.

**File**: `versions.json`
**Change**: Remove `os.alpine` and `os.debian.supported: trixie` entries. Keep only Bookworm.

### 3. PHP 8.5 Beta Reference Cleanup (3 files)

- `docs/changelog.md` line 47: "PHP 8.5-beta support (experimental)" → "PHP 8.5 support"
- `CHANGELOG.md` lines 27-29: Remove/update "PHP 8.5 support postponed" known issue
- `php-base/8.5/debian/bookworm/Dockerfile` line 89: Update igbinary comment to reference 3.2.17RC1 tracking

### 4. Script Example Update (1 file)

- `scripts/get-build-state.sh` line 11: Update example from `8.5 alpine --preview` to `8.4 bookworm`

### 5. Lifecycle Message Updates (2 files)

- `common/lib/lifecycle-check.sh`: "PHP 8.3 or 8.4" → "PHP 8.4 or 8.5" (lines 54, 74, 109)
- `scripts/get-build-state.sh` line 135: Same upgrade path update

### 6. README.md Updates (1 file)

- "Xdebug 3.4" → "Xdebug 3.5" (lines 110, 126)
- docker-compose example version comment if applicable

### 7. Documentation Updates (1 file)

- `docs/reference/available-images.md` line 158: Remove PHP 8.4 stability qualifier — 8.5 is production-ready

## Out of Scope

- SBOM generation (CI/CD change, separate effort)
- Cosign image signing (CI/CD change, separate effort)
- PHP 8.2 removal (requires deprecation period, separate effort)
- Rate limiting documentation (separate improvement)
- igbinary stable migration (blocked on upstream 3.2.17 release)

## Risks

- **Low**: All changes are documentation/metadata/defaults. No runtime behavior changes.
- **igbinary comment**: Factual update, no build impact.
- **versions.json**: Removing dead metadata, no CI references to removed OS variants.
