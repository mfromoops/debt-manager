# DebtFold

Monorepo for a local-first Flutter debt tracker and its Cloudflare Worker backends. DebtFold runs on Android and web, works in guest mode, and can optionally sync loan data through a WorkOS account.

## Current App

- Track mortgages, credit cards, personal loans, auto loans, student loans, and other debts.
- Enter amortized-loan durations as any positive whole number of months; fixed-payment debts use a monthly payment instead.
- Project balances, payoff dates, amortization schedules, and interest with or without extra-payment strategies.
- Log real payments and balance checkpoints so future projections reflect actual progress.
- Compare avalanche and snowball payoff plans, add annual, periodic, or one-time plan payments, then apply the selected plan to the tracked loans.
- Schedule planned pauses or temporary reductions to extra payments while minimum payments continue.
- Add a monthly or annual gross salary profile and see how much income remains after the current debt-payment cycle.
- Check a proposed plan against monthly income using healthy, getting-tight, and high debt-to-income guidance.
- Store loans and the financial profile locally as a guest or sign in with WorkOS for per-user sync.
- Show payment-cycle, debt-progress, and next-payment launcher widgets on Android.

See [the mobile app README](apps/mobile/README.md) for the full feature list, architecture, configuration, and build instructions.

## Projects

| Project | Path | Description |
|---|---|---|
| Mobile app | `apps/mobile` | Flutter app for tracking loans, income, and payoff strategies. |
| Auth Worker | `services/auth` | Cloudflare Worker that exchanges WorkOS AuthKit callback codes. |
| Sync Worker | `services/sync` | Cloudflare Worker + Durable Object backend for local-first loan and profile sync. |

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

- [Mobile app](apps/mobile/README.md)
- [Auth Worker](services/auth/README.md)
- [Sync Worker](services/sync/README.md)
