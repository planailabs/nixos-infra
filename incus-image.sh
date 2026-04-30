#!/bin/bash

set -euxo pipefail

# Build an Incus/LXD image from a NixOS configuration and import it on atlas.
# The config must include modules/container.nix (or nixpkgs' lxc-container.nix).
# Usage: ./incus-image.sh <configuration> [alias]

CONFIG="$1"
ALIAS="${2:-$CONFIG}"

nix build ".#nixosConfigurations.${CONFIG}.config.system.build.metadata" -L -o "result-metadata-${CONFIG}" --impure
nix build ".#nixosConfigurations.${CONFIG}.config.system.build.tarball"  -L -o "result-tarball-${CONFIG}" --impure

METADATA="$(echo "result-metadata-${CONFIG}"/tarball/*.tar.xz)"
ROOTFS="$(echo "result-tarball-${CONFIG}"/tarball/*.tar.xz)"

rsync -L --progress "${METADATA}" atlas.plan.ai:metadata.tar.xz
rsync -L --progress "${ROOTFS}"   atlas.plan.ai:image.tar.xz

ssh atlas.plan.ai "incus image import metadata.tar.xz image.tar.xz --alias ${ALIAS} && incus create ${ALIAS} ${ALIAS} -c security.nesting=true"
