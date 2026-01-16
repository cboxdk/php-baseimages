# Cbox Documentation Guide

This guide explains how to structure documentation for Cbox packages to ensure optimal display and navigation on cbox.com.

## Core Concepts

### Major Version Management
- Cbox displays ONE entry per major version (v1, v2, v3)
- System automatically tracks the latest release within each major version
- URLs use major version: `/docs/{package}/v1`, `/docs/{package}/v2`
- When you release v1.2.1 after v1.2.0, the website updates automatically

### Files NOT Used on Cbox.com

**README.md - GitHub Only**
- ⚠️ README.md is **NEVER** displayed on Cbox.com
- README.md is only for GitHub repository display
- All documentation must be in the `/docs` folder
- Do NOT reference README.md in your docs

**Files Used on Cbox.com**
- All `.md` files in the `/docs` folder
- All image/asset files within `/docs`
- `_index.md` files for directory landing pages (optional but recommended)

## Directory Structure

### Recommended Structure
```
docs/
├── introduction.md              # What is this package?
├── installation.md              # How to install
├── quickstart.md               # 5-minute getting started
├── basic-usage/                # Core features
│   ├── _index.md              # Optional: Section overview
│   ├── feature-one.md
│   └── feature-two.md
├── advanced-usage/             # Complex scenarios
│   ├── _index.md
│   └── advanced-feature.md
├── api-reference.md            # Complete API docs
└── testing.md                  # How to test
```

### Directory Naming Rules
- ✅ Use lowercase with hyphens: `basic-usage/`, `advanced-features/`
- ✅ Keep names short: `api-reference/`, `platform-support/`
- ✅ Max 2-3 levels of nesting
- ❌ Don't use spaces or special characters
- ❌ Don't create deeply nested structures (>3 levels)

## Metadata (Frontmatter)

### Required Fields
Every `.md` file **MUST** have frontmatter with `title` and `description`:

```yaml
---
title: "Page Title"           # REQUIRED
description: "Brief summary"  # REQUIRED
weight: 99                    # OPTIONAL (default: 99)
hidden: false                 # OPTIONAL (default: false)
---
```

### How Metadata Is Used

**Title**
- Navigation sidebar link text
- Page header `<h1>` tag
- Browser tab title
- SEO meta tags
- Social media sharing

**Description**
- SEO meta description
- Search engine result snippets
- Social media preview text
- May influence click-through rate

**Weight**
- Controls navigation order (lower = first)
- Default is 99
- Same weight = alphabetical by title
- Only affects current directory

**Hidden**
- Set to `true` to hide from navigation
- Page still accessible via direct URL
- Useful for drafts or deprecated content

### Metadata Best Practices

**Title Guidelines**
```yaml
# ✅ Good titles
title: "CPU Metrics"
title: "Error Handling"
title: "API Reference"

# ❌ Avoid
title: "Page 1"                    # Generic
title: "System Metrics CPU Stuff"  # Too long, redundant
title: "cpu-metrics"               # Not Title Case
```

**Description Guidelines**
```yaml
# ✅ Good descriptions (60-160 chars, action-oriented)
description: "Get raw CPU time counters and per-core metrics from the system"
description: "Master the Result<T> pattern for explicit error handling"
description: "Monitor resource usage for individual processes or process groups"

# ❌ Avoid
description: "This page describes CPU metrics"  # Too generic
description: "CPU stuff"                        # Too vague
description: "A very long description that goes on and on..."  # Too long (>160 chars)
```

**Weight Organization**
```yaml
# Recommended weight ranges:
1-10:   Critical pages (introduction, installation, quickstart)
11-30:  Common features (basic usage)
31-70:  Advanced features
71-99:  Reference material (API docs, appendices)

# Example:
# docs/introduction.md
weight: 1

# docs/installation.md
weight: 2

# docs/quickstart.md
weight: 3

# docs/basic-usage/cpu-metrics.md
weight: 10
```

