# Marketplace Auth Handoff (Infra -> API -> APP)

## Identity and authorization contract

- Issuer: `http://localhost:${KEYCLOAK_HTTP_PORT:-18080}/realms/pawtner`
- Mobile client id: `pawtner-mobile` (public client, PKCE S256)
- Canonical user identity key: `sub`
- Canonical role source: `realm_access.roles`
- Supported marketplace roles:
  - `merchant`
  - `client`

## Permission intent

- `merchant`: full seller dashboard + create/publish/update/delete own offers.
- `client`: marketplace access + personal dashboard to follow own orders.

API must always enforce ownership from authenticated identity (`sub`) and role claims, never from client-supplied owner IDs.

## Dev seed users (dev import file only)

- `merchant_demo` / `dev-merchant-123` -> member of `/merchants` -> role `merchant`
- `client_demo` / `dev-client-123` -> member of `/clients` -> role `client`

## Import modes

- `KEYCLOAK_REALM_IMPORT_FILE=pawtner-realm.dev.json`
  - includes test users above
- `KEYCLOAK_REALM_IMPORT_FILE=pawtner-realm.base.json`
  - no seeded users, but keeps realm/client/roles/groups baseline

## Validation checklist

1. Start stack:
   - `docker compose up -d`
2. Confirm realm discovery endpoint is available:
   - `curl -fsS "http://localhost:${KEYCLOAK_HTTP_PORT:-18080}/realms/pawtner/.well-known/openid-configuration"`
3. Confirm bootstrap one-shot service succeeded:
   - `docker compose ps keycloak-bootstrap`
   - expected final state: `exited (0)`
4. Query Keycloak Admin API and verify resources exist:
   - roles `merchant`, `client`
   - groups `/merchants`, `/clients`
   - dev users `merchant_demo`, `client_demo` (dev mode only)
5. (Optional) complete one OIDC login per user profile from APP and confirm API receives expected role claim.
6. Restart for repeatability:
   - `docker compose down`
   - `docker compose up -d`
   - re-check role and `sub` claims

## API handoff notes

- Parse `sub` as primary subject identifier.
- Derive authorization from `realm_access.roles`.
- Enforce:
  - offer mutating endpoints: `merchant` only and owner `sub` match
  - order follow-up endpoints: `client` for own orders; merchant only for their own offers/orders scope

## APP handoff notes

- Login/register/logout flows remain OIDC-based and unchanged at high level.
- Determine user mode from `realm_access.roles` (`merchant` vs `client`).
- Keep UX route guards role-aware:
  - merchant routes: seller dashboard + offer management
  - client routes: marketplace + personal orders dashboard
