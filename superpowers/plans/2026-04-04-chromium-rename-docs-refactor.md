# Chromium Rename + Docs Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the `full` Docker tier to `chromium` everywhere, then refactor docs to cut volume ~48% while preserving useful content.

**Architecture:** Two sequential phases — rename first (mechanical find-replace), then docs refactor (content editing). Each phase is independent and commitable.

**Tech Stack:** Dockerfiles, GitHub Actions YAML, Markdown

**Spec:** `superpowers/specs/2026-04-04-chromium-rename-docs-refactor-design.md`

---

## Phase 1: `full` → `chromium` Rename

### Task 1: Rename in php-base Dockerfiles

**Files:**
- Modify: `php-base/8.2/debian/bookworm/Dockerfile`
- Modify: `php-base/8.3/debian/bookworm/Dockerfile`
- Modify: `php-base/8.4/debian/bookworm/Dockerfile`
- Modify: `php-base/8.5/debian/bookworm/Dockerfile`

All 4 files have identical structure. Apply the same changes to each:

- [ ] **Step 1: Rename in php-base/8.4 Dockerfile (reference file)**

Use `replace_all` for each substitution. The following replacements are needed in every php-base Dockerfile:

```
"full:" → "chromium:"                          (line ~10, header comment)
"FULL BASE" → "CHROMIUM BASE"                  (section header comment)
"full-base" → "chromium-base"                  (FROM stage name + references)
"Full + Development" → "Chromium + Development" (dev section comment, if present)
"FULL VARIANTS" → "CHROMIUM VARIANTS"          (section header comment)
"full-root" → "chromium-root"                  (stage names)
"full-rootless" → "chromium-rootless"          (stage names)
"CBOX_IMAGE_TIER=full" → "CBOX_IMAGE_TIER=chromium"  (ENV values)
"full tier" → "chromium tier"                  (any comments)
```

Verify after edits: `grep -i 'full' php-base/8.4/debian/bookworm/Dockerfile` should return zero matches except the word "fully" or "default" if present.

- [ ] **Step 2: Apply same changes to 8.2, 8.3, 8.5 Dockerfiles**

Repeat identical replacements for all 3 remaining files. Verify each with grep.

- [ ] **Step 3: Commit**

```bash
git add php-base/
git commit -m "rename: full tier → chromium in php-base Dockerfiles"
```

### Task 2: Rename in downstream Dockerfiles (php-fpm, php-cli, php-fpm-nginx)

**Files:**
- Modify: `php-fpm/{8.2,8.3,8.4,8.5}/debian/bookworm/Dockerfile` (4 files)
- Modify: `php-cli/{8.2,8.3,8.4,8.5}/debian/bookworm/Dockerfile` (4 files)
- Modify: `php-fpm-nginx/{8.2,8.3,8.4,8.5}/debian/bookworm/Dockerfile` (4 files)

- [ ] **Step 1: Rename in php-fpm Dockerfiles**

Each php-fpm Dockerfile has these patterns (using 8.4 as example):
```
"full:" → "chromium:"                                         (header comment)
"base-full" → "base-chromium"                                 (FROM alias + COPY --from references)
"bookworm-full" → "bookworm-chromium"                         (image tag in FROM)
"full-root" → "chromium-root"                                 (stage names)
"full-rootless" → "chromium-rootless"                         (stage names)
"CBOX_IMAGE_TIER=full" → "CBOX_IMAGE_TIER=chromium"
"full tier" → "chromium tier"
```

Apply to all 4 php-fpm version Dockerfiles. Verify: `grep -ri '\bfull\b' php-fpm/` returns no matches.

- [ ] **Step 2: Rename in php-cli Dockerfiles**

Same pattern as php-fpm. The php-cli Dockerfiles reference `php-base` images:
```
"full:" → "chromium:"
"base-full" → "base-chromium"
"bookworm-full" → "bookworm-chromium"
"full-root" → "chromium-root"
"full-rootless" → "chromium-rootless"
"CBOX_IMAGE_TIER=full" → "CBOX_IMAGE_TIER=chromium"
```

Apply to all 4 php-cli version Dockerfiles. Verify: `grep -ri '\bfull\b' php-cli/` returns no matches.

- [ ] **Step 3: Rename in php-fpm-nginx Dockerfiles**

