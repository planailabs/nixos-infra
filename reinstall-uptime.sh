#!/bin/sh

nix run github:nix-community/nixos-anywhere -- --flake '.#uptime' root@$1

