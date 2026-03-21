#!/bin/sh

nixos-rebuild --flake .#logos --use-substitutes --target-host root@2a01:4f8:242:1ae1:1:a:0:e --impure switch
