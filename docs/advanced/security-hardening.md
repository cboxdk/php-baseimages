---
title: "Security Hardening Guide"
description: "Comprehensive security best practices for PHPeek containers including CVE management, secrets handling, and production hardening"
weight: 23
---

# Security Hardening Guide

Complete security hardening guide for PHPeek containers in production environments.

## Built-in Security Features

PHPeek base images come with enterprise-grade security features enabled by default:

### Nginx Security (Default Configuration)

| Feature | Status | Description |
|---------|--------|-------------|
| Server version hidden | ✅ Enabled | `server_tokens off` - Nginx version not exposed |
| Security headers | ✅ Enabled | X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, CSP, Referrer-Policy |
| Health endpoint restricted | ✅ Enabled | `/health` only accessible from localhost (127.0.0.1) |
| Sensitive files blocked | ✅ Enabled | `.env`, `.git`, `composer.json`, `artisan`, `vendor/`, etc. return 404 |
| Hidden files blocked | ✅ Enabled | All `/.` paths return 404 |
| Upload directory protection | ✅ Enabled | PHP execution blocked in upload directories |

### SSL/TLS Security (When Enabled)

| Feature | Default | Description |
|---------|---------|-------------|
| Key strength | RSA 4096 | Strong key generation for self-signed certificates |
| Protocols | TLSv1.2, TLSv1.3 | Modern protocols only (TLSv1.0/1.1 disabled) |
| Cipher suite | Mozilla Modern | ECDHE-based ciphers with forward secrecy |
| HSTS | Enabled | 1 year max-age with includeSubDomains |
| Session tickets | Disabled | Enhanced security for session resumption |

### Entrypoint Security

| Feature | Status | Description |
|---------|--------|-------------|
| Input validation | ✅ Enabled | Boolean values and paths validated |
| Path traversal protection | ✅ Enabled | `..` sequences blocked in file paths |
| Template injection prevention | ✅ Enabled | `envsubst` used instead of `eval` |
| Signal handling | ✅ Enabled | Graceful shutdown on SIGTERM/SIGINT/SIGQUIT |

### Files Blocked by Default

```
/.env                    # Environment secrets
/.git/*                  # Git repository
/.svn/*                  # Subversion repository
/.htaccess               # Apache config (shouldn't exist)
/.htpasswd               # Password files
/composer.json           # PHP dependencies
/composer.lock           # Dependency lock
/package.json            # Node dependencies
/package-lock.json       # Node lock
/yarn.lock               # Yarn lock
/Dockerfile              # Build instructions
/docker-compose.yml      # Compose config
/artisan                 # Laravel CLI
/vendor/*                # PHP dependencies
/node_modules/*          # Node dependencies
/storage/logs/*          # Laravel logs
/storage/debugbar/*      # Debug data
/tests/*                 # Test files
```

## Table of Contents

