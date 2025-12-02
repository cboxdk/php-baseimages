---
title: "Multi-Service vs Separate Containers"
description: "Choose between multi-service containers and separate PHP-FPM/Nginx containers for your architecture"
weight: 60
---

# Multi-Service vs Separate Containers

Guide for choosing between PHPeek's multi-service containers (PHP-FPM + Nginx together) and separate single-process containers.

## Quick Decision Guide

| Scenario | Recommendation |
|----------|----------------|
| **Simple deployment** | Multi-service |
| **Docker Compose** | Multi-service |
| **Single server** | Multi-service |
| **Kubernetes** | Separate (usually) |
| **Independent scaling** | Separate |
| **Microservices architecture** | Separate |
| **Enterprise/compliance** | Separate |

## Architecture Comparison

### Multi-Service Container

```
┌─────────────────────────────────────┐
│         Single Container            │
│  ┌─────────────┐ ┌─────────────┐   │
│  │   PHP-FPM   │ │    Nginx    │   │
│  │   :9000     │ │    :80      │   │
│  └─────────────┘ └─────────────┘   │
│         └──── FastCGI ────┘        │
└─────────────────────────────────────┘
```

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html
```

### Separate Containers

```
┌─────────────────┐   ┌─────────────────┐
│   PHP-FPM       │   │     Nginx       │
│   Container     │◄──│    Container    │
│   :9000         │   │    :80          │
└─────────────────┘   └─────────────────┘
        └──────── FastCGI ────────┘
```

```yaml
# docker-compose.yml
services:
  php-fpm:
    image: ghcr.io/gophpeek/baseimages/php-fpm:8.4-alpine
    volumes:
      - ./:/var/www/html

  nginx:
    image: ghcr.io/gophpeek/baseimages/nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html:ro
    depends_on:
      - php-fpm
```

## Feature Comparison

| Feature | Multi-Service | Separate |
|---------|---------------|----------|
| **Simplicity** | Simpler | More complex |
| **Resource Efficiency** | Better (shared memory) | Higher overhead |
| **Scaling** | Scale together | Scale independently |
| **Failure Isolation** | Shared fate | Independent |
| **Debugging** | Easier | More tools needed |
| **12-Factor Compliance** | Partial | Full |
| **Kubernetes Native** | Works | Preferred |
| **Zero-Downtime Deploy** | Harder | Easier |

## Multi-Service: Detailed Analysis

### Advantages

**1. Simplicity**
- Single image to manage
- One container to deploy
- Simpler docker-compose files
- Easier local development

**2. Resource Efficiency**
- Shared filesystem cache
- Lower memory footprint
- No network overhead between processes
- Faster FastCGI communication (localhost)

**3. Easy Coordination**
- Graceful shutdown handled together
- Health checks cover both processes
- Single logging stream (optional)
- Framework auto-detection works seamlessly

**4. Perfect for Small Teams**
- Less infrastructure to manage
- Faster deployments
- Simpler monitoring
- Lower cloud costs

### Disadvantages

**1. Scaling Limitations**
- Can't scale PHP-FPM independently of Nginx
- Must scale both even if only one needs it
- Less efficient for high-traffic scenarios

**2. Deployment Complexity**
- Both processes restart together
- Harder to do rolling updates
- Connection draining more complex

**3. Not "Pure" Containers**
- Violates one-process-per-container guideline
- Some orchestration tools expect single process
- May conflict with enterprise policies

### When to Use Multi-Service

✅ **Perfect for:**
- Local development
- Simple production deployments
- Docker Compose setups
- Small to medium applications
- Teams without dedicated DevOps
- Cost-sensitive environments

❌ **Avoid when:**
- Running in Kubernetes at scale
- Need independent scaling
- Enterprise compliance requirements
- Microservices architecture

## Separate Containers: Detailed Analysis

### Advantages

**1. Independent Scaling**
```yaml
# Scale PHP-FPM independently
services:
  php-fpm:
    deploy:
      replicas: 5  # More PHP workers

  nginx:
    deploy:
      replicas: 2  # Fewer Nginx instances
```

**2. Fault Isolation**
- PHP crash doesn't affect Nginx
- Can restart services independently
- Better failure recovery

**3. 12-Factor Compliance**
- One process per container
- Treats backing services properly
- Easier to reason about

**4. Kubernetes Native**
```yaml
# Kubernetes: Separate pods for each service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-fpm
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
```

**5. Zero-Downtime Deployments**
- Rolling updates per service
- Canary deployments easier
- Blue-green deployments simpler

### Disadvantages

**1. Complexity**
- More containers to manage
- Network configuration needed
- Service discovery required
- More YAML to maintain

**2. Higher Resource Usage**
- Two container runtimes
- Network overhead for FastCGI
- Duplicate health checks

**3. Shared Volume Challenges**
```yaml
# Both containers need access to the same files
volumes:
  app-code:
    driver: local

