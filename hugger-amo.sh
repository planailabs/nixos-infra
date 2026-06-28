#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#hugger-amo --use-substitutes --target-host root@hugger-amo.plan.ai --impure switch
