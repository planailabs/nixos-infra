#!/bin/sh

nixos-rebuild --flake .#hyperion --use-substitutes --target-host root@hyperion.plan.ai --impure boot
