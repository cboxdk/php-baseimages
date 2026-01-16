---
title: "Reverse Proxy & mTLS"
description: "Configure Cbox behind Cloudflare, HAProxy, Traefik, Tailscale, Nginx, or Fastly with optional mTLS client certificate authentication"
weight: 15
---

# Reverse Proxy & mTLS Configuration

Production PHP applications typically run behind reverse proxies, load balancers, or CDNs. Cbox includes built-in support for:

- **Reverse Proxy Headers**: Cloudflare, HAProxy, Traefik, Nginx, Fastly, AWS ALB/ELB
- **VPN/Tunnel**: Tailscale, Cloudflare Tunnel, WireGuard
- **mTLS**: Mutual TLS client certificate authentication for zero-trust networks

## Quick Start

### Basic Proxy Configuration

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Trust private network ranges (Docker, Kubernetes)
      NGINX_TRUSTED_PROXIES: "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
```

That's it! Cbox will now:
- Extract the real client IP from `X-Forwarded-For` header
- Pass proxy headers to PHP (`$_SERVER['HTTP_X_FORWARDED_FOR']`, etc.)
- Enable Laravel `TrustProxies` and Symfony `trusted_proxies` to work correctly

## Provider-Specific Configuration

### Cloudflare

Cloudflare uses `CF-Connecting-IP` for the real client IP:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Cloudflare IP ranges (updated January 2025)
      NGINX_TRUSTED_PROXIES: >-
        173.245.48.0/20
        103.21.244.0/22
        103.22.200.0/22
        103.31.4.0/22
        141.101.64.0/18
        108.162.192.0/18
        190.93.240.0/20
        188.114.96.0/20
        197.234.240.0/22
        198.41.128.0/17
        162.158.0.0/15
        104.16.0.0/13
        104.24.0.0/14
        172.64.0.0/13
        131.0.72.0/22
      NGINX_REAL_IP_HEADER: CF-Connecting-IP
```

**Laravel Configuration** (`app/Http/Middleware/TrustProxies.php`):

```php
protected $proxies = '*';  // Trust all proxies (Cloudflare IPs change)
protected $headers = Request::HEADER_X_FORWARDED_FOR;
```

### Cloudflare Tunnel (cloudflared)

For Cloudflare Tunnel, trust private networks since the tunnel runs locally:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      NGINX_TRUSTED_PROXIES: "172.16.0.0/12"
      NGINX_REAL_IP_HEADER: CF-Connecting-IP

  cloudflared:
    image: cloudflare/cloudflared:latest
    command: tunnel run
    environment:
      TUNNEL_TOKEN: ${CLOUDFLARE_TUNNEL_TOKEN}
```

### Traefik

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Trust Traefik container network
      NGINX_TRUSTED_PROXIES: "172.16.0.0/12"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.example.com`)"
      - "traefik.http.services.app.loadbalancer.server.port=80"

  traefik:
    image: traefik:v3.0
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

### HAProxy

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      NGINX_TRUSTED_PROXIES: "172.16.0.0/12"
      # HAProxy typically uses X-Forwarded-For (default)
```

**HAProxy Configuration** (`haproxy.cfg`):

```haproxy
frontend http-in
    bind *:80
    option forwardfor
    default_backend app

backend app
    server app1 app:80 check
```

### Tailscale

Tailscale uses the `100.64.0.0/10` CGNAT range:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      NGINX_TRUSTED_PROXIES: "100.64.0.0/10"
    network_mode: service:tailscale

  tailscale:
    image: tailscale/tailscale:latest
    environment:
      TS_AUTHKEY: ${TAILSCALE_AUTHKEY}
      TS_STATE_DIR: /var/lib/tailscale
    volumes:
      - tailscale-state:/var/lib/tailscale

volumes:
  tailscale-state:
```

### Nginx (External Load Balancer)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      NGINX_TRUSTED_PROXIES: "172.16.0.0/12"
```

**Upstream Nginx Configuration**:

```nginx
upstream app {
    server app:80;
}

server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_pass http://app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Fastly

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Fastly publishes IP ranges at https://api.fastly.com/public-ip-list
      NGINX_TRUSTED_PROXIES: "23.235.32.0/20 43.249.72.0/22 ..."
      NGINX_REAL_IP_HEADER: Fastly-Client-IP
```

### AWS ALB/ELB

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Trust VPC CIDR range
      NGINX_TRUSTED_PROXIES: "10.0.0.0/8"
```

