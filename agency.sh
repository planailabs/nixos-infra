#!/bin/sh

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#agency --use-substitutes --target-host root@agency.plan.ai --impure switch
