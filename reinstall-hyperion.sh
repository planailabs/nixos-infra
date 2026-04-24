#!/bin/sh

nix run github:nix-community/nixos-anywhere -- --flake '.#hyperion' root@$1

