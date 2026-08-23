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
    layout.tsx           # Root layout (html lang="fr", metadata, OpenGraph)
    globals.css          # Tailwind + Inter font import + gradient-hero, pulse-dot, shimmer
    (site)/
      layout.tsx         # SiteLayout: Navbar + main + Footer
      page.tsx           # Home: Hero, Comment ca marche, Features(limit=6), Pricing, Operateurs, CTA
      features/page.tsx  # Features grid + detailed list + stats + CTA
      pricing/page.tsx   # Pricing component + FAQ accordion
      download/page.tsx  # Download hero + installation steps + requirements + versions + Google Play teaser
      docs/page.tsx      # Accordion docs (client-side) with table of contents
    (admin)/
      dashboard/page.tsx
      licences/page.tsx
      clients/page.tsx
      demandes/page.tsx
      notifications/page.tsx
      achats-historique/page.tsx
      login/page.tsx
  components/
    site/
      Navbar.tsx         # Sticky navbar, transparent→white on scroll, mobile hamburger, green download CTA
      Hero.tsx           # gradient-hero, 2-col grid: text left + phone mockup right (3 transactions)
      Features.tsx       # 12 features with SVG icons, gap-px grid, optional `limit` prop
      Pricing.tsx        # 3 plans (Essai/Annuel/Mensuel), highlighted=green card, + SMS import addon
      Footer.tsx         # Black footer, 4 columns, copyright FEUBLE-TechBuilder
    admin/
      Sidebar.tsx        # Admin sidebar nav
      StatCard.tsx       # Dashboard stat cards
      GenerateLicenceModal.tsx
  lib/api.ts             # Axios client with Token auth interceptor
  public/
    logo.png             # App logo (used in navbar, hero mockup, download page, footer)
    icon.png             # Favicon/app icon
    logo_.png, icon_.png # Alternate versions
  tailwind.config.ts     # Custom colors, fonts, shadows