### Kubernetes (Ingress)

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: app
          image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
          env:
            - name: NGINX_TRUSTED_PROXIES
              value: "10.0.0.0/8"  # Pod network CIDR
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_TRUSTED_PROXIES` | *(empty)* | Space-separated list of trusted proxy IPs/CIDRs |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | Header containing the real client IP |
| `NGINX_REAL_IP_RECURSIVE` | `on` | Enable recursive IP extraction (recommended) |

### Common Proxy IP Ranges

| Provider | IP Ranges |
|----------|-----------|
| Docker networks | `172.16.0.0/12` |
| Private networks | `10.0.0.0/8 172.16.0.0/12 192.168.0.0/16` |
| Tailscale | `100.64.0.0/10` |
| Cloudflare | See [cloudflare.com/ips](https://www.cloudflare.com/ips/) |
| Fastly | See [api.fastly.com/public-ip-list](https://api.fastly.com/public-ip-list) |

## What Gets Forwarded to PHP

When `NGINX_TRUSTED_PROXIES` is configured, the following are available in PHP:

```php
// Real client IP (after proxy extraction)
$_SERVER['REMOTE_ADDR'];  // Real client IP, not proxy IP

// Proxy headers (always forwarded)
$_SERVER['HTTP_X_FORWARDED_FOR'];    // Full proxy chain
$_SERVER['HTTP_X_FORWARDED_PROTO'];  // http or https
$_SERVER['HTTP_X_FORWARDED_HOST'];   // Original host
$_SERVER['HTTP_X_FORWARDED_PORT'];   // Original port
$_SERVER['HTTP_X_REAL_IP'];          // Real client IP
```

---

## mTLS (Mutual TLS) Client Authentication

mTLS adds client certificate verification for zero-trust security:

- **Service Mesh**: Istio, Linkerd, Consul Connect
- **Zero-Trust Networks**: BeyondCorp, Tailscale with certificates
- **API Authentication**: Machine-to-machine communication
- **Enterprise Security**: PCI-DSS, HIPAA compliance

### Basic mTLS Setup

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      SSL_MODE: "on"
      MTLS_ENABLED: "true"
      MTLS_CLIENT_CA_FILE: /etc/ssl/certs/client-ca.crt
      MTLS_VERIFY_CLIENT: "optional"  # or "on" for required
      MTLS_VERIFY_DEPTH: "2"
    volumes:
      - ./certs/client-ca.crt:/etc/ssl/certs/client-ca.crt:ro
      - ./certs/server.crt:/etc/ssl/certs/cbox-selfsigned.crt:ro
      - ./certs/server.key:/etc/ssl/private/cbox-selfsigned.key:ro
```

### mTLS Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MTLS_ENABLED` | `false` | Enable mTLS client certificate verification |
| `MTLS_CLIENT_CA_FILE` | `/etc/ssl/certs/client-ca.crt` | CA certificate for client verification |
| `MTLS_VERIFY_CLIENT` | `optional` | `optional`, `on` (required), or `optional_no_ca` |
| `MTLS_VERIFY_DEPTH` | `2` | Maximum certificate chain depth |

### Client Certificate Info in PHP

When mTLS is enabled, client certificate information is available in PHP:

```php
// Check if client presented a valid certificate
if ($_SERVER['SSL_CLIENT_VERIFY'] === 'SUCCESS') {
    $clientDN = $_SERVER['SSL_CLIENT_S_DN'];  // Subject DN
    $issuerDN = $_SERVER['SSL_CLIENT_I_DN'];  // Issuer DN
    $serial = $_SERVER['SSL_CLIENT_SERIAL'];  // Certificate serial
    $fingerprint = $_SERVER['SSL_CLIENT_FINGERPRINT'];  // SHA1 fingerprint

    // Extract CN from DN
    if (preg_match('/CN=([^,]+)/', $clientDN, $matches)) {
        $clientCN = $matches[1];  // e.g., "service-a.internal"
    }
}
```

### Generate Test Certificates

For development/testing:

```bash
# Create CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 \
    -out ca.crt -subj "/CN=Test CA"

# Create server certificate
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=localhost"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt -days 365 -sha256

# Create client certificate
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "/CN=test-client"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out client.crt -days 365 -sha256

# Test with curl
curl --cert client.crt --key client.key --cacert ca.crt https://localhost/api
```

### Service Mesh Integration (Istio)

Istio injects mTLS automatically via sidecar:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    sidecar.istio.io/inject: "true"
spec:
  template:
    spec:
      containers:
        - name: app
          image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
          env:
            # Istio handles TLS termination
            - name: NGINX_TRUSTED_PROXIES
              value: "127.0.0.6"  # Envoy sidecar
