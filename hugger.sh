#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#hugger --use-substitutes --target-host root@hugger-omen.plan.ai --impure switch
