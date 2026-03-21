# logos

Reverse proxy and certificate management server.

## Overview

- **Hostname:** `logos`
- **Platform:** x86_64-linux (LXC container)

## Services

- **Nginx** -- reverse proxy with ACME TLS, brotli, gzip, and recommended security settings
- **ACME distributor** -- centralized Let's Encrypt certificate management for all servers, served at `acme.plan.ai`
- **xzar** -- artifact/binary server at `xzar.plan.ai` (max upload 10 GB)
- **Yggdrasil** -- mesh networking on port 14466

## Virtual hosts

| Domain | Backend |
|--------|---------|
| `xzar.plan.ai` | `http://localhost:17788` |
| `acme.plan.ai` | `http://localhost:3444` |

All virtual hosts have ACME TLS enabled with forced SSL redirect.

## Firewall

Open TCP ports: 80, 443

## Configuration

- `default.nix` -- main server configuration
- `nginx.nix` -- Nginx virtual host definitions
- `../private/logos.nix` -- private/secret configuration (credentials, etc.)

## Deploying

From the repository root:

```sh
./logos.sh
```

This runs `nixos-rebuild switch` targeting `root@2a01:4f8:242:1ae1:1:a:0:e`.
