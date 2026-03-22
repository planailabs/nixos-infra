#!/bin/sh

nixos-rebuild --flake .#logos --use-substitutes --target-host root@logos.plan.ai --impure switch
