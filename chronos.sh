#!/bin/sh

NIX_SSHOPTS="-p 22222" nixos-rebuild --flake .#chronos --use-substitutes --target-host root@2a01:4f8:242:1ae1:1:a:0:c --impure switch
