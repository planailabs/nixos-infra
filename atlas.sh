#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

nixos-rebuild --no-reexec --flake .#atlas --use-substitutes --target-host root@atlas.plan.ai --impure boot
