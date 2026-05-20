#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

nixos-rebuild --no-reexec --flake .#logos --use-substitutes --target-host root@logos.plan.ai --impure switch
