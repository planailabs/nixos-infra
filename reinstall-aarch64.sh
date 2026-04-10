#!/bin/sh

nix run github:nix-community/nixos-anywhere -- --flake '.#aarch64-builder' root@$1
