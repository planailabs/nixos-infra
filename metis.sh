#!/bin/sh

NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#metis --use-substitutes --target-host root@metis.plan.ai --impure switch
