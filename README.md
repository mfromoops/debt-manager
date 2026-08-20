# Debt Manager

Monorepo for the Debt Manager mobile app and its Cloudflare Worker backends.

## Projects

| Project | Path | Description |
|---|---|---|
| Mobile app | `apps/mobile` | Flutter app for tracking loans and payoff strategies. |
| Auth Worker | `services/auth` | Cloudflare Worker that exchanges WorkOS AuthKit callback codes. |
| Sync Worker | `services/sync` | Cloudflare Worker + Durable Object backend for local-first sync. |

## Setup

Install Worker dependencies from the repo root:

```bash
pnpm install
```

Install Flutter dependencies:

```bash
cd apps/mobile
flutter pub get
```

## Development

Run the auth Worker:

```bash
pnpm auth:dev
```

Run the sync Worker on port 8788:

```bash
pnpm sync:dev
```

Run the Flutter app:

```bash
cd apps/mobile
flutter run \
  --dart-define=WORKOS_CLIENT_ID=<your-workos-client-id> \
  --dart-define=AUTH_BACKEND_BASE_URL=http://localhost:8787 \
  --dart-define=SYNC_BACKEND_BASE_URL=http://localhost:8788 \
  --dart-define=WORKOS_PROVIDER=GoogleOAuth
```

See each project README for project-specific configuration:

- `apps/mobile/README.md`
- `services/auth/README.md`
- `services/sync/README.md`