## Links and URLs

### Internal Documentation Links

Use **relative paths** to link between documentation pages:

```markdown
# Link to sibling file in same directory
[Installation Guide](installation)

# Link to file in parent directory
[Back to Introduction](../introduction)

# Link to file in subdirectory
[CPU Metrics](basic-usage/cpu-metrics)

# Link to file in different subdirectory
[Platform Comparison](../platform-support/comparison)

# Link with anchor to heading
[Error Handling](advanced-usage/error-handling#result-pattern)
```

**Link Best Practices**
- ✅ Use descriptive link text: `[View API Reference](api-reference)`
- ✅ Don't remove `.md` extension: `[Guide](installation.md)` not `[Guide](installation)`
- ✅ Use relative paths: `[Guide](../guide)`
- ❌ Don't use generic text: `[Click here](guide)` or `[Read more](docs)`
- ❌ Don't hardcode absolute URLs: `[Guide](/docs/package/v1/guide)`
- ❌ Don't link to README.md (it's not displayed)

### External Links

```markdown
# Always use full URLs with https://
[GitHub Repository](https://github.com/owner/repo)
[Official Website](https://example.com)

# ✅ Good
[Documentation](https://example.com/docs)

# ❌ Avoid
[Documentation](example.com/docs)  # Missing https://
```

## Images and Assets

### Image References

Use **relative paths** for images:

```markdown
# Image in same directory
![Performance Chart](performance.png)

# Image in subdirectory
![Diagram](images/architecture.png)

# Image in parent images folder
![Logo](../images/logo.svg)

# Image with alt text and tooltip
![Chart](chart.png "CPU Performance Over Time")
```

**Image Best Practices**
- ✅ Always include alt text: `![Diagram](image.png)` not `![](image.png)`
- ✅ Use relative paths
- ✅ Organize in `/docs/images/` or feature-specific folders
- ✅ Supported formats: `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`
- ❌ Don't use absolute URLs
- ❌ Don't reference images outside `/docs` folder

### Asset Organization

```
docs/
├── images/              # Shared images
│   ├── logo.png
│   └── architecture.svg
├── basic-usage/
│   ├── cpu-chart.png   # Feature-specific image
│   └── cpu-metrics.md
└── screenshots/         # UI screenshots
    └── dashboard.png
```

## Code Blocks

### Syntax Highlighting

Always specify the language after the opening fence:

````markdown
```php
use Cbox\SystemMetrics\SystemMetrics;

$cpu = SystemMetrics::cpu()->get();
echo "Cores: {$cpu->cores}\n";
```
````

**Supported Languages**
- PHP, JavaScript, Bash, JSON, YAML, XML, HTML, Markdown, SQL, Dockerfile

**Code Block Best Practices**
````markdown
# ✅ Good - Language specified
```php
$metrics = SystemMetrics::cpu()->get();
```

# ❌ Avoid - No language
```
$metrics = SystemMetrics::cpu()->get();
```
````

## Index Files (_index.md)

### Purpose
- Creates landing pages for directory sections
- Provides section overview
- Optional but recommended for better UX

### When to Use

**✅ Create _index.md for:**
- Major sections with 3+ child pages
- Directories needing explanation
- Sections requiring custom intro text

**❌ Skip _index.md for:**
- Simple directories with 1-2 pages
- Self-explanatory sections

### Example _index.md

```markdown
---
title: "Basic Usage"
description: "Essential features for getting started with the package"
weight: 1
---

# Basic Usage

This section covers the fundamental features you'll use daily:

- CPU and memory monitoring
- Disk usage tracking
- Network statistics
- System uptime

Start with the "System Overview" guide for a quick introduction.
```

## Complete Example

**File**: `docs/basic-usage/cpu-metrics.md`

