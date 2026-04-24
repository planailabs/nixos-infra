#!/bin/sh

nixos-rebuild --flake .#hyperion --use-substitutes --target-host root@176.9.148.211 --impure boot
