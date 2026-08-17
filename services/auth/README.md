# Debt Manager Auth

Cloudflare Worker backend for the Debt Manager Flutter app's WorkOS AuthKit login.

## Endpoints

- `GET /health` returns `{ "ok": true }`.
- `POST /auth/workos/callback` exchanges the AuthKit authorization code for a WorkOS session.

Request body:

```json
{
	"code": "01E2RJ4C05B52KKZ8FSRDAP23J",
	"redirect_uri": "com.mortgagetracker.tracker://auth/callback"
}
```

The Worker calls `POST https://api.workos.com/user_management/authenticate` with `grant_type: "authorization_code"` and returns the WorkOS response to the app.

## Local Setup

Install dependencies:

```bash
cd ../..
pnpm install
```

Set the WorkOS API key as a local secret:

```bash
pnpm --filter debt-manager-auth wrangler secret put WORKOS_API_KEY
```

Set `WORKOS_CLIENT_ID` in `wrangler.jsonc`.

Run locally:

```bash
pnpm auth:dev
```

The local backend URL is usually:

```text
http://localhost:8787
```

For an Android emulator, pass this to Flutter:

```bash
--dart-define=AUTH_BACKEND_BASE_URL=http://10.0.2.2:8787
```

For Flutter web, pass:

```bash
--dart-define=AUTH_BACKEND_BASE_URL=http://localhost:8787
```

## Deploy

```bash
pnpm --filter debt-manager-auth wrangler secret put WORKOS_API_KEY
pnpm auth:deploy
```

After deploy, use the Worker URL as `AUTH_BACKEND_BASE_URL`.

## Checks

```bash
pnpm --filter debt-manager-auth exec tsc --noEmit
pnpm auth:test
```