Same pattern. The php-fpm-nginx Dockerfiles reference `php-fpm` images:
```
"full:" → "chromium:"
"base-full" → "base-chromium"
"bookworm-full" → "bookworm-chromium"
"full-root" → "chromium-root"
"full-rootless" → "chromium-rootless"
"CBOX_IMAGE_TIER=full" → "CBOX_IMAGE_TIER=chromium"
```

Apply to all 4 php-fpm-nginx version Dockerfiles. Verify: `grep -ri '\bfull\b' php-fpm-nginx/*/` returns no matches.

- [ ] **Step 4: Commit**

```bash
git add php-fpm/ php-cli/ php-fpm-nginx/
git commit -m "rename: full tier → chromium in downstream Dockerfiles"
```

### Task 3: Rename in GitHub Actions workflows

**Files:**
- Modify: `.github/workflows/build-php-base.yml`
- Modify: `.github/workflows/build-php-fpm.yml`
- Modify: `.github/workflows/build-php-cli.yml`
- Modify: `.github/workflows/build-php-fpm-nginx.yml`
- Modify: `.github/workflows/e2e-tests.yml`
- Modify: `.github/workflows/integration-tests.yml`

- [ ] **Step 1: Rename in build-php-base.yml**

Use `replace_all` for each. Key replacements:
```
"build-full-matrix" → "build-chromium-matrix"
"build-full-rootless-matrix" → "build-chromium-rootless-matrix"
"-full," → "-chromium,"
"-full-rootless" → "-chromium-rootless"
"full-root" → "chromium-root"                    (Docker target names)
"scope=base-${{ matrix.php_version }}-${{ matrix.os_variant }}-full" → "scope=base-${{ matrix.php_version }}-${{ matrix.os_variant }}-chromium"
"Testing full" → "Testing chromium"
"full image" → "chromium image"
"full tier" → "chromium tier"
"(full)" → "(chromium)"
"(full-rootless)" → "(chromium-rootless)"
"trivy-results-full" → "trivy-results-chromium"
```

Also update the input description: `'Image tier to build (slim, standard, full, or all)'` → `'Image tier to build (slim, standard, chromium, or all)'`

Also update the `needs:` line at the bottom: `build-full-matrix, build-full-rootless-matrix` → `build-chromium-matrix, build-chromium-rootless-matrix`

Also update comment: `# All OS variants now support tiered builds (slim, standard, full)` → `(slim, standard, chromium)`

Verify: `grep -i '\bfull\b' .github/workflows/build-php-base.yml` returns only false positives like "fully" or unrelated uses.

- [ ] **Step 2: Rename in build-php-fpm.yml**

Same replacement pattern. Key additions:
```
"build-full-matrix" → "build-chromium-matrix"
"build-full-rootless-matrix" → "build-chromium-rootless-matrix"
"-full" → "-chromium" (in tag contexts)
"full-root" → "chromium-root"
"scope=fpm-*-full" → "scope=fpm-*-chromium"
"Testing full" → "Testing chromium"
"(full)" → "(chromium)"
"(full-rootless)" → "(chromium-rootless)"
"full tier" → "chromium tier"
"trivy-results-full" → "trivy-results-chromium"
```

Update the `needs:` line and comments as in Step 1.

- [ ] **Step 3: Rename in build-php-cli.yml**

Same replacement pattern with `cli-` scope prefix.

- [ ] **Step 4: Rename in build-php-fpm-nginx.yml**

Same replacement pattern with `php-fpm-nginx-` scope prefix. Also:
```
"test-full" → "test-chromium"       (container name in docker run/exec commands)
"latest-${{ matrix.os_variant }}-full" → "latest-${{ matrix.os_variant }}-chromium"
```

- [ ] **Step 5: Rename in e2e-tests.yml and integration-tests.yml**

```
"full-matrix" → "chromium-matrix"
"full tier" → "chromium tier"
"full chain" → "chromium chain"     (if present - check context, may be unrelated)
```

**Important:** The phrase "full chain" in integration-tests.yml may mean "the complete chain" not the tier. Read the context before replacing — only replace if it refers to the tier.

- [ ] **Step 6: Verify and commit**

```bash
grep -ri '\bfull\b' .github/workflows/ | grep -v 'fully\|default\|careful'
```

Review any remaining matches for false positives. Commit:

```bash
git add .github/workflows/
git commit -m "rename: full tier → chromium in CI workflows"
```

