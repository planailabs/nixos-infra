#!/usr/bin/env nix-shell
#!nix-shell -i bash -p openssh

set -euo pipefail

# Export all Incus instances (without snapshots) and upload to Hetzner StorageBox
# Usage: ./export-incus.sh uXXXXX@uXXXXX.your-storagebox.de

if [ -z "${1:-}" ]; then
  echo "Usage: $0 uXXXXX@uXXXXX.your-storagebox.de"
  exit 1
fi

STORAGEBOX="$1"
REMOTE_DIR="incus-backups"
EXPORT_DIR="$(mktemp -d /tmp/incus-export.XXXXXX)"
DATE="$(date +%Y-%m-%d_%H%M)"

cleanup() {
  echo "Cleaning up ${EXPORT_DIR}..."
  rm -rf "${EXPORT_DIR}"
}
trap cleanup EXIT

echo "==> Listing Incus instances..."
INSTANCES="$(incus list -f csv -c n)"

if [ -z "${INSTANCES}" ]; then
  echo "No instances found."
  exit 0
fi

echo "==> Creating remote directory ${REMOTE_DIR}/${DATE}..."
ssh -p 23 "${STORAGEBOX}" "mkdir -p ${REMOTE_DIR}/${DATE}" 2>/dev/null || true

for INSTANCE in ${INSTANCES}; do
  FILENAME="${INSTANCE}_${DATE}.tar.gz"
  FILEPATH="${EXPORT_DIR}/${FILENAME}"

  echo "==> Exporting ${INSTANCE} (instance-only)..."
  incus export "${INSTANCE}" "${FILEPATH}" --instance-only

  echo "==> Uploading ${FILENAME} to StorageBox..."
  scp -P 23 "${FILEPATH}" "${STORAGEBOX}:${REMOTE_DIR}/${DATE}/${FILENAME}"

  # Remove local file after successful upload to save disk space
  rm -f "${FILEPATH}"
  echo "==> Done: ${INSTANCE}"
done

echo "==> All instances exported and uploaded to ${STORAGEBOX}:${REMOTE_DIR}/${DATE}/"
