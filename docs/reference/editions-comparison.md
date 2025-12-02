---
title: "Minimal vs Full Editions"
description: "Complete comparison of Minimal and Full edition features, extensions, and use cases"
weight: 30
---

# Minimal vs Full Editions Comparison

PHPeek Base Images come in two editions optimized for different use cases.

## Quick Decision Guide

**Choose Minimal Edition if:**
- ✅ Building Laravel applications
- ✅ Want smaller images (~30-40% size reduction)
- ✅ Need only essential extensions
- ✅ Prefer to add extensions yourself
- ✅ Optimizing for startup time

**Choose Full Edition if:**
- ✅ Need comprehensive extension coverage
- ✅ Working with legacy applications
- ✅ Require SOAP, LDAP, IMAP, or XML/XSLT
- ✅ Need MongoDB or advanced image processing
- ✅ Want "everything included" approach

## Size Comparison

| Edition | Alpine | Debian |
|---------|--------|--------|
| **Minimal** | ~130MB | ~280MB |
| **Full** | ~200MB | ~450MB |
| **Savings** | -35% | -38% |

## Extensions Comparison

### Core Extensions (Both Editions)

These 17 essential extensions are included in **both** Minimal and Full editions:

| Extension | Purpose | Laravel Usage |
|-----------|---------|---------------|
| `ctype` | Character type checking | ✅ Core requirement |
| `curl` | HTTP requests | ✅ HTTP client, APIs |
| `dom` | XML/HTML parsing | ✅ XML processing |
| `fileinfo` | File type detection | ✅ Upload validation |
| `filter` | Input filtering | ✅ Request validation |
| `hash` | Hashing functions | ✅ Password hashing |
| `mbstring` | Multi-byte strings | ✅ UTF-8 support |
| `openssl` | Cryptography | ✅ Encryption, HTTPS |
| `pcre` | Regex support | ✅ Core requirement |
| `session` | Session handling | ✅ Session management |
| `tokenizer` | Code parsing | ✅ Blade templates |
| `xml` | XML processing | ✅ XML handling |
| `opcache` | Bytecode caching | ⚡ Performance |
| `bcmath` | Arbitrary precision math | ✅ Financial calculations |
| `intl` | Internationalization | ✅ Localization |
| `zip` | ZIP archive support | ✅ Package handling |
| `pcntl` | Process control | ✅ Queue workers |

### Database Extensions (Both Editions)

| Extension | Database | Both Editions |
|-----------|----------|---------------|
| `pdo_mysql` | MySQL/MariaDB | ✅ |
| `pdo_pgsql` | PostgreSQL | ✅ |
| `mysqli` | MySQL (legacy) | ✅ |
| `redis` | Redis cache/queue | ✅ |

### Image Processing (Both Editions)

| Extension | Purpose | Both Editions |
|-----------|---------|---------------|
| `gd` | Basic image manipulation | ✅ |
| `exif` | Image metadata | ✅ |

### Full Edition Exclusive Extensions

These 15 extensions are **only** in the Full edition:

#### Advanced Databases
| Extension | Purpose | Use Case |
|-----------|---------|----------|
| `pgsql` | PostgreSQL (native) | Advanced PG features |
| `mongodb` | MongoDB NoSQL | Modern NoSQL applications |

#### Advanced Image Processing
| Extension | Purpose | Performance |
|-----------|---------|------------|
| `imagick` | ImageMagick | Complex image operations, PDF support |
| `vips` | libvips | 4-10x faster than ImageMagick, low memory |

#### Enterprise Integration
| Extension | Purpose | Common In |
|-----------|---------|-----------|
| `soap` | SOAP web services | Legacy enterprise systems |
| `ldap` | LDAP/Active Directory | Corporate authentication |
| `imap` | Email via IMAP | Email applications |

#### XML & Data Processing
| Extension | Purpose | Use Case |
|-----------|---------|----------|
| `xsl` | XSLT transformations | XML data transformation |
| `sockets` | Low-level networking | Custom protocols |

#### System Integration
| Extension | Purpose | Use Case |
|-----------|---------|----------|
| `calendar` | Calendar functions | Date calculations |
| `gettext` | Localization | GNU gettext translations |
| `bz2` | bzip2 compression | Archive handling |
| `shmop` | Shared memory | IPC operations |
| `sysvmsg` | System V messages | Message queues |
| `sysvsem` | System V semaphores | Process synchronization |
| `sysvshm` | System V shared memory | Shared memory segments |

#### Utilities
| Extension | Purpose | Use Case |
|-----------|---------|----------|
| `apcu` | User cache | Application caching |

### Command-Line Tools

| Tool | Minimal | Full | Purpose |
|------|---------|------|---------|
| `composer` | ✅ | ✅ | Dependency management |
| `redis-cli` | ❌ | ✅ | Redis debugging |
| `exiftool` | ✅ | ✅ | Image metadata extraction |
| `vips` | ✅ | ✅ | High-performance image processing CLI |