### Task 4: Rename in README, CLAUDE.md, templates, tests, examples

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `templates/README.md`
- Modify: `templates/Dockerfile.node`
- Modify: `tests/e2e/scenarios/test-browsershot.sh`
- Modify: `tests/e2e/scenarios/test-env-config.sh`
- Modify: `tests/e2e/fixtures/env-config/docker-compose.yml`
- Modify: `tests/unit/run-matrix-tests.sh`
- Modify: `tests/integration/framework-detection/docker-test.sh`
- Modify: `tests/integration/framework-detection/test-runner.sh`
- Modify: `tests/integration/framework-detection/README.md`
- Modify: `tests/benchmarks/README.md`
- Modify: `examples/README.md`
- Modify: `examples/symfony-basic/README.md`
- Modify: `DOCUMENTATION-GUIDE.md`
- Modify: `docs/changelog.md`

- [ ] **Step 1: Rename in README.md**

Replace all `full` tier references:
```
"bookworm-full" → "bookworm-chromium"
"Full" → "Chromium" (in tier tables/descriptions — be careful with generic "full" usage)
"-full" → "-chromium" (in tag examples)
```

Read the file first to check context of each "full" usage.

- [ ] **Step 2: Rename in CLAUDE.md**

Same pattern — update tier references in the project documentation section.

- [ ] **Step 3: Rename in templates, tests, examples**

Apply `replace_all` of `-full` → `-chromium` and `full` → `chromium` in tier contexts for all remaining files listed above. Read each file first to verify context.

- [ ] **Step 4: Rename in docs/changelog.md**

Update any tier references from "full" to "chromium".

- [ ] **Step 5: Verify no remaining "full" tier references**

```bash
grep -ri '\bfull\b' --include='*.md' --include='*.yml' --include='*.yaml' --include='*.sh' --include='*.conf' . | grep -v 'superpowers/specs\|node_modules\|\.git/' | grep -v 'fully\|default\|careful\|full-stack'
```

Review any remaining matches. They should only be unrelated uses of the word "full".

- [ ] **Step 6: Commit**

```bash
git add README.md CLAUDE.md templates/ tests/ examples/ DOCUMENTATION-GUIDE.md docs/changelog.md
git commit -m "rename: full tier → chromium in docs, tests, templates, examples"
```

### Task 5: Rename in all remaining docs files

**Files:** All docs/ files that reference the `full` tier (found via grep earlier — ~20 files including reference pages, guides, advanced topics, troubleshooting, index files)

