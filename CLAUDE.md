# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MoneyTracking** is a Mobile Money agent/personal-finance tracking app for Burkina Faso. Three codebases in one monorepo:

```
mobi-tracking/
  mobile/    # Flutter Android app
  backend/   # Django REST API
  web/       # Next.js site vitrine + admin dashboard
```

1. **Flutter mobile app** (`mobile/`) — Android-only. Two account types at signup: **Particulier** (personal multi-operator tracking, no commissions) and **Agence** (professional, with commissions, multi-agence, cloud sync). Tracks deposits/withdrawals/transfers/etc., auto-detects SMS transactions against a centrally-managed catalog, manages clients, caisse, and commissions.
2. **Django REST backend** (`backend/`) — Centralized operator/transaction-type catalog, licence management (per-agence billing), multi-agence ownership/sync, notifications, SMS history purchase validation.
3. **Next.js web** (`web/`) — Site vitrine + admin dashboard for managing the catalog (pays/opérateurs/types/patterns), licences, agences, clients, and notifications.

## Build & Run Commands

### Flutter App (Android only)
```bash
cd mobile
flutter pub get
flutter run                    # debug on connected device
flutter build apk --release    # release APK
flutter analyze                # static analysis — must be clean before considering work done
flutter test                   # unit tests (matching engine, DB migration, field extraction)
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
- Database: **MySQL** (via `pymysql` shim, see `config/__init__.py`), configured entirely through `.env` — no SQLite anywhere, dev and prod both point at MySQL
- Production: gunicorn + whitenoise
- Base API URL: `https://api-money-tracking.rf-appdev.online`
- API namespaces: `api/licence/` (client-facing, licence/agence/affiliation), `api/admin/` (dashboard, licences/catalog CRUD), `api/catalog/` (public, mobile onboarding/import), `api/admin/catalog/` (admin catalog CRUD), `api/sync/` (multi-agence push/affiliation)

### Next.js Web
```bash
cd web
npm install
npm run dev      # dev server
npm run build    # production build
npx tsc --noEmit # type-check — must be clean before considering work done
```
- Next.js 14, Tailwind CSS, Axios
- `NEXT_PUBLIC_API_URL` env var for backend URL

## Architecture

### Design decisions (D1–D12)

These were the key calls made during the catalog/multi-agence/sync pivot — know them before touching related code:

- **D1 — Direction lives on `SmsPattern`, not `TransactionType`.** `TransactionType.default_direction` is the fallback; `SmsPattern.direction_override` (nullable) wins if set. Effective direction = `pattern.direction_override ?? type.default_direction`. Lets "Transfert" stay one type with two patterns (reçu=in, envoyé=out) instead of duplicating the type. `in` = client's balance increases (ex-dépôt), `out` = decreases (ex-retrait).
- **D2 — Regex compiled only on mobile (Dart), never backend/web.** Backend/web store structured data only: `raw_example` + `tagged_zones` (`[{start, end, fieldName}]`). Mobile compiles to a real `RegExp` via `SmsPatternBuilder.buildRegex()` — at catalog import time (`CatalogSyncService`) and whenever an agent tags a custom pattern (`SmsZoneTagger` widget, shared between `OperatorFormScreen` and `SmsConfigScreen`). **No pattern is ever saved with a placeholder regex** (`'auto_detect'` was a legacy heuristic path, since removed as the source of type-cross-matching bugs — see D11).
- **D3 — `TransactionType` is a GLOBAL catalog**, not tied to one operator. Dépôt/Retrait/Transfert/Paiement marchand/... are created once in the admin catalog and reused across operators. `OperatorTransactionType` (junction: operator + transaction_type + ussd_code + commission_taux + is_active) carries the operator-specific attributes. `SmsPattern` belongs to an `OperatorTransactionType` (not directly to a type), since the SMS wording is operator-specific.
- **D4 — Pricing is a DB model (`PricingTier`)**, not a hardcoded dict. Editable from admin without a deploy.
- **D5 — SMS history import cost is computed on demand**: free ≤ 1 year back, 200 FCFA per additional year started (`HistoriqueService.calculer_cout`).
- **D6 — Catalog integrity via `catalog_version` + ETag**, not a fake HMAC. A `Country.catalog_version` bumps on any change to its operators/types/patterns (via `catalog/signals.py`), enabling incremental resync.
- **D7 — `Client.account_type`** (`particulier`|`agence`), chosen at onboarding. Drives mobile UI differences: Commissions tab/route hidden entirely for `particulier` (`accountTypeProvider`, router redirect + `MainShell` tab list), the "name your agency" onboarding step is skipped for `particulier` (silent default agence), and sync/affiliation only ever runs for `agence`.
- **D8 — `Agence` is the backend billing unit**, not just a local mobile concept. `Licence` FKs to `Agence` (not directly to `Client`). Each agence has its own licence lifecycle (essai/active/expirée), independent of siblings. **Multiple `Licence` rows can exist for the same `Agence`** — one per device authorized to operate it (see D12).
- **D9 — Commission stays simple**: one rate per `OperatorTransactionType`, no split by direction. Deliberately not complicated further yet.
- **D10 — Every new agence gets its own 3-month free trial**, granted at creation (`LicenceService.creer_agence_avec_essai`), even if the same device/account already used a trial elsewhere. Accepted abuse risk, no guard implemented.
- **D11 — `cible_compte` on `SmsPattern`** (`tous`|`particulier`|`agence`) — the same SMS can read differently depending on account type; the public catalog endpoint filters by `?account_type=` and the mobile catalog sync passes it through. ETag/caching is account_type-aware to avoid incorrect 304s.
- **D12 — All catalog/licence foreign keys use `on_delete=RESTRICT`**, not CASCADE. Deleting a Country/Operator/TransactionType/OperatorTransactionType/Agence/Client while dependents exist raises `RestrictedError`, caught by admin views' `safe_delete()` helper and turned into a 409 with a clear French message — never a silent cascade, never a 500. Deliberately **left as `SET_NULL`** (not RESTRICT): `DemandeActivation.agence`, `DemandeActivation.licence` — genuinely optional/nullable references, not a cascade-delete risk.

