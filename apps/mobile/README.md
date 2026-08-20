# DebtFold

DebtFold is a minimalist Flutter app for tracking debts, projecting payoff dates, and testing strategies for becoming debt-free sooner. It supports mortgages, credit cards, personal loans, auto loans, student loans, and other debts.

The app is local-first: it works without an account and stores data on the device. Users can optionally sign in with WorkOS to sync their data through the Cloudflare backend.

## Current Features

### Loan tracking

- Track multiple debts from one home screen.
- Add amortized loans using a starting balance, annual interest rate, first-payment date, and duration in months. Durations are positive whole numbers and are not capped by the app.
- Add fixed-payment debts such as credit cards using a current balance, APR, tracking date, and monthly payment.
- Calculate scheduled payments, payoff dates, total interest, and month-by-month amortization schedules.
- Warn when a fixed monthly payment does not cover the monthly interest.
- Sort loans by next payment, loan amount, payoff date, date added, minimum due, or interest rate.

### Progress and projections

- See total remaining debt, the next payment, the required monthly amount, planned extras, and projected interest savings.
- See what percentage of gross monthly salary the current payment cycle uses and how much income remains after debt payments.
- View standard and accelerated payoff charts for each loan.
- View the combined projected debt curve across all loans.
- Log real payments, balance checkpoints, dates, and notes; edit or remove previous progress entries.
- Browse amortization schedules in monthly or yearly views.

### Extra-payment strategies

- Create, edit, enable, disable, and delete strategies for an individual loan.
- Supported cadences:
  - Monthly
  - Annual in a selected month
  - Every N weeks
  - Every N months
  - One-time payment on a selected date
- Choose when recurring strategies begin.
- Compare the baseline and accelerated payoff to see interest and time saved.
- Clear all extra-payment strategies from the account menu.

### Payoff Planner

- Compare debt avalanche (highest interest rate first) and debt snowball (smallest balance first).
- Set a shared extra monthly budget and a strategy start month.
- Schedule month-based pauses or temporary reductions without changing required minimum payments.
- Add custom shared plan payments as annual installments, every-N-month payments, or one-time payments.
- See the projected debt-free date, payoff order, time saved, interest saved, and total interest.
- Compare the proposed recurring monthly commitment with gross monthly salary. The affordability card includes minimum payments, the extra monthly budget, and the monthly equivalent of recurring add-ons; one-time payments are excluded from the ongoing ratio.
- Classify the plan as **Healthy** at 36% or less of monthly income, **Getting tight** above 36% through 43%, or **High** above 43%. These labels are general budgeting guidance rather than financial advice.
- Roll a paid-off loan's scheduled payment into the next target.
- Apply the selected plan to the tracked loans as extra-payment strategies, preserving the actual loan and month that received each custom payment.

### Financial profile and income guidance

- Open **Profile** from the account menu, including when no loans have been added yet.
- Enter gross salary as either a monthly or annual amount; annual salary is normalized to a monthly amount for comparisons.
- Store the profile locally in guest mode and sync it with the authenticated user's loan data after sign-in.
- Use salary only for on-device payment-cycle and payoff-plan calculations; the sync backend stores the serialized profile but does not calculate income ratios.

### Local-first accounts and sync

- Continue as a guest with loan and financial-profile data stored locally in `shared_preferences`.
- Sign in through WorkOS AuthKit and sync through the Cloudflare Worker + Durable Object backend.
- Link existing guest data when signing in for the first time.
- Keep account data isolated when switching between users.
- Refresh WorkOS sessions and show sync status on the home screen.

### Android launcher widgets

The Android build includes three display-only home-screen widgets that open DebtFold when tapped:

- **Payment cycle** — required payment, strategy extras, and next due date.
- **Debt progress** — remaining debt, percentage paid, interest saved, and projected time remaining.
- **Next payment** — the next debt, planned amount, due date, and projected balance.

## Architecture

DebtFold lives in a pnpm monorepo with three projects:

| Project | Path | Purpose |
|---|---|---|
| Flutter app | `apps/mobile` | Android and web UI, local persistence, calculations, and sync client |
| Auth Worker | `services/auth` | Exchanges and refreshes WorkOS sessions without exposing the API key to Flutter |
| Sync Worker | `services/sync` | Authenticated, per-user loan-and-profile document storage using a Durable Object |

The financial calculations remain in the Flutter app. The sync service stores the serialized loans and optional financial profile, and does not calculate payoff or income-ratio results.

## Tech Stack

| Area | Technology |
|---|---|
| App | Flutter 3.35.4 / Dart 3.9.2 |
| State management | `provider` |
| Local persistence | `shared_preferences` |
| Authentication | WorkOS AuthKit |
| Auth and sync backends | Cloudflare Workers |
| Per-user sync storage | Cloudflare Durable Objects |
| HTTP and links | `http`, `url_launcher`, `app_links` |
| Formatting | `intl` |
| Supported project targets | Android and web |

## Project Structure

