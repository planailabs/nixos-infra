#!/bin/sh

nixos-rebuild --flake .#omen --use-substitutes --target-host root@omen.plan.ai --impure boot
