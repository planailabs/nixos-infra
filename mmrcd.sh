#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#mmrcd --use-substitutes --target-host root@mmrcd.plan.ai --impure switch
