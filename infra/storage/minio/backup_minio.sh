#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/srv/optcg/minio/backups}"
DATA_DIR="${DATA_DIR:-/srv/optcg/minio/data}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="${BACKUP_ROOT}/minio-data-${STAMP}.tar.zst"

mkdir -p "${BACKUP_ROOT}"

if ! command -v zstd >/dev/null 2>&1; then
  echo "Install zstd first: sudo apt-get install -y zstd"
  exit 1
fi

tar --warning=no-file-changed -C "${DATA_DIR}" -cf - . | zstd -T0 -19 -o "${DEST}"
sha256sum "${DEST}" > "${DEST}.sha256"

find "${BACKUP_ROOT}" -type f -name "minio-data-*.tar.zst" -mtime "+${RETENTION_DAYS}" -delete
find "${BACKUP_ROOT}" -type f -name "minio-data-*.tar.zst.sha256" -mtime "+${RETENTION_DAYS}" -delete

echo "Backup written: ${DEST}"

