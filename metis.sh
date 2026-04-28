#!/bin/sh

nixos-rebuild --flake .#metis --use-substitutes --target-host root@metis.plan.ai --impure switch