```

---

## Framework Integration

### Laravel TrustProxies

Edit `app/Http/Middleware/TrustProxies.php`:

```php
<?php

namespace App\Http\Middleware;

use Illuminate\Http\Middleware\TrustProxies as Middleware;
use Illuminate\Http\Request;

class TrustProxies extends Middleware
{
    // Trust all proxies (Cbox handles IP validation at Nginx level)
    protected $proxies = '*';

    // Standard proxy headers
    protected $headers =
        Request::HEADER_X_FORWARDED_FOR |
        Request::HEADER_X_FORWARDED_HOST |
        Request::HEADER_X_FORWARDED_PORT |
        Request::HEADER_X_FORWARDED_PROTO;
}
```

### Symfony trusted_proxies

Edit `config/packages/framework.yaml`:

```yaml
# config/packages/framework.yaml
framework:
    trusted_proxies: '%env(TRUSTED_PROXIES)%'
    trusted_headers:
        - 'x-forwarded-for'
        - 'x-forwarded-host'
        - 'x-forwarded-proto'
        - 'x-forwarded-port'
```

```yaml
# docker-compose.yml
services:
  app:
    environment:
      TRUSTED_PROXIES: "REMOTE_ADDR"  # Trust immediate proxy (Cbox validated)
```

---

## Security Considerations

### Only Trust Necessary Proxies

```yaml
# ✅ GOOD: Trust specific proxy network
NGINX_TRUSTED_PROXIES: "172.20.0.0/16"

# ⚠️ RISKY: Trust all private networks
NGINX_TRUSTED_PROXIES: "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"

# ❌ BAD: Trust everything (IP spoofing risk)
NGINX_TRUSTED_PROXIES: "0.0.0.0/0"
```

### Keep CDN IP Lists Updated

CDN IP ranges change. Automate updates:

```bash
#!/bin/bash
# update-cloudflare-ips.sh
curl -s https://www.cloudflare.com/ips-v4 | tr '\n' ' ' > /etc/nginx/cloudflare-ips.conf
nginx -s reload
```

### mTLS Best Practices

1. **Rotate certificates regularly** (90 days recommended)
2. **Use separate CA for clients** (not the server CA)
3. **Validate CN/SAN in application** (don't just trust any valid cert)
4. **Set appropriate verify depth** (2-3 for typical hierarchies)
5. **Use `on` instead of `optional`** for strict security

---

## Troubleshooting

### Client IP Not Detected

```bash
# Check Nginx real_ip configuration
docker exec app cat /etc/nginx/conf.d/default.conf | grep -A5 "set_real_ip"

# Expected output:
# set_real_ip_from 172.16.0.0/12;
# real_ip_header X-Forwarded-For;
# real_ip_recursive on;
```

### PHP Not Receiving Headers

```php
// Debug: Print all proxy-related headers
print_r(array_filter($_SERVER, function($key) {
    return strpos($key, 'FORWARD') !== false ||
           strpos($key, 'REAL') !== false ||
           strpos($key, 'SSL_CLIENT') !== false;
}, ARRAY_FILTER_USE_KEY));
```

### mTLS Certificate Rejected

```bash
# Verify certificate chain
openssl verify -CAfile ca.crt client.crt

# Check certificate details
openssl x509 -in client.crt -noout -text

# Test connection
openssl s_client -connect localhost:443 -cert client.crt -key client.key -CAfile ca.crt
```

### SSL_CLIENT_VERIFY is NONE

This means mTLS is not enabled or client didn't present certificate:

```bash
# Check Nginx SSL config
docker exec app cat /etc/nginx/conf.d/default.conf | grep ssl_client

# Expected when MTLS_ENABLED=true:
# ssl_client_certificate /etc/ssl/certs/client-ca.crt;
# ssl_verify_client optional;
```

---

## Common Combinations

### Production with Cloudflare + mTLS API

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Cloudflare for public traffic
      NGINX_TRUSTED_PROXIES: "173.245.48.0/20 103.21.244.0/22 ..."
      NGINX_REAL_IP_HEADER: CF-Connecting-IP

      # mTLS for internal API
      SSL_MODE: "on"
      MTLS_ENABLED: "true"
      MTLS_VERIFY_CLIENT: "optional"  # Required on /api/* routes
    volumes:
      - ./certs:/etc/ssl/certs:ro
```

### Kubernetes with Istio

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Trust Istio sidecar
      NGINX_TRUSTED_PROXIES: "127.0.0.6"
      # Istio handles mTLS
```

### Development with Tailscale

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      NGINX_TRUSTED_PROXIES: "100.64.0.0/10"
    network_mode: service:tailscale
```