## Configuration Differences

### PHP Configuration

**Both Editions** (Production-Ready):
- OPcache: **Enabled by default** (disable via `PHP_OPCACHE_ENABLE=0`)
- JIT: Configured (tracing mode, 100M buffer)
- Memory: 512M default
- Philosophy: Production-optimized out of the box

**Key Difference**:
- **Minimal**: Fewer extensions loaded = lower base memory footprint
- **Full**: More extensions loaded = higher base memory footprint

### Security Features

**Both Editions**:
- ✅ Non-root user execution
- ✅ Minimal attack surface
- ✅ Regular security updates

**Full Edition Additional**:
- ✅ ImageMagick security policy (CVE protection)
- ✅ Disabled dangerous coders (EPHEMERAL, URL, MVG, MSL)
- ✅ Resource limits for image processing

## Use Case Matrix

| Scenario | Recommended Edition | Reason |
|----------|-------------------|--------|
| Laravel API | Minimal | All required extensions included |
| Laravel Full-Stack | Minimal | GD + EXIF sufficient for most apps |
| WordPress | Full | May need ImageMagick for advanced image handling |
| Symfony | Minimal | Core extensions cover typical use |
| Legacy Enterprise App | Full | SOAP, LDAP, IMAP often required |
| Microservice | Minimal | Smaller footprint, faster startup |
| Monolith | Full | Comprehensive coverage |
| Image Processing Service | Full | ImageMagick for comprehensive format support |
| Email Application | Full | IMAP extension required |
| SaaS Platform | Full | Need MongoDB, advanced features |

## Migration Between Editions

### From Minimal → Full

**When to migrate**:
- Adding features requiring exclusive extensions (SOAP, MongoDB, etc.)
- Need advanced image processing (ImageMagick)
- Legacy dependencies discovered

**How to migrate**:
```dockerfile
# Change tag from minimal to full
- image: ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine-minimal
+ image: ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine
```

**Considerations**:
- Image size increase (~70MB)
- More extensions = larger attack surface
- Enable OPcache if not already: `PHP_OPCACHE_ENABLE=1`

### From Full → Minimal

**When to downgrade**:
- Optimization push for container size
- Don't actually use Full-exclusive extensions
- Want explicit control over enabled features

**How to downgrade**:
```dockerfile
# Change tag from full to minimal
- image: ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine
+ image: ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine-minimal
```

**Validation checklist**:
1. Check `composer.json` for extension dependencies
2. Search code for `extension_loaded()` calls
3. Test all features in staging
4. Monitor error logs for missing extensions

## Environment Variable Reference

### Minimal Edition

**Enable OPcache** (recommended for production):
```yaml
environment:
  PHP_OPCACHE_ENABLE: "1"
  PHP_OPCACHE_MEMORY_CONSUMPTION: "256"
  PHP_OPCACHE_JIT: "tracing"
  PHP_OPCACHE_JIT_BUFFER_SIZE: "100M"
```

**Memory Configuration**:
```yaml
environment:
  PHP_MEMORY_LIMIT: "512M"
  PHP_MAX_EXECUTION_TIME: "60"
```

### Full Edition

**Already optimized** - no changes needed for typical use.

**Customize if needed**:
```yaml
environment:
  PHP_OPCACHE_ENABLE: "0"  # Disable if needed
  PHP_MEMORY_LIMIT: "1G"    # Increase if needed
```

## Performance Characteristics

### Startup Time

| Edition | Cold Start | Warm Start | Reason |
|---------|------------|------------|--------|
| Minimal | ~800ms | ~200ms | Fewer extensions to load |
| Full | ~1200ms | ~300ms | More extensions initialized |

### Memory Footprint

| Edition | Base RAM | Per Process | Max Processes (4GB) |
|---------|----------|-------------|---------------------|
| Minimal | 15MB | 30MB | ~130 processes |
| Full | 25MB | 45MB | ~85 processes |

### Build Time

| Edition | Alpine | Debian |
|---------|--------|--------|
| Minimal | ~2min | ~4min |
| Full | ~4min | ~8min |

## Decision Flowchart

```
Do you KNOW you need SOAP, LDAP, IMAP, or MongoDB?
├─ Yes → Full Edition
└─ No
   │
   Do you need advanced image processing (ImageMagick)?
   ├─ Yes → Full Edition
   └─ No
      │
      Are you building a Laravel application?
      ├─ Yes → Minimal Edition ✅
      └─ No
         │
         Do you prefer smaller images and explicit configuration?
         ├─ Yes → Minimal Edition ✅
         └─ No → Full Edition (safer default)
```

## See Also

- [Tagging Strategy](tagging-strategy.md) - How to reference editions in tags
- [Extension List](../analysis/php-extensions-analysis.md) - Complete extension documentation
- [Performance Tuning](../advanced/performance-tuning.md) - Optimize your chosen edition
- [Migration Guide](../troubleshooting/migration-guide.md) - Switching between editions
