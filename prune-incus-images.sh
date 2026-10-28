#!/usr/bin/env bash

set -euo pipefail

# Delete every Incus image no alias points at. Each `incus publish` /
# `incus image import` of a NixOS container leaves such an image behind and
# nothing ever refers to it again; instances keep their own copy of the
# filesystem, so dropping the image entry only reclaims the cached upload.
#
# Enabled hourly on every Incus host by `systemd.services.prune-incus-images`
# in modules/common.nix.

# An image without an alias is not orphaned yet while it is still being
# imported, or still waiting for the alias its operator is about to add.
MIN_AGE_SECONDS=$((60 * 60))

now="$(date +%s)"

incus image list --all-projects --format=json |
  jq -r --argjson now "${now}" --argjson min_age "${MIN_AGE_SECONDS}" '
    .[]
    | select((.aliases // []) | length == 0)
    | select($now - (.uploaded_at | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) >= $min_age)
    | [ .project, .fingerprint, (.properties.description // "") ]
    | @tsv
  ' |
  while IFS=$'\t' read -r project fingerprint description; do
    echo "removing ${fingerprint:0:12} from project ${project}: ${description}"
    incus image delete --project "${project}" "${fingerprint}" ||
      echo "ERROR: could not remove ${fingerprint} from project ${project}" >&2
  done
