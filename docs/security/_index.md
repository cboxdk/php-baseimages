---
title: "Security"
description: "Harden Cbox PHP containers: non-root, capability dropping, TLS/mTLS, image signing, and CVE management"
weight: 50
---

# Security

How to run Cbox images securely in production.

- **[Security Hardening](security-hardening)** — the full checklist: non-root,
  `cap_drop` + `no-new-privileges`, read-only root filesystem, PHP/Nginx
  hardening, secrets, digest pinning, cosign verification, and CVE management.
- **[Rootless Containers](rootless-containers)** — the `-rootless` image
  variants (run as `www-data`, listen on `:8080`) for Kubernetes/OpenShift.
- **[Reverse Proxy & mTLS](reverse-proxy-mtls)** — running behind an L7/L4
  proxy, trusted-proxy configuration, and mutual TLS.

Report a vulnerability via
[SECURITY.md](https://github.com/cboxdk/php-baseimages/blob/main/SECURITY.md).
