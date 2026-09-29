#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#cloud-images --use-substitutes --target-host root@cloud-images.plan.ai --impure switch
