#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/.env"

KEYCLOAK_PORT="${KEYCLOAK_HTTP_PORT:-18080}"
TOKEN_URL="http://localhost:${KEYCLOAK_PORT}/realms/pawtner/protocol/openid-connect/token"
API_CONTEXT_URL="${API_CONTEXT_URL:-http://localhost:3000/api/v1/me/context}"

USERNAME="${1:-merchant_demo}"
PASSWORD="${2:-dev-merchant-123}"
CLIENT_ID="${3:-pawtner-mobile}"

echo "Requesting access+refresh token with offline_access for user ${USERNAME}..."
TOKEN_JSON="$(
  curl -fsS -X POST "${TOKEN_URL}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=${CLIENT_ID}" \
    -d "username=${USERNAME}" \
    -d "password=${PASSWORD}" \
    -d "scope=openid profile email offline_access"
)"

echo "${TOKEN_JSON}" | jq '{scope, has_refresh_token:(.refresh_token|type=="string"), refresh_expires_in}'

ACCESS_TOKEN="$(echo "${TOKEN_JSON}" | jq -r '.access_token')"
REFRESH_TOKEN="$(echo "${TOKEN_JSON}" | jq -r '.refresh_token')"

if [[ -z "${REFRESH_TOKEN}" || "${REFRESH_TOKEN}" == "null" ]]; then
  echo "No refresh token returned. offline_access flow failed."
  exit 1
fi

echo "Refreshing token..."
REFRESH_JSON="$(
  curl -fsS -X POST "${TOKEN_URL}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=refresh_token" \
    -d "client_id=${CLIENT_ID}" \
    --data-urlencode "refresh_token=${REFRESH_TOKEN}"
)"
echo "${REFRESH_JSON}" | jq '{scope, has_access_token:(.access_token|type=="string"), has_refresh_token:(.refresh_token|type=="string")}'

echo "Calling API /api/v1/me/context with issued access token..."
curl -fsS "${API_CONTEXT_URL}" -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '{sub, roles, marketplaceUser: {keycloak_username: .marketplaceUser.keycloak_username, role: .marketplaceUser.role}}'

echo "Offline flow validation passed."
