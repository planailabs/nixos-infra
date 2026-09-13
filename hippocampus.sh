#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#hippocampus --use-substitutes --target-host root@hippocampus.plan.ai --impure switch
