#!/bin/bash

set -euxo pipefail

# Build an Incus/LXD image from a NixOS configuration and import it.
# The config must include modules/container.nix (or nixpkgs' lxc-container.nix).
# Usage: ./incus-image.sh <configuration> [alias]

CONFIG="$1"
ALIAS="${2:-$CONFIG}"

nix build ".#nixosConfigurations.${CONFIG}.config.system.build.metadata" -L -o "result-metadata-${CONFIG}"
nix build ".#nixosConfigurations.${CONFIG}.config.system.build.tarball"  -L -o "result-tarball-${CONFIG}"

METADATA="$(echo "result-metadata-${CONFIG}"/tarball/*.tar.xz)"
ROOTFS="$(echo "result-tarball-${CONFIG}"/tarball/*.tar.xz)"

echo
echo "To import the image, run:"
echo "  incus image import ${METADATA} ${ROOTFS} --alias ${ALIAS}"
