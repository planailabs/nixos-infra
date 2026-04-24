#!/bin/sh

NIX_SSHOPTS="-p 22222" nixos-rebuild --flake .#chronos --use-substitutes --target-host root@chronos.plan.ai --impure switch
