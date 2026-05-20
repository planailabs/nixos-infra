#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

nixos-rebuild --no-reexec --flake .#peira --use-substitutes --target-host root@peira.plan.ai --impure switch
