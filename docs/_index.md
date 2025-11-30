---
title: "PHPeek Base Images Documentation"
description: "Comprehensive documentation for PHPeek base images - clean, minimal, production-ready PHP Docker containers"
weight: 1
---

# PHPeek Base Images Documentation

Welcome to the comprehensive documentation for PHPeek base images! This documentation is designed to help developers of all levels get started quickly and master advanced usage.

## 🎯 Start Here

**New to PHPeek?** Start with these guides:

1. **[5-Minute Quickstart](getting-started/quickstart)** - Get running in 5 minutes
2. **[Complete Laravel Guide](guides/laravel-guide)** - Full Laravel setup (most popular)
3. **[Extending Images](advanced/extending-images)** - Customize for your needs

## 📚 Documentation Structure

### Getting Started

Perfect for beginners and those evaluating PHPeek.

- **[5-Minute Quickstart](getting-started/quickstart)** ⭐ Start here!
- [Introduction](getting-started/introduction) - Why PHPeek? Comparisons
- [Installation](getting-started/installation) - All installation methods
- [Choosing a Variant](getting-started/choosing-variant) - Alpine vs Debian vs Ubuntu

### Framework Guides

Step-by-step guides for popular PHP frameworks.

- **[Laravel Complete Guide](guides/laravel-guide)** ⭐ Most popular
  - Full setup with MySQL, Redis, Scheduler
  - Development and production configurations
  - Common mistakes and solutions

- [Symfony Complete Guide](guides/symfony-guide)
  - Complete Symfony setup with database
  - Cache and session configuration
  - Production deployment

- [WordPress Complete Guide](guides/wordpress-guide)
  - WordPress with MySQL setup
  - Plugin and theme development
  - Production optimization

- [Development Workflow](guides/development-workflow)
  - Local development with Xdebug
  - Hot-reload setup
  - Debugging tips

- [Production Deployment](guides/production-deployment)
  - Security hardening
  - Performance optimization
  - Deployment strategies

### Advanced Topics

Deep dives for experienced users customizing PHPeek.

- **[Extending Images](advanced/extending-images)** ⭐ Most requested
  - Add custom PHP extensions
  - Install system packages
  - Custom configurations
  - Initialization scripts

- [Custom Extensions](advanced/custom-extensions)
  - PECL extension examples
  - Compiling from source
  - Version pinning

- [Custom Initialization](advanced/custom-initialization)
  - Startup script patterns
  - Wait for dependencies
  - Database migrations

- [Performance Tuning](advanced/performance-tuning)
  - PHP-FPM optimization
  - OPcache configuration
  - Nginx tuning

- [Security Hardening](advanced/security-hardening)
  - Security best practices
  - CVE management
  - Secrets management

### Reference Documentation

Complete technical reference materials.

- **[Quick Reference](reference/quick-reference)** ⭐ Copy-paste snippets
  - Minimal setups for all frameworks
  - Common environment variables
  - Quick commands

- [Environment Variables](reference/environment-variables)
  - Complete env var list
  - Laravel-specific variables
  - Symfony-specific variables

- [Configuration Options](reference/configuration-options)
  - PHP.ini customization
  - PHP-FPM pool configuration
  - Nginx server blocks

- [Available Extensions](reference/available-extensions)
  - Complete extension list (40+)
  - Extension usage examples
  - Version information

- [Health Checks](reference/health-checks)
  - Health check internals
  - Monitoring integration
  - Custom health checks

- [Multi-Service vs Separate](reference/multi-service-vs-separate)
  - Architecture decision guide
  - When to use each
  - Trade-offs explained

### Help & Troubleshooting

Solutions to common issues and systematic debugging.

- [Common Issues](troubleshooting/common-issues)
  - FAQ-style solutions
  - Copy-paste fixes
  - Quick diagnostics

- [Debugging Guide](troubleshooting/debugging-guide)
  - Systematic debugging process
  - Log analysis
  - Performance profiling

- [Migration Guide](troubleshooting/migration-guide)
  - From ServerSideUp images
  - From Bitnami images
  - From custom images

- **[Changelog](changelog)** - What's new in each release

## 🔍 Find What You Need

### By Role

