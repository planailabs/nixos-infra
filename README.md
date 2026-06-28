# plan-ai-infra

NixOS infrastructure configuration for plan.ai servers, managed via Nix flakes.

## Servers

| Server | Hostname | Platform | Role |
|--------|----------|----------|------|
| **chronos** | `chronos` | x86_64-linux (LXC) | GitLab, Docker workloads |
| **logos** | `logos` | x86_64-linux (LXC) | Nginx reverse proxy, ACME distributor, xzar |
| **hugger** | `hugger` | x86_64-linux (LXC) | HuggingFace model archiver (hugger-omen.plan.ai) |
| **hugger-amo** | `hugger-amo` | x86_64-linux (LXC) | HuggingFace model archiver (hugger-amo.plan.ai) |
| **relay** | `relay` | x86_64-linux (LXC) | Dedicated plan.ai mac-mgmt relay |
| **peira-relay** | `peira-relay` | x86_64-linux (LXC) | Dedicated peira mac-mgmt relay |
| **home-pi** | `home-pi` | Raspberry Pi | Home server, Incus VMs (currently commented out in flake) |

All servers run as LXC containers (except home-pi) with networkd, nftables, and Yggdrasil mesh networking.

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

# Deploy home-pi (requires aarch64 build host)
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
./sd-image.sh home-pi
```

## Project structure

```
flake.nix          # Flake entrypoint, defines all nixosConfigurations
chronos/           # chronos server config
logos/             # logos server config
relay/             # plan.ai relay server config
peira-relay/       # peira relay server config
pi/                # home-pi server config
modules/           # Shared NixOS modules (common.nix, container.nix)
pkgs/              # Custom package overlays
private/           # Private/secret configuration (not in repo)
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
