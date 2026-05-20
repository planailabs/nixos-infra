#!/bin/sh

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#atlas --use-substitutes --target-host root@atlas.plan.ai --impure boot
