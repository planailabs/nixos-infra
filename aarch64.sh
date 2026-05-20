#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#aarch64-builder --use-substitutes --target-host root@aarch64.plan.ai --impure switch
