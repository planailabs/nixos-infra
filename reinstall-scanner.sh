#!/bin/sh

nix run github:nix-community/nixos-anywhere -- --flake '.#scanner' root@$1
