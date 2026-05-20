#!/bin/sh

NIX_SSHOPTS="-p 22222" NIX_PATH=nixos-system="$PWD/flake.nix" nixos-rebuild --no-reexec --flake .#chronos --use-substitutes --target-host root@chronos.plan.ai --impure switch
