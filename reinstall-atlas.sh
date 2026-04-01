#!/bin/sh

nix run github:nix-community/nixos-anywhere -- --flake '.#atlas' root@$1