### Multi-agence ownership & cloud sync (patron/agent affiliation)

A compte Agence can own several `Agence` records. The **first person to register a given phone number becomes that number's "patron"** and creates/names the agences from their own device (normal `/essai/` → `/agences/creer/` flow, unchanged). A second physical agent, operating a given agence day-to-day on a **different phone**, joins by entering the **patron's phone number** at onboarding (`AffiliationRequest`, `sync` app) — no invitation code. Once the patron approves and assigns one of their agences, the backend mints a **second `Licence` row for that agence** scoped to the agent's `device_id` (`LicenceService.cloner_licence_pour_device`) — from then on the normal licence-check codepath (`RecupererLicenceView`, `VerifierCleView`) works for that device with zero special-casing, since it's genuinely just another authorized device for that agence.

- **Visibility**: the patron sees **full detail** (every transaction/client/caisse operation) of every agence they own, not just aggregates.
- **Rights**: **read-only** — the patron cannot create/modify anything remotely on an agence they don't personally operate.
- **Sync frequency**: automatic and continuous whenever the agent's device has network — no manual "sync now" button.
- **Scope**: this entire feature is Agence-only. Particulier accounts never affiliate and never push sync data.

Backend (`backend/sync/`):
- `AffiliationRequest` (demandeur_telephone/device_id, patron FK, agence FK nullable until approved, statut)
- `SyncedTransaction` / `SyncedClient` / `SyncedCaisseOperation` — denormalized read models (`agence` FK + `local_id` unique together, upserted idempotently), populated only by `POST /api/sync/push/`
- Endpoints (`/api/sync/`): `demander-affiliation/`, `affiliation-statut/` (mobile polls), `demandes-en-attente/` (patron polls), `affiliation/<id>/approuver|rejeter/`, `mes-agences/`, `agence-detail/<id>/`, `push/` (auth = a `Licence` row must exist for `agence_id`+`device_id`, else 403)

Mobile:
- `core/sync/sync_service.dart` — `SyncService.pushIfNeeded()`, called on a 2-minute timer (`main.dart`) and right after SMS-detected transactions. Watermark-based (`created_at` cursor in SharedPreferences), no-op for `particulier`. Idempotent — safe to retry on network failure, never loses data.
- `core/onboarding/affiliation_service.dart` — request/poll/claim-licence for the joining agent, wired into a "Créer" vs "Rejoindre" toggle on the onboarding agence step.
- `features/agences/` — patron-side "Mes agences" screen (pending requests + approve/assign/reject, agence list with sync stats) and a read-only agence detail screen (transactions/clients/caisse tabs). Reachable from the drawer's "MULTI-AGENCE" section, shown only when `account_type == 'agence'`.