- [Security Checklist](#security-checklist)
- [PHP Security Configuration](#php-security-configuration)
- [Nginx Security Headers](#nginx-security-headers)
- [Secrets Management](#secrets-management)
- [Container Security](#container-security)
- [Network Security](#network-security)
- [CVE Management](#cve-management)
- [Security Monitoring](#security-monitoring)

## Security Checklist

### ✅ Before Production

- [ ] Disable PHP error display
- [ ] Restrict dangerous PHP functions
- [ ] Enable HTTPS/TLS
- [ ] Security headers configured
- [ ] Secrets stored securely (not in git)
- [ ] Container runs as non-root
- [ ] File permissions correct
- [ ] Rate limiting enabled
- [ ] Firewall rules configured
- [ ] Security monitoring active
- [ ] CVE scanning enabled
- [ ] Backup encryption enabled

## PHP Security Configuration

### Disable Error Display

```yaml
services:
  app:
    environment:
      # Never display errors in production
      - PHP_DISPLAY_ERRORS=Off
      - PHP_DISPLAY_STARTUP_ERRORS=Off
      - PHP_LOG_ERRORS=On
      - PHP_ERROR_LOG=/proc/self/fd/2
```

### Restrict Dangerous Functions

**Create `docker/php/security.ini`:**

```ini
[Security]
; Disable dangerous functions
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source,phpinfo

; Hide PHP version
expose_php = Off

; Prevent remote file inclusion
allow_url_fopen = Off
allow_url_include = Off

; Restrict file access
open_basedir = /var/www/html:/tmp

; Session security
session.cookie_httponly = 1
session.cookie_secure = 1
session.cookie_samesite = "Strict"
session.use_strict_mode = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.gc_maxlifetime = 1800

; Upload security
file_uploads = On
upload_tmp_dir = /tmp
upload_max_filesize = 10M
max_file_uploads = 5

; SQL injection protection
magic_quotes_gpc = Off
```

**Mount in docker-compose.yml:**

```yaml
services:
  app:
    volumes:
      - ./docker/php/security.ini:/usr/local/etc/php/conf.d/zz-security.ini:ro
```

### Content Security Policy

PHPeek includes a **configurable Content-Security-Policy header** via environment variable:

**Default CSP (enabled by default):**

```bash
NGINX_HEADER_CSP="default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'self'"
```

**Customize via docker-compose.yml:**

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    environment:
      # Strict CSP for high-security applications
      - NGINX_HEADER_CSP=default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'

      # Or allow specific CDNs
      - NGINX_HEADER_CSP=default-src 'self'; script-src 'self' https://cdn.example.com; style-src 'self' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' https://api.example.com
```

**Disable CSP entirely (not recommended):**

```yaml
environment:
  - NGINX_HEADER_CSP=
```

**Laravel middleware alternative** (for dynamic CSP per-route):

```php
// Laravel middleware
public function handle($request, Closure $next)
{
    $response = $next($request);

    $response->headers->set('Content-Security-Policy',
        "default-src 'self'; " .
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.example.com; " .
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " .
        "font-src 'self' https://fonts.gstatic.com; " .
        "img-src 'self' data: https:; " .
        "connect-src 'self' https://api.example.com;"
    );

    return $response;
}
```

## Nginx Security Headers

### Complete Security Headers

**Create `docker/nginx/security-headers.conf`:**

```nginx
# Prevent clickjacking
add_header X-Frame-Options "SAMEORIGIN" always;

# Prevent MIME sniffing
add_header X-Content-Type-Options "nosniff" always;

# Enable XSS protection
add_header X-XSS-Protection "1; mode=block" always;

# Referrer policy
add_header Referrer-Policy "no-referrer-when-downgrade" always;

# Content Security Policy
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;" always;

# HSTS (only with HTTPS)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Permissions Policy (formerly Feature-Policy)
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

# Hide Nginx version
server_tokens off;
```

**Include in server block:**

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    include /etc/nginx/security-headers.conf;

    # ... rest of configuration
}
```

### Rate Limiting

```nginx
# Define rate limit zones
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;

# Connection limiting
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

server {
    # General rate limit
    limit_req zone=general burst=20 nodelay;
    limit_conn conn_limit 10;

    # Strict limit for login
    location /login {
        limit_req zone=login burst=2 nodelay;
        # ... proxy/fastcgi config
    }

    # API rate limit
    location /api/ {
        limit_req zone=api burst=50;
        # ... proxy/fastcgi config
    }
}
```

### Block Common Attacks

```nginx
# Block SQL injection attempts
location ~ (union|select|from|where|concat|delete|update|insert) {
    deny all;
}

# Block file injection attempts
location ~ \.(sql|bak|old|backup|swp)$ {
    deny all;
}

# Block hidden files
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}

# Block access to sensitive files
location ~ /(composer\.json|composer\.lock|package\.json|\.env) {
    deny all;
}

# Prevent execution of scripts in uploads
location ~* ^/uploads/.*\.(php|php5|php7|phtml)$ {
    deny all;
}
```

## Secrets Management

### Environment Variables (Basic)

**Never commit secrets to git!**

```bash
# .env (gitignored)
APP_KEY=base64:your-key-here
DB_PASSWORD=your-secure-password
REDIS_PASSWORD=your-redis-password
```

**Add to `.gitignore`:**

```
.env
.env.*
!.env.example
*.key
*.pem
```

### Docker Secrets (Docker Swarm)

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    secrets:
      - app_key
      - db_password
      - redis_password
    environment:
      - APP_KEY_FILE=/run/secrets/app_key
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - REDIS_PASSWORD_FILE=/run/secrets/redis_password

secrets:
  app_key:
    external: true
  db_password:
    external: true
  redis_password:
    external: true
```

**Create secrets:**

```bash
# From file
docker secret create app_key app_key.txt

# From stdin
echo "your-secret" | docker secret create db_password -

# Random password
openssl rand -base64 32 | docker secret create redis_password -
```

**Read secrets in application:**

```php
// Laravel - config/database.php
'password' => file_exists(env('DB_PASSWORD_FILE'))
    ? trim(file_get_contents(env('DB_PASSWORD_FILE')))
    : env('DB_PASSWORD'),
```

### Kubernetes Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  app-key: "base64:your-key-here"
  db-password: "your-secure-password"
```

```bash
# Create from file
kubectl create secret generic app-secrets \
  --from-file=app-key=./app-key.txt \
  --from-file=db-password=./db-password.txt
```

```yaml
# Use in deployment
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: APP_KEY
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: app-key
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
```

### HashiCorp Vault Integration

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    environment:
      - VAULT_ADDR=https://vault.example.com
      - VAULT_TOKEN=${VAULT_TOKEN}
```

```php
// Fetch secrets from Vault
use Vault\Client;

$client = new Client([
    'base_uri' => env('VAULT_ADDR'),
    'token' => env('VAULT_TOKEN'),
]);

$secret = $client->read('secret/data/myapp');
$dbPassword = $secret['data']['db_password'];
```

## Container Security

### Run as Non-Root User

PHPeek images already run as non-root by default:

```bash
# Verify non-root
docker exec <container> whoami
# Output: www-data (Debian/Ubuntu) or nginx (Alpine)

# Check user ID
docker exec <container> id
# Output: uid=82(www-data) gid=82(www-data)
```

### Read-Only Root Filesystem

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    read_only: true
    tmpfs:
      - /tmp
      - /var/run
      - /var/cache/nginx
    volumes:
      - ./:/var/www/html:ro  # Read-only application code
      - app-storage:/var/www/html/storage  # Writable storage only
```

### Drop Unnecessary Capabilities

```yaml
services:
  app:
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if binding to port <1024
      - CHOWN
      - SETGID
      - SETUID
```

### Security Scanning

**Trivy (Container Vulnerability Scanner):**

```bash
# Scan image for vulnerabilities
trivy image ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

# Scan with severity filter
trivy image --severity HIGH,CRITICAL ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

# Fail CI on vulnerabilities
trivy image --exit-code 1 --severity CRITICAL ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
```

**Integrate in CI/CD:**

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
  push:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

## Network Security

### Firewall Rules (iptables)

```bash
# Allow only necessary ports
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -j DROP

# Rate limiting
iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --set
iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 60 --hitcount 20 -j DROP
```

### Docker Network Isolation

```yaml
services:
  app:
    networks:
      - frontend
      - backend

  mysql:
    networks:
      - backend  # Not exposed to frontend

  redis:
    networks:
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access
```

### TLS/SSL Configuration

**Generate self-signed certificate (dev):**

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/ssl/key.pem \
  -out docker/nginx/ssl/cert.pem \
  -subj "/CN=localhost"
```

**Nginx SSL configuration:**

```nginx
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com;

    # SSL certificates
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # SSL protocols and ciphers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;

    # SSL session cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Diffie-Hellman parameters
    ssl_dhparam /etc/nginx/ssl/dhparam.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # ... rest of configuration
}
```

**Generate DH parameters:**

```bash
openssl dhparam -out docker/nginx/ssl/dhparam.pem 2048
```

### Let's Encrypt with Certbot

```yaml
services:
  certbot:
    image: certbot/certbot:latest
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

  app:
    volumes:
      - ./certbot/conf:/etc/nginx/ssl:ro
      - ./certbot/www:/var/www/certbot:ro
```

```bash
# Initial certificate
docker-compose run --rm certbot certonly --webroot \
  -w /var/www/certbot \
  -d example.com \
  --email admin@example.com \
  --agree-tos \
  --no-eff-email
```

## CVE Management

### Weekly Security Updates

PHPeek images are automatically rebuilt weekly (Mondays 03:00 UTC) to include:
- Latest upstream base image patches
- PHP security updates
- OS security updates

**Stay up to date:**

```bash
# Pull latest image
docker pull ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

# Rebuild and restart
docker-compose build --pull
docker-compose up -d
```

### Automated CVE Scanning with Trivy

[Trivy](https://trivy.dev/) is a comprehensive security scanner that detects vulnerabilities in:
- OS packages (Alpine, Debian, Ubuntu)
- Application dependencies (Composer, npm, etc.)
- Container images and configuration issues
- Misconfigurations and secrets

#### Local Scanning

**Install Trivy:**

```bash
# macOS
brew install trivy

# Linux
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install trivy

# Docker (no installation)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest
```

**Scan your images:**

```bash
# Scan PHPeek Alpine image
trivy image ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

# Scan with severity filter (only HIGH and CRITICAL)
trivy image --severity HIGH,CRITICAL ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

# Scan and exit with error if vulnerabilities found
trivy image --exit-code 1 --severity CRITICAL ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

# Scan your custom image
docker build -t my-app:latest .
trivy image --severity HIGH,CRITICAL my-app:latest

# Generate JSON report
trivy image --format json --output trivy-report.json ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

# Generate HTML report (requires template)
trivy image --format template --template "@contrib/html.tpl" --output trivy-report.html ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
```

**Compare OS variants:**

```bash
# Alpine
trivy image --severity HIGH,CRITICAL ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

# Debian
trivy image --severity HIGH,CRITICAL ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-debian

# Ubuntu
trivy image --severity HIGH,CRITICAL ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-ubuntu
```

#### CI/CD Integration

**GitHub Actions (Basic):**

```yaml
# .github/workflows/cve-scan.yml
name: CVE Scanning

on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:  # Manual trigger

jobs:
  scan:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t my-app:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'my-app:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Fail on CRITICAL vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'my-app:${{ github.sha }}'
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL'

      - name: Notify on Slack
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Critical CVE found in production image!'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

**GitHub Actions (Advanced with Summary):**

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 2 AM
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  trivy-scan:
    name: Trivy Security Scan
    runs-on: ubuntu-latest

    strategy:
      matrix:
        os: [alpine, debian, ubuntu]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build ${{ matrix.os }} image
        run: |
          docker build -t phpeek-test:${{ matrix.os }} \
            -f php-fpm-nginx/8.3/${{ matrix.os }}/Dockerfile .

      - name: Run Trivy scan - ${{ matrix.os }}
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'phpeek-test:${{ matrix.os }}'
          format: 'json'
          output: 'trivy-${{ matrix.os }}.json'
          severity: 'UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL'

      - name: Generate security summary
        run: |
          echo "# Security Scan Results - ${{ matrix.os }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          # Extract counts by severity
          CRITICAL=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' trivy-${{ matrix.os }}.json)
          HIGH=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="HIGH")] | length' trivy-${{ matrix.os }}.json)
          MEDIUM=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' trivy-${{ matrix.os }}.json)
          LOW=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="LOW")] | length' trivy-${{ matrix.os }}.json)

          echo "| Severity | Count |" >> $GITHUB_STEP_SUMMARY
          echo "|----------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| 🔴 CRITICAL | $CRITICAL |" >> $GITHUB_STEP_SUMMARY
          echo "| 🟠 HIGH | $HIGH |" >> $GITHUB_STEP_SUMMARY
          echo "| 🟡 MEDIUM | $MEDIUM |" >> $GITHUB_STEP_SUMMARY
          echo "| 🟢 LOW | $LOW |" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          # Show detailed table for CRITICAL and HIGH
          if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
            echo "## Critical & High Vulnerabilities" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY
            docker run --rm aquasec/trivy image --severity CRITICAL,HIGH --format table phpeek-test:${{ matrix.os }} >> $GITHUB_STEP_SUMMARY || true
          fi

      - name: Upload scan results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: trivy-results-${{ matrix.os }}
          path: trivy-${{ matrix.os }}.json

      - name: Check for CRITICAL vulnerabilities
        run: |
          CRITICAL=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' trivy-${{ matrix.os }}.json)
          if [ "$CRITICAL" -gt 0 ]; then
            echo "❌ Found $CRITICAL CRITICAL vulnerabilities!"
            exit 1
          fi
          echo "✅ No CRITICAL vulnerabilities found"
```

**GitLab CI:**

```yaml
# .gitlab-ci.yml
security_scan:
  stage: test
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_DRIVER: overlay2
    TRIVY_VERSION: latest
  before_script:
    - apk add --no-cache curl
    - curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
  script:
    - docker build -t $CI_PROJECT_NAME:$CI_COMMIT_SHA .
    - trivy image --exit-code 0 --severity HIGH,CRITICAL $CI_PROJECT_NAME:$CI_COMMIT_SHA
    - trivy image --format json --output trivy-report.json $CI_PROJECT_NAME:$CI_COMMIT_SHA
  artifacts:
    reports:
      container_scanning: trivy-report.json
    when: always
    expire_in: 30 days
```

**Jenkins Pipeline:**

```groovy
// Jenkinsfile
pipeline {
    agent any

    environment {
        IMAGE_NAME = "phpeek-app"
        IMAGE_TAG = "${env.BUILD_ID}"
    }

    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    sh """
                        docker run --rm \
                          -v /var/run/docker.sock:/var/run/docker.sock \
                          aquasec/trivy:latest image \
                          --exit-code 1 \
                          --severity CRITICAL,HIGH \
                          --format json \
                          --output trivy-report.json \
                          ${IMAGE_NAME}:${IMAGE_TAG}
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json'
                }
            }
        }
    }
}
```

#### Pre-Deployment Scanning

**Docker Compose Integration:**

Create `scripts/security-check.sh`:

```bash
#!/bin/bash
set -e

IMAGE="${1:-ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine}"

echo "🔍 Running security scan on: $IMAGE"

# Run Trivy scan
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image \
  --severity HIGH,CRITICAL \
  --format table \
  "$IMAGE"

# Check for CRITICAL vulnerabilities
CRITICAL_COUNT=$(docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image \
  --severity CRITICAL \
  --format json \
  "$IMAGE" | jq '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length')

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "❌ Found $CRITICAL_COUNT CRITICAL vulnerabilities!"
  echo "⚠️  Please update the base image or address vulnerabilities before deploying."
  exit 1
fi

echo "✅ Security scan passed!"
```

```bash
chmod +x scripts/security-check.sh

# Run before deployment
./scripts/security-check.sh my-app:latest
```

#### Continuous Monitoring

**Scheduled Scans:**

```yaml
# .github/workflows/scheduled-security-scan.yml
name: Scheduled Security Scan

on:
  schedule:
    # Daily at 3 AM UTC
    - cron: '0 3 * * *'
  workflow_dispatch:

jobs:
  scan-production-images:
    name: Scan Production Images
    runs-on: ubuntu-latest

    strategy:
      matrix:
        environment: [production, staging]

    steps:
      - name: Login to registry
        run: echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login -u "${{ secrets.REGISTRY_USERNAME }}" --password-stdin

      - name: Pull production image
        run: docker pull registry.example.com/app:${{ matrix.environment }}

      - name: Scan for vulnerabilities
        run: |
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --severity HIGH,CRITICAL \
            --format json \
            --output trivy-${{ matrix.environment }}.json \
            registry.example.com/app:${{ matrix.environment }}

      - name: Check thresholds
        run: |
          CRITICAL=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' trivy-${{ matrix.environment }}.json)
          HIGH=$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="HIGH")] | length' trivy-${{ matrix.environment }}.json)

          if [ "$CRITICAL" -gt 0 ]; then
            echo "::error::Found $CRITICAL CRITICAL vulnerabilities in ${{ matrix.environment }}"
            exit 1
          fi

          if [ "$HIGH" -gt 10 ]; then
            echo "::warning::Found $HIGH HIGH vulnerabilities in ${{ matrix.environment }} (threshold: 10)"
          fi

      - name: Create GitHub Issue on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🔴 Security vulnerabilities detected in ${{ matrix.environment }}',
              body: 'Trivy scan detected CRITICAL vulnerabilities. Please review and update images.',
              labels: ['security', 'critical', '${{ matrix.environment }}']
            })
```

#### Scan Results Analysis

**Understanding Trivy Output:**

```bash
# Example Trivy table output
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine (alpine 3.19.0)
================================================================================
Total: 5 (HIGH: 2, CRITICAL: 3)

┌─────────────────┬────────────────┬──────────┬────────────────┬───────────────────┐
│    Library      │ Vulnerability  │ Severity │ Installed Vers │    Fixed Version  │
├─────────────────┼────────────────┼──────────┼────────────────┼───────────────────┤
│ libcrypto3      │ CVE-2024-XXXX  │ CRITICAL │ 3.1.4-r0       │ 3.1.4-r1          │
│ libssl3         │ CVE-2024-XXXX  │ CRITICAL │ 3.1.4-r0       │ 3.1.4-r1          │
│ curl            │ CVE-2024-YYYY  │ HIGH     │ 8.5.0-r0       │ 8.5.0-r1          │
└─────────────────┴────────────────┴──────────┴────────────────┴───────────────────┘
```

**Key fields:**
- **Library**: Affected package name
- **Vulnerability**: CVE identifier
- **Severity**: CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN
- **Installed Version**: Current version in image
- **Fixed Version**: Version with the fix (if available)

**Action items:**
1. **CRITICAL**: Immediate action required - update base image or patch
2. **HIGH**: Schedule update within 1 week
3. **MEDIUM**: Address in next regular update cycle
4. **LOW**: Monitor, address when convenient

#### Best Practices

**1. Scan frequency:**
- **Development**: On every PR
- **Staging**: Daily automated scans
- **Production**: Daily + after every deployment

**2. Severity thresholds:**
```yaml
# Block on CRITICAL
exit-code: 1
severity: CRITICAL

# Warn on HIGH
exit-code: 0
severity: HIGH
```

**3. Ignore specific vulnerabilities** (when false positives or accepted risks):

Create `.trivyignore`:
```
# False positive in dev dependency
CVE-2024-12345

# Accepted risk - no fix available, low exploitability
CVE-2024-67890

# Waiting for upstream fix - tracked in JIRA-123
CVE-2024-11111
```

**4. Keep Trivy database updated:**
```bash
# Update vulnerability database
trivy image --download-db-only

# Use in CI
docker run --rm aquasec/trivy:latest image --download-db-only
```

### Dependency Scanning

**PHP dependencies (Composer):**

```bash
# Local Security Checker
docker-compose exec app composer require --dev enlightn/security-checker
docker-compose exec app php vendor/bin/security-checker security:check

# Or use Symfony CLI
curl -sS https://get.symfony.com/cli/installer | bash
symfony security:check
```

**Integrate in CI:**

```yaml
- name: Check PHP vulnerabilities
  run: |
    composer require --dev enlightn/security-checker
    php vendor/bin/security-checker security:check --format=json
```

## Security Monitoring

### Fail2Ban

```yaml
services:
  fail2ban:
    image: crazymax/fail2ban:latest
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - ./fail2ban:/data
      - /var/log:/var/log:ro
```

**Create `fail2ban/jail.d/nginx.conf`:**

```ini
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
```

### Audit Logging

```php
// Laravel audit log
use Illuminate\Support\Facades\Log;

class AuditMiddleware
{
    public function handle($request, Closure $next)
    {
        $response = $next($request);

        Log::channel('audit')->info('Request handled', [
            'user_id' => auth()->id(),
            'ip' => $request->ip(),
            'method' => $request->method(),
            'path' => $request->path(),
            'status' => $response->status(),
            'user_agent' => $request->userAgent(),
        ]);

        return $response;
    }
}
```

### Security Alerts

```yaml
# docker-compose.monitoring.yml
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus

  alertmanager:
    image: prom/alertmanager:latest
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
```

**Alert rules (`prometheus-rules.yml`):**

```yaml
groups:
  - name: security
    rules:
      - alert: HighErrorRate
        expr: rate(nginx_http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "High error rate detected"

      - alert: TooManyFailedLogins
        expr: rate(login_failed_total[5m]) > 10
        for: 1m
        annotations:
          summary: "Possible brute force attack"
```

## Security Best Practices

### ✅ Application Security
- [ ] Input validation on all user input
- [ ] Output encoding to prevent XSS
- [ ] Parameterized queries to prevent SQL injection
- [ ] CSRF protection enabled
- [ ] Strong password hashing (bcrypt/argon2)
- [ ] Rate limiting on sensitive endpoints
- [ ] Security headers configured

### ✅ Container Security
- [ ] Run as non-root user
- [ ] Read-only root filesystem where possible
- [ ] Drop unnecessary capabilities
- [ ] Regular security scanning
- [ ] Minimal base image (Alpine preferred)
- [ ] No secrets in image layers

### ✅ Network Security
- [ ] HTTPS/TLS enabled
- [ ] Strong TLS configuration
- [ ] Network isolation configured
- [ ] Firewall rules in place
- [ ] Rate limiting enabled
- [ ] DDoS protection configured

### ✅ Monitoring & Response
- [ ] Security logging enabled
- [ ] Audit trail maintained
- [ ] Alerts configured
- [ ] Incident response plan documented
- [ ] Regular security reviews
- [ ] CVE monitoring active

## Related Documentation

- [Production Deployment](../guides/production-deployment) - Production setup
- [Environment Variables](../reference/environment-variables) - Configuration options
- [Configuration Options](../reference/configuration-options) - Detailed config
- [Performance Tuning](performance-tuning) - Performance optimization

---

**Questions?** Check [common issues](../troubleshooting/common-issues) or ask in [GitHub Discussions](https://github.com/phpeek/baseimages/discussions).
