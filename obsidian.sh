#!/bin/sh

nixos-rebuild --flake .#obsidian --use-substitutes --target-host root@obsidian.plan.ai --impure switch
