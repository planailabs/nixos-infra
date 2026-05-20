#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

nixos-rebuild --no-reexec --flake .#obsidian --use-substitutes --target-host root@obsidian.plan.ai --impure switch
