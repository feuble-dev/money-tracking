# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MoneyTracking** is a Mobile Money agent management app for Burkina Faso. Three codebases in one monorepo:

```
mobi-tracking/
  mobile/    # Flutter Android app
  backend/   # Django REST API
  web/       # Next.js site vitrine + admin dashboard
```

1. **Flutter mobile app** (`mobile/`) — Android-only, for agents to track deposits/withdrawals, auto-detect SMS transactions, manage clients, and view commissions
2. **Django REST backend** (`backend/`) — Licence management, notifications, and SMS history purchase validation
3. **Next.js web** (`web/`) — Site vitrine + admin dashboard for managing licences, clients, and notifications

## Build & Run Commands

### Flutter App (Android only)
```bash
cd mobile
flutter pub get
flutter run                    # debug on connected device
flutter build apk --release    # release APK (~60MB)
```
- SDK constraint: `^3.9.0`
- Package name: `com.rftech.mobitracking`
- Java 17 required (set in `mobile/android/app/build.gradle.kts`)
- Native Kotlin code in `mobile/android/app/src/main/kotlin/com/rftech/mobitracking/MainActivity.kt` — two MethodChannels for SMS

### Django Backend
```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```
- Django 4.2, DRF 3.14, Python-dotenv for env vars
- Production: gunicorn + whitenoise
- Base API URL: `https://api-money-tracking.rf-appdev.online`
- API routes: `api/licence/` (client-facing), `api/admin/` (dashboard)

### Next.js Web
```bash
cd web
npm install
npm run dev      # dev server
npm run build    # production build
```
- Next.js 14, Tailwind CSS, Axios
- `NEXT_PUBLIC_API_URL` env var for backend URL

## Architecture

### Flutter App Structure (`mobile/`)
```
mobile/
  lib/
    core/
      database/       # SQLite singleton (DatabaseHelper), WAL mode, DB version 8
      sms/            # SmsListenerService (EventChannel), SmsFieldExtractor
      licence/        # LicenceService, LicenceStorage, LicenceGuard, LicenceValidator
      historique/     # SMS history import (purchase + import flow)
      notifications/  # NotificationService (flutter_local_notifications)
      router.dart     # GoRouter with PIN auth redirect
      theme/          # AppTheme, ThemeNotifier (light/dark)
    features/
      auth/           # PIN lock, setup, change, timeout
      dashboard/      # Stats, charts (fl_chart), settings
      transactions/   # List, new, pending confirmation, cancelled
      commissions/    # Commission tracking with operator filters
      clients/        # CRUD, detail view
      operators/      # Config, SMS pattern setup
      notifications/  # Fetch from backend, show in notification bar
      caisse/         # Cash register management
      backup/         # Encrypted SQLite backup/restore
      export/         # PDF and CSV export
    shared/widgets/   # MainShell (bottom nav with 3 tabs)
  android/            # Native Android project + MainActivity.kt
  assets/             # App icons and logos
  pubspec.yaml
```

### State Management
- **Riverpod** throughout (`flutter_riverpod` + `riverpod_annotation`)
- Providers in `mobile/lib/features/*/providers/` — one per domain
- Dashboard/transactions/commissions providers auto-invalidate on SMS detection (see `main.dart`)

### Database
- SQLite via `sqflite`, singleton in `DatabaseHelper.instance`
- WAL mode enabled on open, foreign keys enforced
- Key tables: `operators`, `sms_patterns`, `clients`, `transactions`, `sms_messages`, `caisse`, `caisse_operations`, `daily_summaries`
- SQL View: `v_transactions_with_operator` for optimized queries
- `clients.phone_number` has UNIQUE constraint — always check existence before insert

### SMS Processing (critical path)
Two entry points, same strict matching logic:

1. **Real-time listener** (`SmsListenerService`) — EventChannel `com.rftech.moneytracking/sms`, processes incoming SMS
2. **History import** (`HistoriqueService`) — MethodChannel `com.rftech.moneytracking/sms_inbox`, reads SMS inbox with date range

Both follow this strict workflow:
- Load operators + their `sms_patterns` from DB
- Filter SMS by `sender == operator.sms_sender`
- Test deposit regex patterns, then withdrawal regex patterns from `sms_patterns.regex_generated`
- **No fallback** — if no pattern matches, the SMS is ignored entirely (prevents false positives from recharges, solde checks, etc.)
- Extract fields via `SmsFieldExtractor`, dedup by `operator_transaction_id`, create transaction with commission

