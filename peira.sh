#!/bin/sh

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#peira --use-substitutes --target-host root@peira.plan.ai --impure switch
