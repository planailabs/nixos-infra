#!/bin/sh

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#obsidian --use-substitutes --target-host root@obsidian.plan.ai --impure switch
