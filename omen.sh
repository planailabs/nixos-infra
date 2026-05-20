#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

nixos-rebuild --no-reexec --flake .#omen --use-substitutes --target-host root@omen.plan.ai --impure boot
