#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#hugger-hetzner --use-substitutes --target-host root@hugger-hetzner.plan.ai --impure switch
