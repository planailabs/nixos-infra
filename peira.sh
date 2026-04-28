#!/bin/sh

nixos-rebuild --flake .#peira --use-substitutes --target-host root@peira.plan.ai --impure switch
