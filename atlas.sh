#!/bin/sh

nixos-rebuild --flake .#atlas --use-substitutes --target-host root@atlas.plan.ai --impure switch
