# chronos

GitLab and Docker workloads server.

## Overview

- **Hostname:** `chronos`
- **Platform:** x86_64-linux (LXC container)
- **SSH port:** 22222 (non-standard, to avoid conflict with GitLab SSH)

## Services

- **Docker** -- enabled for running containerized workloads (e.g. GitLab)
- **GitLab** -- self-hosted at `/srv/gitlab` (`GITLAB_HOME` env var)
- **Yggdrasil** -- mesh networking on port 14466
- **ACME** -- TLS certificates via acme-distributor at `https://acme.plan.ai`

## Firewall

Open TCP ports: 80, 443, 22

## Configuration

- `default.nix` -- main server configuration
- `../private/chronos.nix` -- private/secret configuration (credentials, etc.)

## Deploying

From the repository root:

```sh
./chronos.sh
```

This runs `nixos-rebuild switch` targeting `root@2a01:4f8:242:1ae1:1:a:0:c` on SSH port 22222.

## Notes

- Docker iptables FORWARD policy is set to ACCEPT via a systemd oneshot service (`docker-iptables-fix`) to work around container networking issues in LXC.
- Kernel sysctl `kernel.keys.maxkeys` and `kernel.keys.maxbytes` are increased for GitLab requirements.

## Updating gitlab

- `cd /srv/gitlab`
- Change version in docker-compose.yml
- run `docker compose up -d` to recreate container

Gitlab configuration is managed by docker-compose.yml
