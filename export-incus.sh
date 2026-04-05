#!/usr/bin/env nix-shell
#!nix-shell -i bash -p openssh sshfs

set -euo pipefail

# Export all Incus instances (without snapshots) directly to Hetzner StorageBox via sshfs
# Usage: ./export-incus.sh uXXXXX@uXXXXX.your-storagebox.de

if [ -z "${1:-}" ]; then
  echo "Usage: $0 uXXXXX@uXXXXX.your-storagebox.de"
  exit 1
fi

STORAGEBOX="$1"
REMOTE_DIR="incus-backups"
MOUNT_DIR="$(mktemp -d /tmp/incus-export.XXXXXX)"
DATE="$(date +%Y-%m-%d_%H%M)"

cleanup() {
  echo "Unmounting and cleaning up ${MOUNT_DIR}..."
  fusermount -u "${MOUNT_DIR}" 2>/dev/null || true
  rm -rf "${MOUNT_DIR}"
}
trap cleanup EXIT

echo "==> Mounting StorageBox via sshfs..."
sshfs -p 23 "${STORAGEBOX}:${REMOTE_DIR}" "${MOUNT_DIR}"
mkdir -p "${MOUNT_DIR}/${DATE}"

echo "==> Listing Incus instances..."
INSTANCES="$(incus list -f csv -c n)"

if [ -z "${INSTANCES}" ]; then
  echo "No instances found."
  exit 0
fi

for INSTANCE in ${INSTANCES}; do
  FILENAME="${INSTANCE}_${DATE}.tar.gz"

  echo "==> Exporting ${INSTANCE} (instance-only) directly to StorageBox..."
  incus export "${INSTANCE}" "${MOUNT_DIR}/${DATE}/${FILENAME}" --instance-only --compression none

  echo "==> Done: ${INSTANCE}"
done

echo "==> All instances exported to ${STORAGEBOX}:${REMOTE_DIR}/${DATE}/"

CUTOFF="$(date -d '3 days ago' +%Y-%m-%d_%H%M)"
echo "==> Removing backups older than 3 days (before ${CUTOFF})..."
for DIR in "${MOUNT_DIR}"/*/; do
  DIRNAME="$(basename "${DIR}")"
  if [[ "${DIRNAME}" < "${CUTOFF}" ]]; then
    echo "    Removing ${DIRNAME}..."
    rm -rf "${DIR}"
  fi
done
echo "==> Cleanup complete."
