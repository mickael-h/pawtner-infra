#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED_SQL="${ROOT_DIR}/postgres/seed/10-marketplace-demo.sql"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  echo "Missing ${ROOT_DIR}/.env. Copy .env.example first."
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/.env"

POSTGRES_USER="${POSTGRES_USER:-pawtner}"
DB_NAME="${PAWTNER_DB_NAME:-pawtner_db}"
CONTAINER="${POSTGRES_CONTAINER_NAME:-pawtner-postgres}"

if ! docker ps --format '{{.Names}}' | awk -v container="${CONTAINER}" '$0 == container { found=1 } END { exit !found }'; then
  echo "Container ${CONTAINER} is not running. Start stack with: docker compose up -d"
  exit 1
fi

echo "Applying demo marketplace seed to ${DB_NAME} in ${CONTAINER}..."
docker exec -i "${CONTAINER}" psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${DB_NAME}" < "${SEED_SQL}"
echo "Seed applied successfully."
