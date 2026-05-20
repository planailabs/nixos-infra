#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

nixos-rebuild --no-reexec --flake .#aarch64-builder --use-substitutes --target-host root@aarch64.plan.ai --impure switch
