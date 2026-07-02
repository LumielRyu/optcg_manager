#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/srv/optcg/minio}"
DATA_DIR="${DATA_DIR:-/srv/optcg/minio/data}"
BACKUP_DIR="${BACKUP_DIR:-/srv/optcg/minio/backups}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo APP_DIR=${APP_DIR} bash bootstrap.sh"
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl gnupg ufw

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

mkdir -p "${APP_DIR}" "${DATA_DIR}" "${BACKUP_DIR}"
chown -R "${SUDO_USER:-root}:${SUDO_USER:-root}" /srv/optcg

ufw allow OpenSSH
ufw --force enable

cat <<EOF
Bootstrap complete.

Next steps:
1. Copy docker-compose.yml and .env to ${APP_DIR}
2. Edit ${APP_DIR}/.env with strong credentials
3. Run:
   cd ${APP_DIR}
   docker compose up -d
4. Put MinIO behind Cloudflare Tunnel or a reverse proxy with HTTPS
EOF