```markdown
---
title: "CPU Metrics"
description: "Get raw CPU time counters and per-core metrics from the system"
weight: 10
---

# CPU Metrics

Monitor CPU usage and performance with real-time metrics.

## Getting CPU Statistics

```php
use Cbox\SystemMetrics\SystemMetrics;

$cpu = SystemMetrics::cpu()->get();

echo "CPU Cores: {$cpu->cores}\n";
echo "User Time: {$cpu->user}ms\n";
echo "System Time: {$cpu->system}ms\n";
```

## Per-Core Metrics

```php
foreach ($cpu->perCore as $core) {
    echo "Core {$core->id}: {$core->usage}%\n";
}
```

## Performance Considerations

![CPU Performance Chart](../images/cpu-performance.png)

The metrics collection is highly optimized:
- No system calls for static data
- Efficient caching for hardware info
- Minimal overhead (<1ms per call)

See [Performance Caching](../architecture/performance-caching) for details.

## Platform Support

- ✅ Linux: Full support via `/proc/stat`
- ✅ macOS: Full support via `host_processor_info()`

See [Platform Comparison](../platform-support/comparison) for detailed differences.
```

## Quality Checklist

Before publishing, verify:

### Metadata
- [ ] Every `.md` file has `title` and `description`
- [ ] Titles are unique and descriptive (Title Case)
- [ ] Descriptions are 60-160 characters
- [ ] Weight values create logical ordering
- [ ] No generic titles like "Page 1", "Document"

### Structure
- [ ] Major sections have `_index.md` files
- [ ] Directory nesting is shallow (max 2-3 levels)
- [ ] File names use lowercase-with-hyphens
- [ ] Directory names are short and descriptive

### Content
- [ ] Code blocks specify language
- [ ] Images have alt text
- [ ] Links use relative paths
- [ ] No references to README.md
- [ ] All internal links tested

### Files
- [ ] All documentation in `/docs` folder
- [ ] No absolute URLs for internal content
- [ ] Images stored within `/docs` directory
- [ ] No spaces or special characters in filenames

## Troubleshooting

### Navigation Not Showing
- Check frontmatter exists and is valid YAML
- Verify `title` and `description` are present
- Ensure file has `.md` extension
- Confirm `hidden: false` (or field omitted)
- Verify file is in `/docs` folder (not root)

### Images Not Loading
- Use relative paths: `![](../images/file.png)`
- Verify image exists in repository
- Check file extension is supported
- Ensure image is within `/docs` directory

### Wrong Page Order
- Add `weight` to frontmatter
- Lower numbers appear first (1, 2, 3...)
- Default weight is 99
- Same weight = alphabetical by title

### Code Not Highlighting
- Specify language: \`\`\`php not just \`\`\`
- Supported: php, js, bash, json, yaml, xml, html, md, sql, dockerfile
- Check spelling of language name
- Ensure code block is properly closed

## URL Structure

Your documentation will be available at:

```
https://cbox.com/docs/{package}/{major_version}/{page_path}

Examples:
/docs/system-metrics/v1/introduction
/docs/system-metrics/v1/basic-usage/cpu-metrics
/docs/system-metrics/v2/advanced-usage/custom-implementations
```

**How URLs Are Generated**
```
File: docs/basic-usage/cpu-metrics.md
URL:  /docs/system-metrics/v1/basic-usage/cpu-metrics

File: docs/introduction.md
URL:  /docs/system-metrics/v1/introduction
```

## SEO Tips

**Title Impact**
- Shown in Google search results
- Used in social media shares
- Displayed in browser tabs
- Should be unique and descriptive

**Description Impact**
- Shown as snippet in search results
- Used in social media previews
- Should be 120 characters ideal
- Should explain page value to users

**Best Practices**
- ✅ Unique title per page
- ✅ Descriptive URLs (via good filenames)
- ✅ 60-160 character descriptions
- ✅ Include relevant keywords naturally
- ❌ Don't stuff keywords
- ❌ Don't use duplicate titles
- ❌ Don't create duplicate content