```text
apps/mobile/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── extra_payment.dart
│   │   ├── financial_profile.dart
│   │   ├── loan.dart
│   │   └── progress_entry.dart
│   ├── screens/
│   │   ├── dashboard_screen.dart
│   │   ├── home_shell.dart
│   │   ├── loan_detail_shell.dart
│   │   ├── loan_edit_screen.dart
│   │   ├── loans_overview_screen.dart
│   │   ├── planner_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── schedule_screen.dart
│   │   ├── sign_in_screen.dart
│   │   ├── strategies_screen.dart
│   │   └── strategy_edit_screen.dart
│   ├── services/
│   │   ├── amortization_engine.dart
│   │   ├── app_state.dart
│   │   ├── auth_config.dart
│   │   ├── auth_service.dart
│   │   ├── launcher_widget_service.dart
│   │   ├── payoff_planner.dart
│   │   ├── sync_config.dart
│   │   └── sync_service.dart
│   └── widgets/
│       ├── debt_curve_chart.dart
│       └── payoff_chart.dart
├── android/                 # Android app and native launcher widgets
├── web/                     # Flutter web bootstrap files
└── test/widget_test.dart    # Financial, state, sync, planner, and UI tests
```

## Local Development

### Prerequisites

- Flutter 3.35.x with Dart 3.9.x
- Node.js and pnpm 11
- Android SDK and JDK 17 for Android development
- A WorkOS application with AuthKit enabled when testing sign-in and sync

Verify Flutter:

```bash
flutter doctor
```

### Install dependencies

From the repository root:

```bash
pnpm install
cd apps/mobile
flutter pub get
```

### Run without an account

The app can run without backend configuration. Start Flutter and choose **Continue without signing in**:

```bash
cd apps/mobile
flutter run
```

### Run with WorkOS and sync

Start both Workers from the repository root:

```bash
pnpm auth:dev
pnpm sync:dev
```

Configure this callback URI in WorkOS for Android:

```text
com.debtfold.app://auth/callback
```

Then start the Android app with public build-time settings:

```bash
cd apps/mobile
flutter run \
  --dart-define=WORKOS_CLIENT_ID=<your-workos-client-id> \
  --dart-define=AUTH_BACKEND_BASE_URL=http://10.0.2.2:8787 \
  --dart-define=SYNC_BACKEND_BASE_URL=http://10.0.2.2:8788 \
  --dart-define=WORKOS_PROVIDER=GoogleOAuth
```

`10.0.2.2` lets an Android emulator reach Workers running on the host. Use the host computer's LAN IP for a physical device.

For Flutter web, register a browser callback URL in WorkOS and pass it explicitly:

```bash
cd apps/mobile
flutter run -d chrome \
  --dart-define=WORKOS_CLIENT_ID=<your-workos-client-id> \
  --dart-define=AUTH_BACKEND_BASE_URL=http://localhost:8787 \
  --dart-define=SYNC_BACKEND_BASE_URL=http://localhost:8788 \
  --dart-define=WORKOS_REDIRECT_URI=http://localhost:<flutter-port>/ \
  --dart-define=WORKOS_PROVIDER=GoogleOAuth
```

Use exactly one WorkOS connection selector:

- `WORKOS_PROVIDER`
- `WORKOS_ORGANIZATION_ID`
- `WORKOS_CONNECTION_ID`

The WorkOS API key is a Worker secret and must never be included in Flutter build settings. See `services/auth/README.md` and `services/sync/README.md` for backend configuration and deployment.

## Checks

Run the Flutter checks from `apps/mobile`:

```bash
flutter analyze
flutter test
```

Run the backend checks from the repository root:

```bash
pnpm auth:test
pnpm sync:typecheck
```

## Build and Deploy

### Android

Release signing is read from `apps/mobile/android/key.properties`. Create a keystore and keep both the keystore and credentials out of version control.

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=WORKOS_CLIENT_ID=<your-workos-client-id> \
  --dart-define=AUTH_BACKEND_BASE_URL=<deployed-auth-worker-url> \
  --dart-define=SYNC_BACKEND_BASE_URL=<deployed-sync-worker-url> \
  --dart-define=WORKOS_PROVIDER=GoogleOAuth
```

The APK is written to:

```text
apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

Use `flutter build appbundle --release` for a Google Play app bundle.

### Web

Build Flutter web with the deployed backend URLs and a registered web redirect URI:

```bash
cd apps/mobile
flutter build web --release \
  --dart-define=WORKOS_CLIENT_ID=<your-workos-client-id> \
  --dart-define=AUTH_BACKEND_BASE_URL=<deployed-auth-worker-url> \
  --dart-define=SYNC_BACKEND_BASE_URL=<deployed-sync-worker-url> \
  --dart-define=WORKOS_REDIRECT_URI=<registered-web-callback-url> \
  --dart-define=WORKOS_PROVIDER=GoogleOAuth
```

The repository also provides `pnpm mobile:build:apk`, `pnpm mobile:build:web`, and `pnpm mobile:deploy:web` scripts configured for the project's deployed environments.

## App Details

| Field | Value |
|---|---|
| App name | DebtFold |
| Android package | `com.debtfold.app` |
| Version | `1.0.0+1` |
| Flutter platforms in this repository | Android and web |

## License

Personal project — no license specified.