services:
  php-fpm:
    volumes:
      - app-code:/var/www/html

  nginx:
    volumes:
      - app-code:/var/www/html:ro
```

### When to Use Separate Containers

✅ **Perfect for:**
- Kubernetes production
- High-traffic applications
- Microservices architecture
- Independent scaling needs
- Enterprise environments
- Teams with DevOps experience

❌ **Avoid when:**
- Simple deployments
- Small applications
- Limited DevOps resources
- Local development (unless mirroring prod)

## Migration Guide

### Multi-Service → Separate

**Step 1: Extract Configuration**

```bash
# From multi-service container
docker exec myapp cat /etc/nginx/conf.d/default.conf > nginx.conf
docker exec myapp cat /usr/local/etc/php/conf.d/99-custom.ini > php.ini
```

**Step 2: Update docker-compose.yml**

```yaml
# Before (multi-service)
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# After (separate)
services:
  php-fpm:
    image: ghcr.io/gophpeek/baseimages/php-fpm:8.4-alpine
    volumes:
      - ./:/var/www/html
      - ./php.ini:/usr/local/etc/php/conf.d/99-custom.ini

  nginx:
    image: ghcr.io/gophpeek/baseimages/nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php-fpm
```

**Step 3: Update Nginx Configuration**

```nginx
# Change FastCGI pass from localhost to service name
upstream php-fpm {
    server php-fpm:9000;
}

server {
    location ~ \.php$ {
        fastcgi_pass php-fpm;
        # ... rest of config
    }
}
```

### Separate → Multi-Service

**Step 1: Consolidate Configuration**

Merge Nginx and PHP configurations into the multi-service setup.

**Step 2: Update docker-compose.yml**

```yaml
# Before (separate)
services:
  php-fpm:
    image: ghcr.io/gophpeek/baseimages/php-fpm:8.4-alpine
  nginx:
    image: ghcr.io/gophpeek/baseimages/nginx:alpine

# After (multi-service)
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html
```

**Step 3: Remove Network Configuration**

FastCGI now uses localhost automatically.

## Kubernetes Patterns

### Multi-Service in Kubernetes

Still works, just not "native":

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
        ports:
        - containerPort: 80
```

### Separate in Kubernetes (Sidecar Pattern)

PHP-FPM as sidecar in same pod:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: ghcr.io/gophpeek/baseimages/nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-code
          mountPath: /var/www/html
          readOnly: true

      - name: php-fpm
        image: ghcr.io/gophpeek/baseimages/php-fpm:8.4-alpine
        ports:
        - containerPort: 9000
        volumeMounts:
        - name: app-code
          mountPath: /var/www/html

      volumes:
      - name: app-code
        emptyDir: {}
```

### Separate in Kubernetes (Full Separation)

Different deployments entirely:

```yaml
# php-fpm-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-fpm
spec:
  replicas: 5  # Scale PHP independently
  template:
    spec:
      containers:
      - name: php-fpm
        image: ghcr.io/gophpeek/baseimages/php-fpm:8.4-alpine
---
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2  # Scale Nginx independently
  template:
    spec:
      containers:
      - name: nginx
        image: ghcr.io/gophpeek/baseimages/nginx:alpine
```

## Performance Comparison

### Latency

| Setup | Avg Latency | Notes |
|-------|-------------|-------|
| Multi-service | ~1ms | Localhost FastCGI |
| Separate (same pod) | ~1-2ms | Localhost FastCGI |
| Separate (diff pods) | ~2-5ms | Network FastCGI |

### Memory Usage

| Setup | Memory (per replica) |
|-------|---------------------|
| Multi-service | ~80-120MB |
| Separate (combined) | ~100-150MB |

### Throughput

For most applications, both approaches handle similar throughput. Separate containers excel when:
- PHP processing is the bottleneck (scale PHP-FPM only)
- Static assets dominate (scale Nginx only)

## Decision Matrix

Score each factor 1-5 for your project, multiply by weight:

| Factor | Weight | Multi-Service | Separate |
|--------|--------|---------------|----------|
| Simplicity | 3 | 5 | 2 |
| Scaling Flexibility | 2 | 2 | 5 |
| Resource Efficiency | 2 | 4 | 3 |
| Kubernetes Native | 2 | 3 | 5 |
| Debugging Ease | 1 | 4 | 3 |

**Typical Scores:**
- Small/Medium Projects: Multi-service wins
- Large/Enterprise: Separate wins

---

**Need more guidance?** [Getting Started](../getting-started/quickstart) | [Production Deployment](../guides/production-deployment)
