#!/bin/sh

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#logos --use-substitutes --target-host root@logos.plan.ai --impure switch
