#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

nixos-rebuild --no-reexec --flake .#agency --use-substitutes --target-host root@agency.plan.ai --impure switch
