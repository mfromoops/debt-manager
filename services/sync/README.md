# DebtFold Sync

Cloudflare Worker + Durable Object backend for local-first device sync.

The Flutter app still stores loan and financial-profile data locally in `shared_preferences`. This Worker stores one sync document per authenticated WorkOS user and lets devices pull/push that document opportunistically.

Each document contains the serialized loan list and may contain a financial profile with the user's salary amount and monthly/annual period. Older documents without a profile remain valid. Payoff and debt-to-income calculations stay in Flutter; the Worker only stores and returns the document.

## Endpoints

- `GET /health` returns `{ "ok": true }`.
- `GET /sync/state` returns the current user document or `null`.
- `PUT /sync/state` saves the current user document.

`/sync/state` requires:

```text
Authorization: Bearer <WorkOS access token>
```

The Worker validates the WorkOS JWT with the JWKS at:

```text
https://api.workos.com/sso/jwks/<WORKOS_CLIENT_ID>
```

## Local Setup

Install dependencies:

```bash
cd ../..
pnpm install
```

Run locally on a different port from the auth Worker:

```bash
pnpm sync:dev
```

For Flutter web, pass:

```bash
--dart-define=SYNC_BACKEND_BASE_URL=http://localhost:8788
```

For an Android emulator:

```bash
--dart-define=SYNC_BACKEND_BASE_URL=http://10.0.2.2:8788
```

## Deploy

```bash
pnpm sync:deploy
```

After deploy, use the Worker URL as `SYNC_BACKEND_BASE_URL`.

## Checks

```bash
pnpm sync:typecheck
```
