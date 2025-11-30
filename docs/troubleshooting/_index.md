---
title: "Help & Troubleshooting"
description: "Get help with PHPeek base images - common issues, systematic debugging, and migration guides"
weight: 40
---

# Help & Troubleshooting

Solutions to common issues and systematic approaches to debugging PHPeek containers.

## Available Resources

### Quick Solutions

- **[Common Issues](common-issues)** ⭐ Start here!
  - FAQ-style solutions
  - Copy-paste fixes
  - Quick diagnostics
  - Most common problems and solutions

### Systematic Debugging

- **[Debugging Guide](debugging-guide)**
  - Step-by-step debugging process
  - Log analysis techniques
  - Performance profiling
  - Advanced troubleshooting

### Migration Help

- **[Migration Guide](migration-guide)**
  - From ServerSideUp images
  - From Bitnami images
  - From custom images
  - Framework-specific migrations

## Quick Diagnosis

### Container Won't Start

```bash
# Check logs
docker-compose logs app

# Common causes:
# - Port already in use
# - Volume permission issues
# - Invalid configuration
# - Missing dependencies
```

→ See [Common Issues - Container Problems](common-issues#container-problems)

### Application Not Accessible

```bash
# Verify container is running
docker-compose ps

# Check port mapping
docker-compose port app 80

# Test locally
docker-compose exec app curl http://localhost
```

→ See [Common Issues - Connection Problems](common-issues#connection-problems)

### PHP Errors

```bash
# View PHP error log
docker-compose logs app | grep -i error

# Check PHP-FPM status
docker-compose exec app ps aux | grep php-fpm

# Verify PHP configuration
docker-compose exec app php -i | grep error
```

→ See [Common Issues - PHP Problems](common-issues#php-problems)

### Database Connection Failed

```bash
# Check database is running
docker-compose ps mysql

# Test connection from app
docker-compose exec app nc -zv mysql 3306

# Common causes:
# - Wrong DB_HOST (should be service name, not 'localhost')
# - Database not ready yet
# - Wrong credentials
```

→ See [Common Issues - Database Problems](common-issues#database-problems)

## Getting Help

### Before Asking for Help

1. **Check logs**: `docker-compose logs -f app`
2. **Search common issues**: Read [Common Issues](common-issues)
3. **Try debugging guide**: Follow [Debugging Guide](debugging-guide)
4. **Search GitHub**: Check [existing issues](https://github.com/phpeek/baseimages/issues)

### When Asking for Help

Include this information:

```bash
# PHPeek version
docker inspect ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine | grep Created

# Docker version
docker version

# Docker Compose version
docker-compose version

# OS information
uname -a  # Linux/macOS
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"  # Windows

# Container logs
docker-compose logs app > logs.txt

# docker-compose.yml (sanitize secrets first!)
```

### Support Channels

- **Documentation Issues**: [GitHub Issues](https://github.com/phpeek/baseimages/issues) (label: documentation)
- **Bug Reports**: [GitHub Issues](https://github.com/phpeek/baseimages/issues) (label: bug)
- **Questions**: [GitHub Discussions](https://github.com/phpeek/baseimages/discussions)
- **Security Issues**: [GitHub Security Advisories](https://github.com/phpeek/baseimages/security)

## Common Problem Categories

### Container Issues
- Container won't start
- Container exits immediately
- Port conflicts
- Permission denied errors
- Volume mount issues

### Application Issues
- 502 Bad Gateway
- 504 Gateway Timeout
- White screen / no output
- PHP errors displayed
- Static assets not loading

### Database Issues
- Can't connect to database
- Connection refused
- Authentication failed
- Database not ready
- Migration failures

### Performance Issues
- Slow response times
- High memory usage
- High CPU usage
- OPcache issues
- PHP-FPM process problems

### Development Issues
- Xdebug not working
- Hot-reload not working
- File permission errors
- Composer install failures
- Asset compilation issues

## Documentation Navigation

### By Experience Level

**Junior Developer:**
1. Start with [Common Issues](common-issues)
2. If not found, try [Debugging Guide](debugging-guide)
3. Check framework guides: [Laravel](../guides/laravel-guide) | [Symfony](../guides/symfony-guide)

**Experienced Developer:**
1. [Debugging Guide](debugging-guide) for systematic approach
2. [Performance Tuning](../advanced/performance-tuning) for optimization
3. [Configuration Options](../reference/configuration-options) for deep customization

**DevOps / SRE:**
1. [Production Deployment](../guides/production-deployment) for deployment issues
2. [Security Hardening](../advanced/security-hardening) for security concerns
3. [Performance Tuning](../advanced/performance-tuning) for optimization

### By Problem Type

**"Something is broken"** → [Common Issues](common-issues)

**"Need to understand why"** → [Debugging Guide](debugging-guide)

**"Moving from another solution"** → [Migration Guide](migration-guide)

**"Performance is slow"** → [Performance Tuning](../advanced/performance-tuning)

**"Security concerns"** → [Security Hardening](../advanced/security-hardening)

## Contributing

Found a solution not documented here?

1. Check [Contributing Guide](../../CONTRIBUTING.md)
2. Submit documentation PR
3. Share in [GitHub Discussions](https://github.com/phpeek/baseimages/discussions/categories/show-and-tell)

---

**Can't find what you're looking for?** Ask in [GitHub Discussions](https://github.com/phpeek/baseimages/discussions).