- [ ] **Step 1: Bulk rename in docs/**

For every file in `docs/` (excluding `superpowers/specs/`), replace:
```
"bookworm-full" → "bookworm-chromium"
"-full" → "-chromium" (in tag/image contexts)
"Full" → "Chromium" (in tier tables and descriptions — NOT generic usage like "full support")
"CBOX_IMAGE_TIER=full" → "CBOX_IMAGE_TIER=chromium"
"full tier" → "chromium tier"
```

Read each file before editing to verify context. Key files:
- `docs/reference/available-images.md` — tag tables
- `docs/reference/available-extensions.md` — tier comparison tables
- `docs/reference/tagging-strategy.md` — tag format examples
- `docs/reference/quick-reference.md` — quick reference tables
- `docs/reference/environment-variables.md` — CBOX_IMAGE_TIER values
- `docs/getting-started/choosing-variant.md` — tier descriptions
- `docs/getting-started/choosing-an-image.md` — tier descriptions
- `docs/_index.md` — landing page tier table
- `docs/guides/laravel-guide.md`, `symfony-guide.md`, `wordpress-guide.md` — tier mentions
- `docs/advanced/security-hardening.md`, `rootless-containers.md`, `performance-tuning.md`, `testing-guide.md` — tier mentions
- `docs/troubleshooting/common-issues.md`, `debugging-guide.md` — tier mentions
- `docs/guides/image-processing.md` — tier mentions

- [ ] **Step 2: Verify and commit**

```bash
grep -ri '\bfull\b' docs/ | grep -v 'superpowers/specs\|fully\|full-stack\|full support\|full list\|full path\|full control\|full access'
```

Review remaining matches for false positives.

```bash
git add docs/
git commit -m "rename: full tier → chromium in all documentation"
```

---

## Phase 2: Docs Refactor

### Task 6: Fix landing page (`docs/_index.md`)

**Files:**
- Modify: `docs/_index.md` (290 → ~100 lines)

- [ ] **Step 1: Read current content**

Read `docs/_index.md` fully to understand all sections.

- [ ] **Step 2: Rewrite landing page**

Replace the entire file with a trimmed version:

```markdown
---
title: "Cbox PHP Base Images"
description: "Production-ready PHP Docker containers with Cbox Init process manager"
weight: 1
---

New to Cbox? Start with these guides:

1. [5-Minute Quickstart](getting-started/quickstart) - Get running in 5 minutes
2. [Choosing Your Image](getting-started/choosing-your-image) - Pick the right tier and variant
3. [Laravel Guide](guides/laravel-guide) - Full Laravel setup (most popular)

## Image Tiers

| Tier | Tag Suffix | Size | Best For |
|------|-----------|------|----------|
| **Slim** | `-slim` | ~120 MiB | APIs, microservices |
| **Standard** | _(none)_ | ~250 MiB | Most apps (DEFAULT) |
| **Chromium** | `-chromium` | ~700 MiB | Browsershot, Dusk, PDF |
| **Dev** | `-dev` | ~800 MiB | Local development only |

```yaml
# Standard tier (DEFAULT) - Most Laravel/PHP apps
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Slim tier - APIs, microservices
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim

# Chromium tier - Browsershot, Dusk, PDF generation
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium
```

## Documentation

### Getting Started
- [Quickstart](getting-started/quickstart) - 5-minute setup
- [Introduction](getting-started/introduction) - What Cbox PHP Base Images are
- [Choosing Your Image](getting-started/choosing-your-image) - Tiers, variants, sizing

### Framework Guides
- [Laravel](guides/laravel-guide) | [Symfony](guides/symfony-guide) | [WordPress](guides/wordpress-guide)
- [Queue Workers](guides/queue-workers) | [Image Processing](guides/image-processing)

### Operations
- [Production Deployment](guides/production-deployment) | [Development Workflow](guides/development-workflow)
- [Performance Tuning](advanced/performance-tuning) | [Security Hardening](advanced/security-hardening)

### Reference
- [Available Images](reference/available-images) | [Extensions](reference/available-extensions)
- [Environment Variables](reference/environment-variables) | [Configuration](reference/configuration-options)
- [Health Checks](reference/health-checks) | [Tagging Strategy](reference/tagging-strategy)

### Help
- [Common Issues](troubleshooting/common-issues) | [Debugging](troubleshooting/debugging-guide) | [Migration](troubleshooting/migration-guide)
- [FAQ](getting-started/faq) | [Changelog](changelog)
```

Note: Remove the duplicate H1 (the `# Cbox Base Images Documentation` heading). The frontmatter `title` handles the page heading.

- [ ] **Step 3: Commit**

```bash
git add docs/_index.md
git commit -m "refactor: trim landing page, rebrand to Cbox PHP Base Images"
```

### Task 7: Create `choosing-your-image.md` (merge 3 pages)

**Files:**
- Read: `docs/getting-started/choosing-variant.md` (315 lines)
- Read: `docs/getting-started/choosing-an-image.md` (187 lines)
- Read: `docs/reference/editions-comparison.md` (260 lines)
- Read: `docs/reference/multi-service-vs-separate.md` (459 lines)
- Create: `docs/getting-started/choosing-your-image.md` (~200 lines)

- [ ] **Step 1: Read all 4 source files**

Read each file fully to extract the useful, non-duplicated content.

- [ ] **Step 2: Write the merged page**

Create `docs/getting-started/choosing-your-image.md`. Structure inspired by ServersideUp's image matrix — lead with scannable tables, minimize prose:

```markdown
---
title: "Choosing Your Image"
description: "Pick the right Cbox PHP base image for your project — tiers, variants, and sizing"
weight: 3
---

## Image Size Matrix

### php-fpm-nginx (multi-service)

| Image | Tier | Size |
|-------|------|------|
| `php-fpm-nginx:8.5-bookworm-slim` | Slim | ~120 MiB |
| `php-fpm-nginx:8.5-bookworm` | Standard | ~250 MiB |
| `php-fpm-nginx:8.5-bookworm-chromium` | Chromium | ~700 MiB |
| `php-fpm-nginx:8.4-bookworm-slim` | Slim | ~120 MiB |
| `php-fpm-nginx:8.4-bookworm` | Standard | ~250 MiB |
| `php-fpm-nginx:8.4-bookworm-chromium` | Chromium | ~700 MiB |
| `php-fpm-nginx:8.3-bookworm-slim` | Slim | ~120 MiB |
| `php-fpm-nginx:8.3-bookworm` | Standard | ~250 MiB |
| `php-fpm-nginx:8.3-bookworm-chromium` | Chromium | ~700 MiB |
| `php-fpm-nginx:8.2-bookworm-slim` | Slim | ~120 MiB |
| `php-fpm-nginx:8.2-bookworm` | Standard | ~250 MiB |
| `php-fpm-nginx:8.2-bookworm-chromium` | Chromium | ~700 MiB |

### php-fpm (single-service)

| Image | Tier | Size |
|-------|------|------|
| `php-fpm:8.5-bookworm-slim` | Slim | ~100 MiB |
| `php-fpm:8.5-bookworm` | Standard | ~230 MiB |
| `php-fpm:8.5-bookworm-chromium` | Chromium | ~680 MiB |
| ... | ... | ... |

### php-cli

| Image | Tier | Size |
|-------|------|------|
| `php-cli:8.5-bookworm-slim` | Slim | ~100 MiB |
| `php-cli:8.5-bookworm` | Standard | ~230 MiB |
| `php-cli:8.5-bookworm-chromium` | Chromium | ~680 MiB |
| ... | ... | ... |

> **Note:** Sizes are approximate compressed sizes. Actual sizes should be verified by building locally.

## Tiers

**Slim** (`-slim`) — Core PHP extensions only. Use for APIs, microservices, queue workers, or any app that doesn't need image processing or Node.js.

**Standard** (no suffix, DEFAULT) — Adds ImageMagick, libvips, and Node.js. Use for most Laravel, Symfony, and WordPress apps.

**Chromium** (`-chromium`) — Adds headless Chromium. Use if your app needs Browsershot, Laravel Dusk, Puppeteer, or server-side PDF generation.

**Dev** (`-dev`) — Adds Xdebug, PCOV, and SPX profiler. Use for local development only — never in production.

## Root vs Rootless

Every tier comes in two variants:

| Variant | Tag | Runs as | Use when |
|---------|-----|---------|----------|
| Root | `8.4-bookworm` | `root` | Default, most flexible |
| Rootless | `8.4-bookworm-rootless` | `www-data` | Security-hardened, Kubernetes |

Rootless images can't bind to ports below 1024 or modify system files at runtime.

## Multi-Service vs Single-Service

| Approach | Images | Use when |
|----------|--------|----------|
| **Multi-service** | `php-fpm-nginx` | Simpler deployment, fewer containers. Recommended for most apps. |
| **Single-service** | `php-fpm` + `nginx` + `php-cli` | Kubernetes, independent scaling, microservices. |

Multi-service images include [Cbox Init](../cbox-init-integration) as PID 1 process manager, handling PHP-FPM and Nginx together with health checks and graceful shutdown.
```

Adapt the actual content by extracting the best parts from the 4 source files. Keep the total under 200 lines.

- [ ] **Step 3: Delete the 3 source files that are replaced**

```bash
git rm docs/getting-started/choosing-variant.md
git rm docs/reference/editions-comparison.md
git rm docs/reference/multi-service-vs-separate.md
```

Keep `docs/getting-started/choosing-an-image.md` — check if it overlaps significantly with the new page. If so, delete it too. If it has unique content, update it to link to the new page instead.

- [ ] **Step 4: Update all internal links**

Search for links to the deleted files and update them:
```bash
grep -r 'choosing-variant\|editions-comparison\|multi-service-vs-separate' docs/ --include='*.md'
```

Replace with links to `choosing-your-image`.

- [ ] **Step 5: Commit**

```bash
git add docs/
git commit -m "refactor: merge tier/variant selection into choosing-your-image.md"
```

### Task 8: Delete 4 niche framework guides

**Files:**
- Delete: `docs/guides/drupal-guide.md`
- Delete: `docs/guides/magento-guide.md`
- Delete: `docs/guides/typo3-guide.md`
- Delete: `docs/guides/statamic-guide.md`
- Modify: `docs/guides/_index.md`

- [ ] **Step 1: Delete the 4 files**

```bash
git rm docs/guides/drupal-guide.md docs/guides/magento-guide.md docs/guides/typo3-guide.md docs/guides/statamic-guide.md
```

- [ ] **Step 2: Add "Other Frameworks" section to guides/_index.md**

Read `docs/guides/_index.md`, then add a short section:

```markdown
## Other Frameworks

These frameworks work out of the box with Cbox PHP Base Images:

- **Statamic** — Runs on Laravel. Use the [Laravel Guide](laravel-guide).
- **Drupal / TYPO3 / Magento** — Use the standard tier with the [Quickstart](../getting-started/quickstart). No framework-specific configuration needed.
```

Also remove any navigation links to the deleted guides from this index.

- [ ] **Step 3: Remove links to deleted guides from other docs**

```bash
grep -r 'drupal-guide\|magento-guide\|typo3-guide\|statamic-guide' docs/ --include='*.md'
```

Update or remove any links found.

- [ ] **Step 4: Commit**

```bash
git add docs/guides/
git commit -m "refactor: remove niche framework guides, add Other Frameworks section"
```

### Task 9: Trim `security-hardening.md` (1,341 → ~400 lines)

**Files:**
- Modify: `docs/advanced/security-hardening.md`

- [ ] **Step 1: Read the full file**

Read `docs/advanced/security-hardening.md` and identify:
- Verbose example configs that duplicate official documentation (e.g., full nginx TLS configs, full PHP security configs)
- Generic security advice not specific to Cbox images
- Sections that can be replaced with links to authoritative sources

- [ ] **Step 2: Trim to ~400 lines**

Keep:
- Cbox-specific security recommendations (image hardening, rootless, health checks)
- Quick-reference security checklists
- Environment variable security settings specific to these images

Remove:
- Full nginx TLS configuration examples (link to Mozilla SSL Config Generator instead)
- Generic PHP security hardening (link to php.net security docs)
- Full Kubernetes security policy examples (link to K8s docs)
- Verbose CVE scanning tutorials (already covered in CI workflows)

Replace removed sections with brief summaries + links to authoritative sources.

- [ ] **Step 3: Commit**

```bash
git add docs/advanced/security-hardening.md
git commit -m "refactor: trim security-hardening.md from 1341 to ~400 lines"
```

### Task 10: Trim `production-deployment.md` (889 → ~400 lines)

**Files:**
- Modify: `docs/guides/production-deployment.md`

- [ ] **Step 1: Read and identify duplication**

Read `docs/guides/production-deployment.md` and identify:
- Docker-compose examples duplicated from quickstart
- Tier selection content duplicated from choosing-your-image
- Generic Docker best practices not specific to Cbox

- [ ] **Step 2: Trim to ~400 lines**

Keep:
- Production-specific configuration (health checks, logging, scaling)
- Deployment checklists
- Rollback strategies
- Cbox Init production configuration

Remove/replace with links:
- Full docker-compose examples → link to [Quickstart](../getting-started/quickstart)
- Tier selection guidance → link to [Choosing Your Image](../getting-started/choosing-your-image)
- Generic Docker security → link to [Security Hardening](../advanced/security-hardening)

- [ ] **Step 3: Commit**

```bash
git add docs/guides/production-deployment.md
git commit -m "refactor: trim production-deployment.md from 889 to ~400 lines"
```

### Task 11: Trim `development-workflow.md` (847 → ~400 lines)

**Files:**
- Modify: `docs/guides/development-workflow.md`

- [ ] **Step 1: Read and identify overlap**

Read `docs/guides/development-workflow.md` and identify:
- Basic setup content duplicated from quickstart
- Troubleshooting content duplicated from debugging-guide
- Generic Docker development advice

- [ ] **Step 2: Trim to ~400 lines**

Keep:
- Xdebug configuration for IDEs (PHPStorm, VS Code)
- Hot reload setup
- Dev tier usage and configuration
- Local development docker-compose patterns specific to dev workflow

Remove/replace with links:
- Basic Docker setup → link to [Quickstart](../getting-started/quickstart)
- Debugging techniques → link to [Debugging Guide](../troubleshooting/debugging-guide)
- Generic Docker Compose tutorial content

- [ ] **Step 3: Commit**

```bash
git add docs/guides/development-workflow.md
git commit -m "refactor: trim development-workflow.md from 847 to ~400 lines"
```

### Task 12: Eliminate duplicated content across remaining docs

**Files:**
- Modify: `docs/guides/laravel-guide.md` — trim duplicated docker-compose
- Modify: `docs/guides/symfony-guide.md` — trim duplicated docker-compose
- Modify: `docs/guides/wordpress-guide.md` — trim duplicated docker-compose
- Modify: `docs/reference/quick-reference.md` — remove duplicated tier content
- Modify: `docs/getting-started/faq.md` — trim duplicated content
- Modify: `docs/getting-started/introduction.md` — trim slightly
- Modify: Various index files (`_index.md`)

- [ ] **Step 1: Trim framework guides**

For each framework guide (Laravel, Symfony, WordPress):
1. Read the file
2. Replace full docker-compose examples with framework-specific snippets only + link to quickstart for the base setup
3. Replace "use service names not localhost" explanations with link to [Common Issues](../troubleshooting/common-issues)
4. Keep only framework-specific content (scheduler setup, artisan commands, etc.)

- [ ] **Step 2: Trim quick-reference.md**

Read `docs/reference/quick-reference.md`. Remove tier selection tables/descriptions that are now in `choosing-your-image.md`. Keep only the quick command reference.

- [ ] **Step 3: Trim FAQ and introduction**

- `docs/getting-started/faq.md` — remove answers that duplicate other pages, replace with links
- `docs/getting-started/introduction.md` — remove tier comparison content (now in choosing-your-image)

- [ ] **Step 4: Update index files**

Update all `_index.md` files:
- `docs/getting-started/_index.md` — update nav links (remove choosing-variant, add choosing-your-image)
- `docs/reference/_index.md` — remove editions-comparison, multi-service-vs-separate from nav
- `docs/guides/_index.md` — remove deleted framework guides from nav
- `docs/advanced/_index.md` — trim if needed
- `docs/troubleshooting/_index.md` — trim if needed

- [ ] **Step 5: Commit**

```bash
git add docs/
git commit -m "refactor: eliminate duplicated content across docs"
```

### Task 13: Apply "Cbox PHP Base Images" branding consistently

**Files:**
- Modify: `README.md` — title/heading
- Modify: `CLAUDE.md` — project description
- Modify: `docs/_index.md` — already done in Task 6
- Modify: `docs/getting-started/introduction.md` — heading/references
- Modify: Any other files using "Cbox Base Images" without "PHP"

- [ ] **Step 1: Find all branding instances**

```bash
grep -ri 'cbox base images' --include='*.md' . | grep -v 'superpowers/specs'
```

- [ ] **Step 2: Update to "Cbox PHP Base Images"**

Replace "Cbox Base Images" → "Cbox PHP Base Images" everywhere (except where context already has "PHP" adjacent, e.g., "Cbox PHP base images" is fine).

Be careful with:
- The README title and badges
- CLAUDE.md project overview section
- docs/getting-started/introduction.md title

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "refactor: consistent 'Cbox PHP Base Images' branding"
```

### Task 14: Final verification

- [ ] **Step 1: Verify no stale "full" tier references**

```bash
grep -ri '\bfull\b' --include='*.md' --include='*.yml' --include='*.yaml' --include='*.sh' --include='Dockerfile' . | grep -v 'superpowers/specs\|node_modules\|\.git/' | grep -v 'fully\|full-stack\|full support\|full list\|full path\|full control\|full access\|full set\|full compatibility'
```

- [ ] **Step 2: Verify no broken internal links**

```bash
grep -roh '\[.*\](.*\.md)' docs/ | grep -oP '\(.*?\)' | sort -u | while read link; do
  file=$(echo "$link" | tr -d '()')
  # Check if referenced files exist (relative to docs/)
  echo "Checking: $file"
done
```

- [ ] **Step 3: Verify deleted files have no remaining references**

```bash
grep -r 'drupal-guide\|magento-guide\|typo3-guide\|statamic-guide\|choosing-variant\|editions-comparison\|multi-service-vs-separate' docs/ --include='*.md'
```

Should return zero matches.

- [ ] **Step 4: Count final docs stats**

```bash
find docs/ -name '*.md' -not -path '*/superpowers/*' | wc -l
find docs/ -name '*.md' -not -path '*/superpowers/*' -exec cat {} + | wc -l
find docs/ -name '*.md' -not -path '*/superpowers/*' -exec wc -l {} + | sort -rn | head -5
```

Verify: ~38 files, ~9k lines, no file over ~400 lines (except reference lookup pages which are tables).

- [ ] **Step 5: Final commit if any fixes needed**

```bash
git add .
git commit -m "fix: resolve stale references from chromium rename + docs refactor"
```
