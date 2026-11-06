# plan-ai-infra

NixOS infrastructure configuration for plan.ai servers, managed via Nix flakes.

## Servers

### Incus hosts

| Server | Platform | Role |
|--------|----------|------|
| **atlas** | x86_64 bare metal (Hetzner) | Incus host for most containers, wg-vpng node, Incus export to Storage Box |
| **hyperion** | x86_64 bare metal (Hetzner) | Incus host, gitlab-nix-ci runners |
| **odysseus** | x86_64 workstation (`omen.plan.ai`) | Incus host, NVIDIA, CUPS print server, mac-mgmt daemon |
| **plan-ai-pi** | Raspberry Pi | Incus, kiosk browser, DHCPv6/radvd |

### Containers (LXC)

| Server | Role |
|--------|------|
| **logos** | Hub: nginx proxy, ACME distributor, xzar cache, plan.ai chat/cloud, mac-mgmt server + runner, wg-vpng (vpn.plan.ai), Prometheus/Alertmanager/Grafana (+MCP), oauth2-proxy, Zitadel, HedgeDoc, memvault, Matrix |
| **chronos** | GitLab, Docker workloads |
| **deploy** | Docker + nested Incus build/deploy box, mac-mgmt daemon |
| **codex** | litellm proxy for the Codex OAuth provider (codex.plan.ai) |
| **hippocampus** | Knowledge-graph adapter LM + Garage S3 (hippocampus.plan.ai) |
| **redream** | iDRAC web console (redream.plan.ai) |
| **obsidian** | Headless Obsidian, obsidian-mcp-server, SilverBullet (obsidian/wiki.plan.ai) |
| **cloud-images** | Image store for plan.ai cloud (cloud-images.plan.ai) |
| **harbor** | Domains/webspaces/certs/billing (harbor.plan.ai) |
| **peira** / **metis** | xzar + mac-mgmt servers for peira / extra-skills |
| **relay** / **peira-relay** | mac-mgmt relays |
| **hugger**, **hugger-amo**, **hugger-hetzner** | HuggingFace model archivers |
| **mmrcd** | mmrcd orchestration daemon driving a remote Incus (mmrcd.plan.ai) |

### Other machines

| Server | Platform | Role |
|--------|----------|------|
| **charon** | Hetzner Cloud VM | Transmission behind Mullvad WireGuard, Storage Box at /storage |
| **uptime** | Hetzner Cloud VM | Uptime Kuma (uptime.plan.ai) |
| **aarch64-builder** | Hetzner Cloud ARM | aarch64 Nix build host (aarch64.plan.ai) |
| **scanner** | VM | rustnmap API (scanner.plan.ai) |

All servers use networkd, nftables and Yggdrasil mesh networking.

## Deploying

Each server has a deployment script in the repository root. Run it from this directory to build and deploy the NixOS configuration to the target host:

```sh
# Deploy chronos
./chronos.sh

# Deploy logos
./logos.sh

# Deploy relay
./relay.sh

# Deploy peira relay
./peira-relay.sh

# Deploy plan-ai-pi (built on aarch64.plan.ai)
./pi.sh
```

The scripts use `nixos-rebuild --flake .#HOSTNAME --target-host root@ADDRESS switch` to build and activate the configuration remotely.

## Updating flake inputs

To update all flake inputs (nixpkgs, modules, etc.) and commit the lock file:

```sh
nix flake update
```

The `update.sh` script is used by CI to automatically update and push `flake.lock`.

## Building an SD image

For Raspberry Pi initial setup:

```sh
./sd-image.sh plan-ai-pi
```

## Project structure

```
flake.nix          # Flake entrypoint, defines all nixosConfigurations
<host>/            # One directory per server (see table above)
<host>.sh          # Deploy script per server; reinstall-<host>.sh for nixos-anywhere
incus-image.sh     # Build + import a container image into an Incus host
modules/           # Shared NixOS modules (common.nix, container.nix, ...)
pkgs/              # Custom package overlays
private/           # Private/secret configuration (not in repo)
docs/              # Setup notes (Hetzner/Incus host setup)
```

## Common configuration

All servers share modules from `modules/`:

- **common.nix** -- SSH (key-only root login), timezone (Europe/Vienna), nix flakes, automatic GC, system packages (htop, git, tcpdump, etc.)
- **container.nix** -- LXC container networking (networkd, DHCP on eth0, nftables)

## Flake inputs

- **nixpkgs** -- NixOS unstable
- **mkg-mod** -- Yggdrasil mesh networking module
- **xnix** -- Xeredo NixOS modules
- **acme-distributor** -- Distributed ACME certificate management
- **xzar** -- xzar artifact server
- **rust-overlay** -- Rust toolchain overlay
