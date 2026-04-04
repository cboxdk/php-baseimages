# Chromium Rename + Docs Refactor

**Date:** 2026-04-04
**Status:** Approved

## Overview

Two changes in one pass:

1. Rename the `full` Docker image tier to `chromium` across the entire codebase
2. Moderate docs refactor: reduce from 48 files / 17k lines to ~25 files / ~9k lines

## Part 1: `full` → `chromium` Rename

### Rationale

"Full" implies other tiers are incomplete, pushing users toward a 700MB image when 250MB (standard) is right for 90%+ of use cases. "Chromium" is honest about what the extra 450MB buys: a headless browser for Browsershot, Dusk, Puppeteer, and PDF generation.

### Tier Naming

| Before | After | Size | Purpose |
|--------|-------|------|---------|
| slim | slim | ~120MB | Core PHP extensions |
| standard | standard | ~250MB | + imagick, vips, Node.js |
| full | **chromium** | ~700MB | + headless Chromium |
| dev | dev | ~800MB | + Xdebug, PCOV, SPX |

No backwards-compatibility alias. Few users, clean break.

### Files to Change

**php-base Dockerfiles** (8.2, 8.3, 8.4, 8.5):
- Stage names: `full-base` �� `chromium-base`, `full-root` → `chromium-root`, `full-rootless` → `chromium-rootless`
- `CBOX_IMAGE_TIER=full` → `CBOX_IMAGE_TIER=chromium`
- Comment on line ~10: "full:" → "chromium:"
- Dev stage: `FROM full-base` → `FROM chromium-base`

**Downstream Dockerfiles** (php-fpm, php-cli, php-fpm-nginx — all versions):
- Build target references: `full-root`/`full-rootless` → `chromium-root`/`chromium-rootless`

**GitHub Actions workflows** (build-php-base.yml, build-php-cli.yml, build-php-fpm.yml, build-php-fpm-nginx.yml, e2e-tests.yml):
- Job names: `build-full-matrix` → `build-chromium-matrix`, `build-full-rootless-matrix` → `build-chromium-rootless-matrix`
- Docker tags: `-full` suffix → `-chromium`
- Cache scopes: `*-full` → `*-chromium`
- Log/echo messages

**Docs, README, templates, tests:**
- All narrative references to "full" tier
- Size tables
- Tag examples
- docker-compose profiles and service names
- Test scripts referencing full tier

## Part 2: Moderate Docs Refactor

### Rationale

48 docs files with 17k+ lines of content. Significant duplication: docker-compose patterns in 13+ files, 8 framework guides that are 90% identical, tier selection explained 4+ times. The quality of individual content is good, but the volume makes it hard to maintain and overwhelming to navigate.

### Target

~38 files, ~9k lines. The big win is halving the line count and eliminating duplication, not the file count.

### Delete: 4 Niche Framework Guides

| File | Lines | Reason |
|------|-------|--------|
| `docs/guides/drupal-guide.md` | 159 | Standard tier + generic PHP setup |
| `docs/guides/magento-guide.md` | 189 | Standard tier + generic PHP setup |
| `docs/guides/typo3-guide.md` | 154 | Standard tier + generic PHP setup |
| `docs/guides/statamic-guide.md` | 150 | Is Laravel — guide itself admits this |

Add a short "Other Frameworks" section to `docs/guides/_index.md` with one-liner pointers: "Statamic runs on Laravel — use the Laravel guide. Drupal/TYPO3/Magento work with standard tier — use the quickstart."

### Trim: 3 Oversized Pages (→ max ~400 lines each)

**`docs/advanced/security-hardening.md`** (1,341 → ~400):
- Remove verbose example configs that users should get from official sources
- Keep concrete, Cbox-specific security recommendations
- Link to external references instead of reproducing them

**`docs/guides/production-deployment.md`** (889 → ~400):
- Remove duplicated docker-compose patterns (link to quickstart)
- Remove duplicated tier selection content (link to choosing-your-image)
- Focus on prod-specific concerns: health checks, logging, scaling, rollbacks

**`docs/guides/development-workflow.md`** (847 → ~400):
- Remove overlap with quickstart (basic setup)
- Remove overlap with debugging-guide (troubleshooting)
- Focus on dev-specific: Xdebug config, hot reload, dev tier usage

### Eliminate: Duplicated Content

**Docker-compose examples:**
- `docs/getting-started/quickstart.md` is the canonical source for basic docker-compose
- All other pages link to quickstart instead of reproducing examples
- Framework guides include only framework-specific additions (e.g., Laravel scheduler env var)

**"Use service names not localhost":**
- Single explanation in `docs/troubleshooting/common-issues.md`
- Framework guides link there instead of repeating

**Tier selection:**
- `docs/getting-started/choosing-variant.md` is the authoritative page
- Remove duplicated tier content from `_index.md`, `quick-reference.md`

### Merge: 2 Overlapping Reference Pages

