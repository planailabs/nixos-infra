# relay

Dedicated mac-mgmt relay server for plan.ai.

## Overview

- **Hostname:** `relay`
- **Platform:** x86_64-linux (LXC container)
- **Services:** mac-mgmt relay, Nginx TLS reverse proxy for `relay.plan.ai` and `plan-ai-relay.com`

## Key files

- `default.nix` -- main server configuration
- `nginx.nix` -- relay virtual host definitions

## Deploying

```sh
./relay.sh
```

This runs `nixos-rebuild switch` targeting `root@relay.plan.ai`.
