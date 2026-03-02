# Pawtner infrastructure (Docker Compose)

- **postgres**: One instance, two databases: `keycloak_db`, `pawtner_db`.
- **keycloak**: Auth server (realm must be created manually or via import; see docs).

## Quick start

```bash
cp .env.example .env
# Edit .env and set passwords (required for compose)
docker compose up -d
```

## Health

- Postgres: `pg_isready -h localhost -p 5432 -U pawtner`
- Keycloak: http://localhost:8080/health/ready (and Admin Console at http://localhost:8080)

## After first start

1. Open Keycloak Admin: http://localhost:8080 (login with `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD`).
2. Create realm `pawtner`, then create a **public** client with PKCE for the mobile app (redirect URI e.g. `com.pawtner://callback`).

## Pawtner Keycloak theme

- A custom login theme is provided at `infra/keycloak/themes/pawtner`.
- It is mounted automatically in the Keycloak container at `/opt/keycloak/themes`.
- In Keycloak Admin Console, set:
  - **Realm settings** -> **Themes** -> **Login theme** = `pawtner`

If Keycloak was already running, restart it to pick up theme file changes:

```bash
docker compose restart keycloak
```