**`choosing-variant.md` + `editions-comparison.md`** → `choosing-your-image.md`:
- One page for "which image do I pick?"
- Covers tier selection, root vs rootless, single vs multi-service
- Absorbs the useful content from `multi-service-vs-separate.md` as a short section

Delete after merge:
- `docs/getting-started/choosing-variant.md`
- `docs/reference/editions-comparison.md`
- `docs/reference/multi-service-vs-separate.md`

### New Page: `choosing-your-image.md`

Inspired by ServersideUp's image matrix (serversideup.net/open-source/docker-php/docs/getting-started/choosing-an-image). Lead with a clean, scannable table showing every image tag and its size — no prose, let the numbers speak. Then a brief section on tier differences and when to pick what.

Structure:
1. **Image size matrix** — table with columns: Image tag, Tier, Size. All PHP versions × all tiers. Visual, compact, easy to scan.
2. **When to use each tier** — 4 short paragraphs (slim/standard/chromium/dev), max 2-3 sentences each.
3. **Root vs rootless** — brief explanation, which to pick.
4. **Single-service vs multi-service** — absorbed from multi-service-vs-separate.md, trimmed to essentials.

Note: actual image sizes should be verified by building and checking `docker images` before publishing. Use approximate sizes in the initial version, replace with real MiB values when available.

### Fix: Landing Page (`docs/_index.md`)

Current issues visible on cbox.dk:
1. **No nav item** — the landing page has no sidebar link to navigate back to it
2. **Duplicate H1** — frontmatter `title` and markdown `# heading` both render, producing double header
3. **Stale tier table** — still shows "Full" tier (will be fixed by chromium rename)
4. **Overly long** (290 lines) — too much content for a landing page

Fix:
- Rename to "Cbox PHP Base Images" (not "Cbox Base Images Documentation") — both frontmatter title and description
- Remove the markdown H1 (let frontmatter `title` handle it)
- Trim to ~100 lines: "Start Here" links + tier quick-reference table + section overview. Cut the role-based navigation, documentation structure breakdown, and status sections.
- The nav item issue may be a website-side config (how cbox.dk renders `_index.md`), but ensure the frontmatter has correct `title` and `weight: 0` so it appears first in navigation.

Note: "Cbox PHP Base Images" branding should be consistent across all docs, README, and CLAUDE.md.

### Keep Intact

These pages are useful as-is and don't have significant duplication:

- `docs/getting-started/quickstart.md` (134 lines) — excellent as-is
- `docs/getting-started/introduction.md` — trim slightly
- `docs/getting-started/faq.md` — trim duplicated content
- `docs/guides/laravel-guide.md` — trim duplicated docker-compose
- `docs/guides/symfony-guide.md` — trim duplicated docker-compose
- `docs/guides/wordpress-guide.md` — trim duplicated docker-compose
- `docs/guides/queue-workers.md` — unique, useful content
- `docs/guides/image-processing.md` — unique, useful content
- `docs/reference/environment-variables.md` — reference lookup, keep
- `docs/reference/configuration-options.md` — reference lookup, trim slightly
- `docs/reference/available-extensions.md` — reference lookup, keep
- `docs/reference/available-images.md` — reference lookup, keep
- `docs/reference/health-checks.md` — reference lookup, keep
- `docs/reference/tagging-strategy.md` — reference lookup, keep
- `docs/reference/quick-reference.md` — trim duplicated tier content
- `docs/troubleshooting/common-issues.md` — keep
- `docs/troubleshooting/debugging-guide.md` — keep
- `docs/troubleshooting/migration-guide.md` — keep
- `docs/advanced/extending-images.md` — trim slightly
- `docs/advanced/custom-extensions.md` — keep
- `docs/advanced/custom-initialization.md` — trim
- `docs/advanced/rootless-containers.md` — keep
- `docs/advanced/performance-tuning.md` — trim
- `docs/advanced/reverse-proxy-mtls.md` — trim
- `docs/advanced/multi-architecture.md` — trim
- `docs/advanced/testing-guide.md` — keep
- `docs/cbox-init-integration.md` — keep
- `docs/changelog.md` — keep
- Index files (`_index.md`) — trim, update navigation

### Expected Result

| Metric | Before | After |
|--------|--------|-------|
| Files | 48 | ~38 |
| Lines | 17,262 | ~9,000 |
| Framework guides | 8 | 3 (+ "other frameworks" section) |
| Max page length | 1,341 | ~400 |
| Duplicated docker-compose | 13+ places | 1 canonical + links |

### Files Deleted (total: 7)

1. `docs/guides/drupal-guide.md`
2. `docs/guides/magento-guide.md`
3. `docs/guides/typo3-guide.md`
4. `docs/guides/statamic-guide.md`
5. `docs/getting-started/choosing-variant.md`
6. `docs/reference/editions-comparison.md`
7. `docs/reference/multi-service-vs-separate.md`

### Files Created (total: 1)

1. `docs/getting-started/choosing-your-image.md` — merged from choosing-variant + editions-comparison + multi-service-vs-separate
