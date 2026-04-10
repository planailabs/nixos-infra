#!/bin/sh

nixos-rebuild --flake .#aarch64-builder --use-substitutes --target-host root@aarch64.plan.ai --impure switch
