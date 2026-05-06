#!/bin/sh

nixos-rebuild --flake .#agency --use-substitutes --target-host root@agency.plan.ai --impure switch