**Junior Developer / First Time User:**
1. [5-Minute Quickstart](getting-started/quickstart)
2. [Laravel Guide](guides/laravel-guide) or your framework
3. [Common Issues](troubleshooting/common-issues)

**Experienced Developer:**
1. [Extending Images](advanced/extending-images)
2. [Custom Extensions](advanced/custom-extensions)
3. [Performance Tuning](advanced/performance-tuning)

**DevOps / SRE:**
1. [Production Deployment](guides/production-deployment)
2. [Security Hardening](advanced/security-hardening)
3. [Health Checks](reference/health-checks)

**Team Lead / Architect:**
1. [Multi-Service vs Separate](reference/multi-service-vs-separate)
2. [Introduction](getting-started/introduction) (comparisons)
3. [Choosing a Variant](getting-started/choosing-variant)

### By Task

**"I want to get started quickly"**
→ [5-Minute Quickstart](getting-started/quickstart)

**"I need to add a PHP extension"**
→ [Extending Images](advanced/extending-images)

**"My Laravel app won't connect to MySQL"**
→ [Laravel Guide - Common Mistakes](guides/laravel-guide#common-mistakes-and-how-to-avoid-them)

**"How do I deploy to production?"**
→ [Production Deployment](guides/production-deployment)

**"Something is broken, I need help"**
→ [Common Issues](troubleshooting/common-issues)

**"Alpine vs Debian vs Ubuntu?"**
→ [Choosing a Variant](getting-started/choosing-variant)

**"Single container or separate containers?"**
→ [Multi-Service vs Separate](reference/multi-service-vs-separate)

**"How do I debug Xdebug?"**
→ [Development Workflow](guides/development-workflow)

## 📋 Documentation Status

### ✅ Complete (All Phases)

**Phase 1 - Foundation**
- ✅ 5-Minute Quickstart
- ✅ Laravel Complete Guide
- ✅ Extending Images Guide
- ✅ Slim README with navigation

**Phase 2 - Framework & Reference**
- ✅ Symfony Complete Guide
- ✅ WordPress Complete Guide
- ✅ Environment Variables Reference
- ✅ Configuration Options Reference

**Phase 3 - Advanced Topics**
- ✅ Production Deployment Guide
- ✅ Development Workflow Guide
- ✅ Performance Tuning Guide
- ✅ Security Hardening Guide

**Phase 4 - Troubleshooting**
- ✅ Common Issues FAQ
- ✅ Debugging Guide
- ✅ Migration Guide
- ✅ Troubleshooting Index

**Phase 5 - Extended Reference**
- ✅ Introduction (Why PHPeek?)
- ✅ Installation Guide
- ✅ Choosing a Variant (Alpine vs Debian vs Ubuntu)
- ✅ Custom Extensions Guide
- ✅ Custom Initialization Guide
- ✅ Reverse Proxy & mTLS Guide

### 📅 Future Enhancements
- 📝 Available Extensions Reference (detailed)
- 📝 Health Checks Reference (detailed)

## 🤝 Contributing to Documentation

Found a typo? Want to add examples? We welcome documentation improvements!

**Quick fixes:**
- Click "Edit this page" on any doc
- Make your changes
- Submit a pull request

**New pages:**
1. Check [Documentation Plan](DOCUMENTATION_PLAN.md)
2. Follow the [Style Guide](STYLE_GUIDE.md)
3. Submit a pull request

## 📖 Documentation Principles

Our documentation follows these principles:

1. **Copy-Paste Ready** - All examples work without modification
2. **Progressive Complexity** - Start simple, add details progressively
3. **Real Explanations** - Explain WHY, not just WHAT
4. **Inline Troubleshooting** - Common mistakes included with solutions
5. **Expected Output** - Show what success looks like
6. **Tested Examples** - Every code snippet is tested

Inspired by ServerSideUp's excellent documentation standards.

## 💬 Get Help

- **Documentation Issues:** [GitHub Issues](https://github.com/phpeek/baseimages/issues) (label: documentation)
- **General Questions:** [GitHub Discussions](https://github.com/phpeek/baseimages/discussions)
- **Security Issues:** [GitHub Security Advisories](https://github.com/phpeek/baseimages/security)

---

**Ready to dive in?** → [5-Minute Quickstart](getting-started/quickstart) 🚀
