#!/bin/sh

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#omen --use-substitutes --target-host root@omen.plan.ai --impure boot
