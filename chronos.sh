#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

NIX_SSHOPTS="-p 22222" nixos-rebuild --no-reexec --flake .#chronos --use-substitutes --target-host root@chronos.plan.ai --impure switch
