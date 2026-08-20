# Debt Manager

A minimalist Flutter app to track your debts and simulate strategies to pay them off sooner.

Track mortgages, credit cards, personal loans, auto loans and student loans in one place. Add extra-payment strategies with flexible cadences — monthly, annual, or fully custom (e.g. **every 8 weeks**) — and instantly see how much interest and time you save. A built-in **Payoff Planner** compares the debt **avalanche** vs **snowball** methods to tell you where your extra money should go first.

## Features

- **Multi-loan tracking** — mortgages, credit cards, personal/auto/student loans, each with its own dashboard, strategies and amortization schedule.
- **Two payment modes**:
  - *Amortized* loans (mortgage, personal, auto, student): enter amount, rate and term — the monthly payment is computed.
  - *Fixed-payment* loans (credit cards): no fixed term — enter your balance, APR and what you pay monthly. The app warns you if the payment doesn't even cover interest.
- **Payoff strategies** with flexible cadences:
  - Monthly (e.g. extra $200/month)
  - Annual (e.g. $5,000 bonus every December)
  - Every N weeks (e.g. every 8 weeks)
  - Every N months (e.g. quarterly)
  - One-time lump sum
  - Each strategy shows its individual interest savings and can be toggled on/off.
- **Payoff Planner** — one shared monthly budget aimed at the right loan:
  - **Avalanche** (highest interest rate first — saves the most money)
  - **Snowball** (smallest balance first — quick wins for motivation)
  - Payment **rollover**: when a loan is eliminated, its scheduled payment automatically flows into the next target.
  - Shows debt-free date, payoff order, interest saved, and how much more one method saves vs the other.
- **Charts & schedules** — minimalist payoff-projection charts (standard vs accelerated) and full amortization tables with yearly/monthly views.
- **Offline & private** — all data is stored locally on the device (`shared_preferences`). No account, no backend, no tracking.

## Tech Stack

| | |
|---|---|
| Framework | Flutter 3.35.4 / Dart 3.9.2 |
| State management | `provider` |
| Persistence | `shared_preferences` (local JSON) |
| Formatting | `intl` |
| Platforms | Android, Web |

## Project Structure

```
lib/
├── main.dart                  # App entry, minimalist theme
├── models/
│   ├── loan.dart              # Loan types & payment modes
│   └── extra_payment.dart     # Strategy cadences
├── services/
│   ├── amortization_engine.dart  # Month-by-month loan simulation
│   ├── payoff_planner.dart       # Avalanche/snowball with rollover
│   └── app_state.dart            # State + persistence
├── screens/                   # Overview, detail, strategies, schedule, planner
└── widgets/                   # Custom-painted charts
test/
└── widget_test.dart           # 9 unit tests for the financial math
```

## How to Run

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.35.x (Dart 3.9.x)
- For Android builds: Android SDK (API 35) and JDK 17
- A WorkOS application with AuthKit enabled

Verify your setup:

```bash
flutter doctor
```

### 1. Clone and install dependencies

```bash
git clone https://github.com/mfromoops/debt-manager.git
cd debt-manager
flutter pub get
```

### 2. Configure WorkOS auth

AuthKit uses a hosted sign-in page and redirects back into the app. Add this exact sign-in callback URI in the WorkOS dashboard:

```text
com.mortgagetracker.tracker://auth/callback
```

The Flutter app needs public auth settings at build time:

```bash
flutter run \
  --dart-define=WORKOS_CLIENT_ID=<your-workos-client-id> \
  --dart-define=AUTH_BACKEND_BASE_URL=http://localhost:8787 \
  --dart-define=SYNC_BACKEND_BASE_URL=http://localhost:8788 \
  --dart-define=WORKOS_PROVIDER=GoogleOAuth
```

Optional:

```bash
--dart-define=WORKOS_REDIRECT_URI=com.mortgagetracker.tracker://auth/callback
--dart-define=WORKOS_ORGANIZATION_ID=<org_id>
--dart-define=WORKOS_CONNECTION_ID=<conn_id>
```

Use exactly one connection selector: `WORKOS_PROVIDER`, `WORKOS_ORGANIZATION_ID`, or `WORKOS_CONNECTION_ID`.

`AUTH_BACKEND_BASE_URL` must point to the Cloudflare Worker backend in `../../services/auth`. `SYNC_BACKEND_BASE_URL` must point to the Durable Object sync Worker in `../../services/sync`. The app posts WorkOS callback codes to:

```text
POST /auth/workos/callback
Content-Type: application/json

{
  "code": "<authorization-code>",
  "redirect_uri": "com.mortgagetracker.tracker://auth/callback"
}
```

That backend should exchange the code with WorkOS using the server-side API key, then return:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "user": {
    "id": "...",
    "email": "person@example.com",
    "first_name": "Person",
    "last_name": "Example"
  }
}
```

Do not put the WorkOS API key in Flutter. Keep it only on the backend.

### 3. Run on the web (quickest way to try it)

```bash
flutter run -d chrome \
  --dart-define=WORKOS_CLIENT_ID=<your-workos-client-id> \
  --dart-define=AUTH_BACKEND_BASE_URL=http://localhost:8787 \
  --dart-define=SYNC_BACKEND_BASE_URL=http://localhost:8788 \
  --dart-define=WORKOS_REDIRECT_URI=http://localhost:<flutter-port>/ \
  --dart-define=WORKOS_PROVIDER=GoogleOAuth
```

Or build a release web bundle and serve it with any static server:

```bash
flutter build web --release
python3 -m http.server 8080 --directory build/web
# open http://localhost:8080
```

For web, the `WORKOS_REDIRECT_URI` must exactly match the browser URL WorkOS returns to and must be registered in the WorkOS dashboard.

### 4. Run on an Android device/emulator

```bash
flutter devices          # list connected devices
flutter run -d <device_id> \
  --dart-define=WORKOS_CLIENT_ID=<your-workos-client-id> \
  --dart-define=AUTH_BACKEND_BASE_URL=http://10.0.2.2:8787 \
  --dart-define=SYNC_BACKEND_BASE_URL=http://10.0.2.2:8788 \
  --dart-define=WORKOS_PROVIDER=GoogleOAuth
```

Use `10.0.2.2` for an Android emulator talking to Workers on your host machine. Use your computer's LAN IP for a physical device.

### 5. Run the tests

```bash
flutter test
```

## Building the APK

The release build is configured for signing via `android/key.properties`. **Signing secrets are not committed to this repo** — you need to create your own keystore once:

### 1. Create a keystore

```bash
keytool -genkey -v \
  -keystore android/release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release
```

### 2. Create `android/key.properties`

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=release
storeFile=../release-key.jks
```

> ⚠️ Never commit `release-key.jks` or `key.properties` — both are already in `.gitignore`. Keep a safe backup: updates to a published app must be signed with the same key.

### 3. Build

```bash
flutter build apk --release
```

The signed APK is produced at:

```
build/app/outputs/flutter-apk/app-release.apk
```

Optional variants:

```bash
# Smaller per-device APKs
flutter build apk --release --split-per-abi

# App Bundle for Google Play
flutter build appbundle --release
```

### 4. Install on a device

Transfer the APK to your phone and open it, or install via ADB:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

Since the app isn't distributed through the Play Store, Android will ask you to allow installs from unknown sources.

## App Details

| | |
|---|---|
| App name | Debt Manager |
| Package | `com.mortgagetracker.tracker` |
| Version | 1.0.0 |

## License

Personal project — no license specified.