### Licence System
- **Non-blocking**: read actions (dashboard, history, clients, exports, SMS receive) are always free
- **Write actions** (confirm transaction, add client, configure operator, etc.) require active licence
- `LicenceGuard` checks `ActionType` — free actions bypass, write actions show activation dialog
- Three activation modes: free trial (30 days), online request (admin validates), offline key (HMAC-SHA256 signed)
- `FlutterSecureStorage` stores licence data and phone number
- `importerHistoriqueSMS` action type triggers special purchase dialog (2000 FCFA one-time)

### Native Android
- `mobile/android/app/src/main/kotlin/com/rftech/mobitracking/MainActivity.kt` has two channels:
  - `com.rftech.moneytracking/sms` — EventChannel for real-time SMS stream
  - `com.rftech.moneytracking/sms_inbox` — MethodChannel for `readInboxSms()` (queries `content://sms/inbox`)

### Django Backend Structure (`backend/`)
- Single app: `licences`
- Models: `Client`, `Licence`, `DemandeActivation`, `Notification`, `AchatHistorique`
- Client-facing API (`licences/urls.py`): essai, demander, recuperer, verifier-cle, notifications, historique/*
- Admin API (`licences/admin_urls.py`): stats, licences CRUD, demandes validation, notifications, achats-historique
- Token authentication (DRF `rest_framework.authtoken`)

### Next.js Web Structure (`web/`)
```
web/
  app/
    (site)/         # Public pages: home, features, pricing, download, docs
    (admin)/        # Dashboard, licences, clients, demandes, notifications, achats-historique
  components/
    site/           # Hero, Features, Pricing, etc.
    admin/          # Sidebar, layout components
  lib/api.ts        # Axios client with Token auth interceptor
```

## Theme & Design

### Color Palette
```
Primary blue     : #1565C0 (bleu roi)
Primary light    : #42A5F5
Primary dark     : #0D47A1
Accent orange    : #FF6B35 (badges, alerts only)
Deposit green    : #2E7D32
Withdrawal red   : #C62828
Light background : #F5F7FA
Dark background  : #0F1923
Dark surface     : #1A2535
```

### Theme Rules
- Light mode: soft grey background, white cards, dark text
- Dark mode: deep navy background, marine blue cards, light text
- Orange only for badges, alerts, and occasional accents
- Green for deposits, red for withdrawals — in both modes
- Theme preference stored in `SharedPreferences`, toggled from Settings

## SMS Pattern Configuration (dynamic parsing)

SMS patterns are user-configurable per operator:
1. Agent pastes a sample SMS (e.g., "Depot de 5000 FCFA recu de 70123456. Ref: TXN20241201...")
2. Agent tags zones by long-pressing values: `montant`, `numero_client`, `operator_transaction_id`, `operator_reference`, `solde`, `nom_client`
3. App auto-generates a regex stored in `sms_patterns.regex_generated`
4. Agent tests with a second SMS to verify extraction
5. Pattern saved to DB — used for both real-time detection and history import

## Licence Pricing

| Duration | Price | Notes |
|----------|-------|-------|
| Trial | Free | 30 days, one per device |
| 1 month | 1 000 FCFA | |
| 12 months | 10 000 FCFA | ~17% discount |
| 24 months | 18 000 FCFA | ~25% discount |
| SMS History Import | 2 000 FCFA | One-time purchase |

### Licence Code Format
`MT-{SIGNATURE}-{PAYLOAD}{DATE}` (e.g., `MT-A3F9BC12-KL82MN7P20260330`)
- Signature: HMAC-SHA256 first 8 chars (uppercase)
- Payload: base32-encoded device_id[:4] + telephone[-4:]
- Date: YYYYMMDD expiration
- `LICENCE_SECRET` env var must match between Django backend and Flutter `LicenceValidator`

## Environment Variables

### Backend (`backend/.env`)
```
DJANGO_SECRET_KEY=...
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,...
LICENCE_SECRET=moneytracking-secret-key-...
```

### Web (`web/.env.local`)
```
NEXT_PUBLIC_API_URL=http://localhost:8000
```

## Key Conventions

- All UI text is in French
- Currency is FCFA (West African CFA franc), formatted with `fr-FR` locale
- Phone numbers are Burkina Faso format (8 digits, prefixes 70/71/72/73/74/75/76/77/78)
- Transaction sources: `manual`, `sms_auto` (real-time), `sms_import` (history import)
- Notifications polling: 60-second interval in `main.dart`
- Backend production URL: `https://api-money-tracking.rf-appdev.online/api/licence`
- PIN stored hashed (SHA-256) in `FlutterSecureStorage`
- Biometric auth via `local_auth` package when available
- Android permissions required: `RECEIVE_SMS`, `READ_SMS`, `CALL_PHONE`, `USE_BIOMETRIC`
