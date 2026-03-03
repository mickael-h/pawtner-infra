#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  echo "Missing ${ROOT_DIR}/.env. Copy .env.example first."
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/.env"

KEYCLOAK_CONTAINER="${KEYCLOAK_CONTAINER_NAME:-pawtner-keycloak}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_NAME="pawtner"
CLIENT_ID_NAME="pawtner-mobile"

if ! docker ps --format '{{.Names}}' | awk -v container="${KEYCLOAK_CONTAINER}" '$0 == container { found=1 } END { exit !found }'; then
  echo "Container ${KEYCLOAK_CONTAINER} is not running. Start stack with: docker compose up -d"
  exit 1
fi

docker exec -i "${KEYCLOAK_CONTAINER}" bash -ec "
  /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user '${KEYCLOAK_ADMIN_USER}' \
    --password '${KEYCLOAK_ADMIN_PASS}'

  /opt/keycloak/bin/kcadm.sh add-roles -r ${REALM_NAME} --rname default-roles-${REALM_NAME} --rolename offline_access --rolename uma_authorization >/dev/null 2>&1 || true
  /opt/keycloak/bin/kcadm.sh add-roles -r ${REALM_NAME} --gname merchants --rolename offline_access >/dev/null 2>&1 || true
  /opt/keycloak/bin/kcadm.sh add-roles -r ${REALM_NAME} --gname clients --rolename offline_access >/dev/null 2>&1 || true
"

ADMIN_TOKEN="$(
  curl -fsS -X POST "http://localhost:${KEYCLOAK_HTTP_PORT:-18080}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=admin-cli" \
    -d "grant_type=password" \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASS}" | jq -r '.access_token'
)"

CLIENT_UUID="$(
  curl -fsS -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:${KEYCLOAK_HTTP_PORT:-18080}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID_NAME}" \
    | jq -r '.[0].id'
)"

OFFLINE_SCOPE_UUID="$(
  curl -fsS -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:${KEYCLOAK_HTTP_PORT:-18080}/admin/realms/${REALM_NAME}/client-scopes" \
    | jq -r '.[] | select(.name=="offline_access") | .id'
)"

if [[ -n "${CLIENT_UUID}" && -n "${OFFLINE_SCOPE_UUID}" ]]; then
  curl -sS -X PUT \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:${KEYCLOAK_HTTP_PORT:-18080}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/optional-client-scopes/${OFFLINE_SCOPE_UUID}" \
    >/dev/null || true
fi

echo "Offline access drift-correction applied for realm ${REALM_NAME} and client ${CLIENT_ID_NAME}."
