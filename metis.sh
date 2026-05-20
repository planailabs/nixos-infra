#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

nixos-rebuild --no-reexec --flake .#metis --use-substitutes --target-host root@metis.plan.ai --impure switch