**Note**: this ships the sync/affiliation/patron-viewer layer, but does **not** implement full local multi-agence data scoping (an agence switcher, `TransactionRepository`/`caisse_provider` filtering by a `currentAgenceProvider`, etc.) — each device still operates exactly one locally-active agence, same as before. The patron's visibility into *other* agences is entirely server-side (read via `/api/sync/agence-detail/`), not a second local dataset on the patron's own phone.

### Multi-phone for Particulier accounts (same mechanism, zero "agence" wording)

A Particulier often has two phones (two SIM lines). D7 forbids any "agence"/"patron" vocabulary in their UI, but the underlying need — "see everything from both phones in one place" — is identical to the agence/patron case, and every Particulier account already has exactly one hidden `Agence` row (created silently at onboarding, D7) that can serve as the sync target. So the mobile onboarding's "join an existing account" step (`_rejoindreCompte()` in `onboarding_screen.dart`, shared by both account types) and the whole `sync` backend are reused as-is — only the UI copy and screen differ:

- Onboarding step 3 for Particulier shows "Premier téléphone" (default, one tap, unchanged silent behavior) vs "J'ai déjà un compte" (enters the other phone's number) — never "Créer une agence"/"Rejoindre une agence".
- `features/agences/screens/mes_telephones_screen.dart` — Particulier-branded equivalent of `MesAgencesScreen`: approving a request auto-assigns the account's single hidden agence (no agence picker dialog, since there's only ever one), reachable from the drawer as "Mes téléphones" (shown only when `account_type == 'particulier'`, mutually exclusive with the "MULTI-AGENCE" section).
- `AgenceSyncDetailScreen` accepts an optional `title` override (`?title=` query param) so the Particulier detail view says "Téléphone lié" instead of surfacing the internal hidden agence name ("Mon suivi personnel").

No backend changes were needed for this — `sync.AffiliationRequest`/`Synced*` models are already account-type-agnostic.

### Background SMS detection (app closed, even right after reboot)

Real-time SMS detection previously only worked while the Flutter process was alive (foreground or backgrounded-but-not-killed), via the native EventChannel (`SmsListenerService` ↔ `.SmsReceiver`, manifest-registered). To keep working when the app is **fully killed** — including immediately after a device reboot, with no explicit boot step needed — mobile now also wires the (previously unused) `another_telephony` package's headless background-isolate mechanism:

