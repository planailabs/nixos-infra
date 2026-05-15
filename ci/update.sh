#!/bin/bash

set -euxo pipefail

if [ ! -v TARGET ]; then
  TARGET="$1.plan.ai"
fi

d() {
  nix build ".#$1.image" -o /tmp/$2-image
  nix build ".#$1.metadata"  -o /tmp/$2-meta

  META=$(readlink -f /tmp/$2-meta)
  IMAGE=$(readlink -f /tmp/$2-image)

  nix-copy-closure --gzip --to "$TARGET" "$META" "$IMAGE"
  if $3; then
    ssh "$TARGET" sudo incus image import "$META"/*/*xz "$IMAGE"/*/*xz --alias $2 --public || true
  else
    ssh "$TARGET" sudo incus image import "$META"/*/*xz "$IMAGE"/*squashfs --alias $2 --public || true
  fi
}

d glci nix-gitlab false
d glci-image nix-gitlab-image true
