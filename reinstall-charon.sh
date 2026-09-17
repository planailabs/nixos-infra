#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

# charon pulls its secrets from the private submodule via private.nix, which
# resolves the path with builtins.getEnv "PWD" -- that needs impure eval in
# every nix command nixos-anywhere runs, hence `--option pure-eval false`.
nix run github:nix-community/nixos-anywhere -- --option pure-eval false --flake '.#charon' root@$1