- `core/sms/sms_processing_pipeline.dart` — the entire SMS→transaction pipeline (operator lookup, `SmsMatchingEngine`, commission, licence check, notification, `SyncService.pushIfNeeded()`) extracted into one top-level `processIncomingSms()` function, shared by **both** entry points below. No logic is duplicated between the live and headless paths.
- `core/sms/background_sms_handler.dart` — a top-level `@pragma('vm:entry-point')` function (`backgroundSmsHandler`), registered via `Telephony.instance.listenIncomingSms(onNewMessage: (_) {}, onBackgroundMessage: backgroundSmsHandler, listenInBackground: true)` in `main.dart`, right after SMS permissions are granted. `onNewMessage` is deliberately a no-op — real-time foreground detection is already covered by the existing EventChannel path, so only the *background* callback does real work, avoiding double-processing while the app is open.
- `android/app/src/main/AndroidManifest.xml` declares `com.shounakmulay.telephony.sms.IncomingSmsReceiver` (the plugin's receiver) alongside the existing `.SmsReceiver`, both listening for `SMS_RECEIVED`. This works even after a fresh reboot with no app interaction, because `SMS_RECEIVED` is a protected system broadcast exempt from Android 8+'s implicit-broadcast background-execution limits — **no `RECEIVE_BOOT_COMPLETED`/boot receiver/foreground service was needed** for this specific behavior.
- Fixed a pre-existing bug found while touching this code: `MainActivity.kt` was registering a **second**, dynamic instance of `.SmsReceiver` on top of the manifest-declared one every time the EventChannel's `onListen` fired, both invoking the same static callback — i.e. every SMS was processed twice while the app was foregrounded (silently masked by the DB-level dedup in the SMS pipeline). Removed the dynamic `registerReceiver`/`unregisterReceiver` calls; the manifest receiver alone is sufficient.
- Settings → Diagnostic → "Fonctionnement en arrière-plan" requests `Permission.ignoreBatteryOptimizations` (`permission_handler`), always preceded by an explanatory dialog — never silently. Without this, aggressive OEM battery managers (Xiaomi, Tecno, Infinix, Samsung — common in Burkina Faso) can still kill the process regardless of the broadcast mechanism above; there is no unified Android API for OEM-specific "autostart" allow-lists, so this is the best available standard mechanism.
- **Not implemented**: periodic background sync unrelated to an incoming SMS (e.g. a `WorkManager` job pushing every N minutes regardless of activity). Sync is triggered by `processIncomingSms()` on every detected transaction (the moment that actually matters to a patron) and by the 2-minute foreground timer in `main.dart` while the app is open — genuinely periodic background sync was judged not worth the added complexity/battery cost for now.

### Flutter App Structure (`mobile/`)
```
mobile/
  lib/
    core/
      database/       # SQLite singleton (DatabaseHelper), WAL mode, DB version 9
      sms/             # SmsListenerService (EventChannel), SmsMatchingEngine (unified), SmsFieldExtractor (legacy fallback), SmsPatternBuilder (real regex compiler), CommissionCalculator
      licence/         # LicenceService, LicenceStorage, LicenceGuard, LicenceValidator
      onboarding/      # OnboardingScreen (compte→téléphone/pays→agence→opérateurs), CatalogSyncService, AffiliationService, OnboardingStatusService (account_type, onboarding_complete)
      sync/            # SyncService — push continu vers /api/sync/push/
      historique/      # SMS history import (purchase + import flow)
      notifications/   # NotificationService (flutter_local_notifications)
      router.dart      # GoRouter — onboarding gate, PIN auth redirect, Commissions blocked for Particulier
      theme/           # AppTheme, ThemeNotifier (light/dark)
    features/
      auth/            # PIN lock, setup, change, timeout
      dashboard/       # Stats, charts (fl_chart), settings
      transactions/    # List, new, pending confirmation, cancelled
      commissions/     # Commission tracking — hidden entirely for compte Particulier (D7)
      clients/         # CRUD, detail view
      operators/       # Config, SMS pattern setup (SmsZoneTagger — vraie regex, jamais de heuristique), TransactionTypeRepository (types custom)
      agences/          # Vue "patron" multi-agence (Mes agences, détail lecture seule)
      notifications/   # Fetch from backend, show in notification bar
      caisse/          # Cash register management
      backup/          # Encrypted SQLite backup/restore
      export/          # PDF and CSV export
    shared/widgets/    # MainShell (bottom nav — 2 or 3 tabs depending on account_type), AppDrawer
  android/             # Native Android project + MainActivity.kt
  assets/              # App icons and logos
  pubspec.yaml
```

### State Management
- **Riverpod** throughout (`flutter_riverpod` + `riverpod_annotation`)
- Providers in `mobile/lib/features/*/providers/` — one per domain
- `accountTypeProvider`/`isOnboardingCompleteProvider` in `core/onboarding/onboarding_state.dart` gate router redirects and UI (Commissions tab, drawer sections)
- Dashboard/transactions/commissions providers auto-invalidate on SMS detection (see `main.dart`), which also triggers `SyncService.pushIfNeeded()`

### Database
- SQLite via `sqflite`, singleton in `DatabaseHelper.instance`, **DB version 9**
- WAL mode enabled on open, foreign keys enforced
- Key tables: `operators`, `transaction_types` (global catalog mirror), `operator_transaction_types` (junction, mirrors backend), `sms_patterns` (`operator_transaction_type_id`, `direction`, `tagged_zones_json`, `source`), `clients`, `transactions` (`transaction_type_id`, `direction`, `agence_id`), `sms_messages`, `caisse`, `caisse_operations`, `agences`, `agence_operators`, `daily_summaries` / `daily_summaries_v2`
- SQL View: `v_transactions_with_operator` for optimized queries
- `clients.phone_number` has UNIQUE constraint — always check existence before insert
- v8→v9 migration is purely additive with a full data backfill (default agence created for every pre-existing install, `operator_transaction_types` synthesized from the old `taux_commission_*`/`ussd_*_template` columns, `transactions.transaction_type_id`/`direction` and `sms_patterns.operator_transaction_type_id`/`direction` backfilled) — zero data loss, behavior identical immediately after upgrade. Covered by `test/database_migration_v9_test.dart`.

### SMS Processing (critical path)
Two entry points, same unified matching logic (`core/sms/sms_matching_engine.dart`, `SmsMatchingEngine.match()`):

1. **Real-time listener** (`SmsListenerService`) — EventChannel `com.rftech.moneytracking/sms`
2. **History import** (`HistoriqueService`) — MethodChannel `com.rftech.moneytracking/sms_inbox`

Workflow:
- Load an operator's `sms_patterns` joined to their `operator_transaction_types`/`transaction_types`
- Try patterns most-specific-first (structured/real-regex patterns before legacy ones; among structured patterns, more tagged zones = higher priority)
- **Structured patterns** (`tagged_zones_json` set, the only kind any current UI can create — see D2) match via a real compiled `RegExp`, so a pattern for one transaction type **cannot** match an SMS belonging to a different type by construction — this is what fixed the historical bug where an "achat de crédit" SMS could be picked up as a transfer
- **Legacy patterns** (`tagged_zones_json` null, `regex_generated = 'auto_detect'`, pre-existing installs only — no UI writes these anymore) fall back to a stricter-than-before keyword-discriminant heuristic, kept only for backward compatibility with already-deployed custom patterns
- **No fallback** — if nothing matches, the SMS is ignored entirely
- Extract fields, dedup by `operator_transaction_id`, create transaction with commission (`CommissionCalculator`, single implementation shared by both entry points and `TransactionTypeModel`)

Tagging a new pattern (`SmsZoneTagger` widget, `features/operators/widgets/sms_zone_tagger.dart`) is shared by:
- `OperatorFormScreen` — creating a brand-new custom operator (dépôt/retrait steps)
- `SmsConfigScreen` — adding/overriding a pattern on an existing operator, tied to a real `operator_transaction_type_id` (pick an existing catalog type or create a custom one via `TransactionTypeRepository.createCustomTypeForOperator`)

Both always produce a real `regex_generated` via `SmsPatternBuilder.buildRegex()` — there is no code path left that writes `'auto_detect'`.

### Licence System
- **Non-blocking**: read actions (dashboard, history, clients, exports, SMS receive) are always free
- **Write actions** (confirm transaction, add client, configure operator, etc.) require an active licence **for the current agence** (`LicenceGuard` checks `ActionType`)
- Three activation modes: free trial (3 months, per-agence, D10), online request (admin validates), offline key (HMAC-SHA256 signed)
- `FlutterSecureStorage` stores licence data and phone number
- `importerHistoriqueSMS` action type triggers a special purchase dialog (free ≤1 year, 200 FCFA/year beyond — D5)
- An agent affiliated to a patron's agence (D-affiliation above) gets their own `Licence` row for that agence — same licence-check code, no special-casing

### Native Android
- `mobile/android/app/src/main/kotlin/com/rftech/mobitracking/MainActivity.kt` has two channels:
  - `com.rftech.moneytracking/sms` — EventChannel for real-time SMS stream
  - `com.rftech.moneytracking/sms_inbox` — MethodChannel for `readInboxSms()` (queries `content://sms/inbox`)

### Django Backend Structure (`backend/`)
Three apps:

- **`licences`** — `Client` (account_type), `Agence` (billing unit, D8), `PricingTier` (D4), `Licence` (FK→Agence), `DemandeActivation`, `Notification`, `AchatHistorique`. Client-facing API (`licences/urls.py`, mounted at `/api/licence/`): `essai/`, `agences/`, `agences/creer/`, `demander/`, `recuperer/`, `verifier-cle/`, `notifications/`, `historique/*`. Admin API (`licences/admin_urls.py`, `/api/admin/`): `login/`, `stats/`, `licences/`, `licences/generer/`, `demandes/*`, `clients/`, `agences/`, `pricing-tiers/*`, `notifications/*`, `achats-historique/*`.
- **`catalog`** — `Country`, `Operator`, `TransactionType` (global, D3), `OperatorTransactionType` (junction), `SmsPattern` (D1/D2/D11, `cible_compte`). Public API (`catalog/urls.py`, `/api/catalog/`): `countries/`, `countries/<code>/operators/` (nested operator→types→patterns, ETag on `catalog_version`, `?account_type=` filter). Admin API (`catalog/admin_urls.py`, `/api/admin/catalog/`): full CRUD on all 5 entities, `safe_delete()` RESTRICT-aware.
- **`sync`** — multi-agence ownership/cloud sync (see dedicated section above). `/api/sync/*`.

Token authentication (DRF `rest_framework.authtoken`) is used for the **admin** endpoints only — the client-facing `/api/licence/`, `/api/catalog/`, `/api/sync/` endpoints authenticate via telephone+device_id (no bearer token), consistent across the whole client-facing surface.

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
      docs/page.tsx       # Accordion docs (client-side) with table of contents
    (admin)/
      dashboard/page.tsx
      licences/page.tsx
      clients/page.tsx
      demandes/page.tsx
      notifications/page.tsx
      achats-historique/page.tsx
      catalog/
        countries/page.tsx           # CRUD complet (create/edit/delete)
        operators/page.tsx           # CRUD complet, upload logo (FormData)
        operators/[id]/page.tsx      # Détail : types attachés (edit/delete), patterns SMS
        transaction-types/page.tsx   # CRUD complet — catalogue global (D3)
      login/page.tsx
  components/
    site/
      Navbar.tsx, Hero.tsx, Features.tsx, Pricing.tsx, Footer.tsx
    admin/
      Sidebar.tsx, StatCard.tsx, GenerateLicenceModal.tsx
      CreateCountryModal.tsx / EditCountryModal.tsx
      CreateOperatorModal.tsx / EditOperatorModal.tsx
      CreateTransactionTypeModal.tsx / EditTransactionTypeModal.tsx
      AttachTransactionTypeModal.tsx / EditOperatorTypeModal.tsx  # OperatorTransactionType (USSD/commission par paire)
      CreateSmsPatternModal.tsx, SmsPatternTagger.tsx             # tagging start/end/fieldName, jamais de regex (D2)
      ConfirmModal.tsx      # confirmation de suppression générique, affiche le message 409 RESTRICT du backend
  lib/api.ts             # Axios client with Token auth interceptor + FormData Content-Type handling
  public/
    logo.png             # App logo (used in navbar, hero mockup, download page, footer)
    icon.png             # Favicon/app icon
    logo_.png, icon_.png # Alternate versions
  tailwind.config.ts     # Custom colors, fonts, shadows
```

**Catalog CRUD pattern** (`countries`/`operators`/`transaction-types` pages, and the operator detail page's `OperatorTransactionType`/`SmsPattern` rows): table with Modifier/Supprimer actions per row → `Edit*Modal` pre-filled from the row, or `ConfirmModal` for delete. Every delete is RESTRICT-aware: the backend returns 409 with a French message when dependents exist, and `ConfirmModal` surfaces `err.response.data.erreur` directly rather than a generic failure message.

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
- Plans built around 450 FCFA/mois/agence (D4/D8) with proportional discounted tiers (annual/2-year) and an SMS-import addon card (D5) — actual figures live in `PricingTier` (admin-editable), the site copy should be kept in sync manually when tiers change
- Highlighted card: `bg-accent text-white ring-1 ring-accent`
- Non-highlighted: `bg-white border border-gray-200`
- Buttons: highlighted → `bg-white text-accent`, others → `bg-accent-50 text-accent`

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

Two sources of patterns, same underlying mechanism (D1/D2/D3):

1. **Catalog patterns** (admin-managed) — admin tags zones on a sample SMS in the web dashboard (`SmsPatternTagger`, start/end/fieldName only, no regex generated web-side per D2) against a specific `OperatorTransactionType`. Mobile imports the catalog (`CatalogSyncService.importOperators`) and compiles the real regex locally via `SmsPatternBuilder.buildRegex()`.
2. **Custom/local patterns** (agent-managed, mobile-only) — `SmsZoneTagger` widget (agent selects text on-device, tags a field, sees a live highlighted preview) against either an existing attached type or a newly-created custom one (`TransactionTypeRepository.createCustomTypeForOperator`). Always produces a real compiled regex, tested against a second sample SMS before saving (`SmsPatternBuilder.parseSms`).

Both paths write to the same `sms_patterns` schema (`tagged_zones_json` + real `regex_generated` + `operator_transaction_type_id` + `direction`) and are matched identically by `SmsMatchingEngine`.

## Licence Pricing

| Item | Price | Notes |
|------|-------|-------|
| Trial | Free | 3 months, granted per new agence created (D10) |
| Base rate | 450 FCFA/mois/agence | Billing unit is the agence (D8), not the account |
| Longer tiers | Proportional discount | `PricingTier.remise_pct`, admin-editable (D4) |
| SMS History Import | Free ≤ 1 year back, then 200 FCFA/year | Computed on demand (D5), not a flat fee |

### Licence Code Format
`MT-{SIGNATURE}-{PAYLOAD}{DATE}` (e.g., `MT-A3F9BC12-KL82MN7P20260330`)
- Signature: HMAC-SHA256 first 8 chars (uppercase)
- Payload: base32-encoded device_id[:4] + telephone[-4:], **plus `agence_id` folded into the HMAC payload** to prevent collisions between agences created same-day/telephone/device
- Date: YYYYMMDD expiration
- `LICENCE_SECRET` env var must match between Django backend and Flutter `LicenceValidator`
- `LicenceService.cloner_licence_pour_device()` mints a second code (same dates/statut, different device_id) for an agent affiliated to someone else's agence — same generation function, no new format

## Environment Variables

### Backend (`backend/.env`)
```
DJANGO_SECRET_KEY=...
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,...        # bare hostnames only, no scheme (https://) prefix
LICENCE_SECRET=moneytracking-secret-key-...
DB_NAME=moneytracking_db
DB_USER=...
DB_PASSWORD=...
DB_HOST=127.0.0.1
DB_PORT=3306
```
`USE_TZ = False` deliberately (see comment in `config/settings.py`) — Burkina Faso is always UTC+0, and `USE_TZ=True` would require MySQL timezone tables (`mysql_tzinfo_to_sql`) that aren't portable between Windows dev and the Linux VPS for zero practical benefit.

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
| `/catalog/countries` | Pays — CRUD complet |
| `/catalog/operators` | Opérateurs — CRUD complet, filtrable par pays, upload logo |
| `/catalog/operators/[id]` | Détail opérateur — types de transaction attachés (edit/delete), patterns SMS |
| `/catalog/transaction-types` | Types de transaction — catalogue global (D3), CRUD complet |

Admin uses `Sidebar.tsx`, `StatCard.tsx`, `GenerateLicenceModal.tsx`, and the catalog CRUD modal set (see Web Components Detail). Admin pages may use `pulse-dot` and `shimmer` CSS classes.

## Key Conventions

- All UI text is in French
- Currency is FCFA (West African CFA franc), formatted with `fr-FR` locale
- Phone numbers are Burkina Faso format (8 digits, prefixes 70/71/72/73/74/75/76/77/78)
- Transaction sources: `manual`, `sms_auto` (real-time), `sms_import` (history import)
- Notifications polling: 60-second interval in `main.dart`; sync push runs on a separate 2-minute timer (agence accounts only)
- Backend production URL: `https://api-money-tracking.rf-appdev.online/api`
- PIN stored hashed (SHA-256) in `FlutterSecureStorage`
- Biometric auth via `local_auth` package when available
- Android permissions required: `RECEIVE_SMS`, `READ_SMS`, `CALL_PHONE`, `USE_BIOMETRIC`
- `Colors.orange` in Flutter is semantic (warnings/pending states), not brand accent — leave as-is
- Web dev server: `npm run dev` (defaults to port 3000; use `-p 3001` if 3000 is busy)
- After heavy file changes in web, delete `.next/` folder if stale cache errors appear (e.g., "Cannot find module './161.js'")
- The web site vitrine company name is "FEUBLE-TechBuilder" (copyright footer)
- Public assets: `logo.png` (main logo), `icon.png` (favicon), plus `logo_.png`/`icon_.png` alternates
- All new FKs on catalog/licence models should default to `on_delete=RESTRICT` (D12) unless the reference is genuinely optional/nullable, in which case use `SET_NULL` explicitly and document why