```

### Web Components Detail

**Navbar** (`components/site/Navbar.tsx`):
- `use client` — scroll listener for transparent→white transition
- Links: Accueil, Fonctionnalites, Tarifs, Documentation
- Download CTA button: `bg-accent text-white`
- Mobile: hamburger menu with full link list

**Hero** (`components/site/Hero.tsx`):
- `gradient-hero` background (blue gradient)
- Left: h1 + description + 2 CTA buttons (green download + outline "Decouvrir") + 3 feature bullets
- Right: Phone mockup (280x560px, `rounded-[2.5rem]`, gray-900 body, blue gradient screen)
  - Logo inside phone + "MoneyTracking" + "Gestion Mobile Money"
  - 3 transaction rows: Depot Orange +50,000 (green), Retrait Moov -25,000 (red), Depot Coris +100,000 (green)
  - SVG arrow icons (down=deposit, up=withdrawal)
  - **No floating animation** — static positioning only
  - Hidden on mobile (`hidden lg:flex`)

**Features** (`components/site/Features.tsx`):
- 12 features, each with SVG icon + title + description + optional tag
- Grid: `gap-px bg-gray-200 border border-gray-200 rounded-xl overflow-hidden`
- Icon box: `w-9 h-9 rounded-lg bg-primary-50 text-primary`
- Accepts `limit` prop (home page shows 6)

**Pricing** (`components/site/Pricing.tsx`):
- 3 plans: Essai gratuit, Annuel (highlighted), Mensuel
- Highlighted card: `bg-accent text-white ring-1 ring-accent`
- Non-highlighted: `bg-white border border-gray-200`
- Buttons: highlighted → `bg-white text-accent`, others → `bg-accent-50 text-accent`
- SMS Import addon card below plans: white card with `2 000 FCFA` badge

**Footer** (`components/site/Footer.tsx`):
- `bg-dark text-gray-400` — explicitly black (user rejected green footer)
- 4 columns: Brand, Navigation, Support, Contact

## Theme & Design

### Color Palette
```
Primary blue     : #1565C0 (bleu roi)
Primary light    : #42A5F5
Primary dark     : #0D47A1
Accent green     : #2E7D32 (buttons, badges, accents — replaced former orange #FF6B35)
Accent light     : #4CAF50
Accent dark      : #1B5E20
Accent 50        : #E8F5E9 (light green background for non-highlighted pricing buttons)
Deposit blue     : #1565C0 (argent sort de l'agent)
Withdrawal green : #2E7D32 (argent entre chez l'agent)
Light background : #F5F7FA (Tailwind: `soft`)
Dark background  : #0F1923 (Tailwind: `dark`)
Dark surface     : #1A2535
Muted text       : #64748B (Tailwind: `muted`)
```

### Tailwind Custom Config (`web/tailwind.config.ts`)
```
colors: primary (DEFAULT/#1565C0, dark, light, 50-700), accent (DEFAULT/#2E7D32, hover/#1B5E20, light/#4CAF50, 50/#E8F5E9), success, warning, danger, dark, soft, muted
fontFamily: Inter, system-ui, sans-serif
boxShadow: soft, medium, large, blue, green
```

### Theme Rules
- Light mode: soft grey background, white cards, dark text
- Dark mode: deep navy background, marine blue cards, light text
- Green accent for buttons, badges, and CTA elements (replaced former orange)
- Blue for deposits, green for withdrawals — in both modes
- Theme preference stored in `SharedPreferences`, toggled from Settings

### Web Design Philosophy (CRITICAL)
**No AI-generated look.** The site must look hand-crafted. Explicitly forbidden:
- Emoji as icons — use inline SVG icons only (stroke style, strokeWidth 1.5-2)
- Floating/animated elements (no float, no bounce, no pulse on site pages)
- Glass morphism / frosted glass effects
- Gradient text / gradient icon boxes
- Pill badges with gradient backgrounds
- Pulse animations on site pages (pulse-dot/shimmer kept only for admin dashboard)
- Radial gradient backgrounds
- Excessive box-shadows on cards
- Sticker-like decorative elements

**Preferred patterns:**
- Clean borders (`border border-gray-200`), `gap-px bg-gray-200` grid pattern for feature cards
- Simple white cards on `bg-soft` or `bg-white` backgrounds
- SVG icons inside small rounded boxes (`w-9 h-9 rounded-lg bg-primary-50 text-primary`)
- Minimal typography: `text-dark` for headings, `text-muted` for descriptions
- Green accent buttons everywhere: `bg-accent text-white hover:bg-accent-hover`
- No animations on site pages except CSS transitions (`transition-colors`)

### Footer
- **Black background** (`bg-dark text-gray-400`) — user explicitly wants footer black, not green
- 4-column grid: brand + description, Navigation links, Support links, Contact info
- Copyright: `© {year} MoneyTracking par FEUBLE-TechBuilder`
- Divider: `border-t border-white/10`

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

## CSS & Styling (`web/app/globals.css`)

- Google Fonts: Inter (400, 500, 600, 700, 800)
- Base: `scroll-behavior: smooth`, `body` = `text-dark antialiased`
- Custom component classes:
  - `gradient-hero` — blue gradient for hero/CTA sections: `linear-gradient(160deg, #0D47A1 0%, #1565C0 50%, #1976D2 100%)`
  - `pulse-dot` — pulsing animation (admin pages only, NOT site)
  - `shimmer` — shimmer loading effect (admin pages only, NOT site)
- No other custom CSS classes — everything uses Tailwind utilities

## Site Pages Summary

| Route | Title | Key Sections |
|-------|-------|-------------|
| `/` | Home | Hero (phone mockup), Comment ca marche (3 steps), Features (6), Pricing, Operateurs, CTA |
| `/features` | Fonctionnalites | Features grid (all 12), detailed list with bullet points, stats row, CTA |
| `/pricing` | Tarifs | Pricing cards, FAQ (4 questions) |
| `/download` | Telecharger | Logo + download button, installation steps, requirements, version history, Google Play teaser |
| `/docs` | Documentation | Table of contents, 11 accordion sections (client-side useState) |

## Admin Pages

| Route | Purpose |
|-------|---------|
| `/login` | Admin authentication |
| `/dashboard` | Stats overview with donut chart (green #2E7D32) |
| `/licences` | CRUD for licences |
| `/clients` | Client management |
| `/demandes` | Activation requests |
| `/notifications` | Push notifications to agents |
| `/achats-historique` | SMS history purchases |

Admin uses `Sidebar.tsx`, `StatCard.tsx`, `GenerateLicenceModal.tsx` components. Admin pages may use `pulse-dot` and `shimmer` CSS classes.

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
- `Colors.orange` in Flutter is semantic (warnings/pending states), not brand accent — leave as-is
- Web dev server: `npm run dev` (defaults to port 3000; use `-p 3001` if 3000 is busy)
- After heavy file changes in web, delete `.next/` folder if stale cache errors appear (e.g., "Cannot find module './161.js'")
- The web site vitrine company name is "FEUBLE-TechBuilder" (copyright footer)
- Public assets: `logo.png` (main logo), `icon.png` (favicon), plus `logo_.png`/`icon_.png` alternates
