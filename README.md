# Pawtner infrastructure (Docker Compose)

- **postgres**: One instance, two databases: `keycloak_db`, `pawtner_db`.
- **keycloak**: Auth server (realm is imported automatically on startup).

## Quick start

```bash
cp .env.example .env
# Edit .env and set passwords (required for compose)
docker compose up -d
```

By default, Keycloak imports `keycloak/realm/pawtner-realm.dev.json` through `KEYCLOAK_REALM_IMPORT_FILE`.
Then `keycloak-bootstrap` applies an idempotent partial import from `KEYCLOAK_BOOTSTRAP_FILE` so roles/groups/client/users are enforced even when the realm already exists in the database.
If runtime drift causes offline token issues (`offline_access`), run:

```bash
./scripts/keycloak-fix-offline-access.sh
```

Validate offline token + refresh + API context flow:

```bash
./scripts/validate-offline-flow.sh
```

## Health

- Postgres: `pg_isready -h localhost -p 5432 -U pawtner`
- Keycloak realm discovery: `http://localhost:${KEYCLOAK_HTTP_PORT}/realms/pawtner/.well-known/openid-configuration`
- Keycloak Admin Console: `http://localhost:${KEYCLOAK_HTTP_PORT}`

## Realm import modes

- **Dev mode** (`KEYCLOAK_REALM_IMPORT_FILE=pawtner-realm.dev.json`, `KEYCLOAK_BOOTSTRAP_FILE=pawtner-partial.dev.json`):
  - imports realm `pawtner`
  - creates mobile client `pawtner-mobile` (public + PKCE)
  - creates realm roles `merchant` and `client`
  - creates groups `/merchants` and `/clients`
  - seeds two test users:
    - `merchant_demo` / `dev-merchant-123`
    - `client_demo` / `dev-client-123`
- **Baseline/prod mode** (`KEYCLOAK_REALM_IMPORT_FILE=pawtner-realm.base.json`, `KEYCLOAK_BOOTSTRAP_FILE=pawtner-partial.base.json`):
  - same realm/client/roles/groups
  - no seeded users

Use baseline/prod mode outside local development and manage users through your usual identity lifecycle.

## Auth contract for API and APP

- Canonical identity key: `sub`.
- Canonical authorization source: `realm_access.roles` containing `merchant` or `client`.
- Offline sessions: app requests `offline_access`; realm/client bootstrap ensures offline scope + role are available for mobile refresh token flows.
- Permission intent:
  - `merchant`: seller dashboard + create/publish/update/delete own offers.
  - `client`: marketplace browsing + personal order dashboard.
- Issuer format: `http://localhost:${KEYCLOAK_HTTP_PORT}/realms/pawtner` (default port in `.env` is `18080`).
- Detailed handoff and validation checklist: `MARKETPLACE_AUTH_HANDOFF.md`.

## Marketplace demo data seed (for API/APP integration)

- Seed source is mapped from `../pawtner-app/src/features/shared/data/mockData.ts`.
- This creates and populates local tables in `pawtner_db`:
  - `marketplace_users`, `merchant_profiles`, `marketplace_offers`
  - `merchant_reviews`, `marketplace_orders`, `marketplace_monthly_sales_metrics`
- Run:

```bash
./scripts/seed-marketplace-demo.sh
```

- Re-running is safe (idempotent upserts).

## Pawtner Keycloak theme

- A custom login theme is provided at `infra/keycloak/themes/pawtner`.
- It is mounted automatically in the Keycloak container at `/opt/keycloak/themes`.
- In Keycloak Admin Console, set:
  - **Realm settings** -> **Themes** -> **Login theme** = `pawtner`

If Keycloak was already running, restart it to pick up theme file changes:

```bash
docker compose restart keycloak
```
