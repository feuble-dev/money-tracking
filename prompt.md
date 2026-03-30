# 📱 MobiTracking — Application Flutter de Gestion d'Agence Mobile Money

## 🎯 Contexte
Développe une application Flutter Android complète nommée **MobiTracking** pour les agents de Mobile Money en Afrique de l'Ouest (Burkina Faso). L'app permet à un agent de gérer ses dépôts, retraits, clients et transactions pour plusieurs opérateurs (Orange Money, Moov Money, Coris Money, etc.) avec un système de parsing SMS **entièrement dynamique et paramétrable**.

---

## 🏗️ Architecture & Stack

- **Framework:** Flutter (Android uniquement, SDK >= 3.0)
- **Nom de l'app:** MobiTracking
- **Package name:** `com.rftech.mobitracking`
- **Architecture:** Clean Architecture (Feature-first)
- **State Management:** Riverpod
- **Base de données:** SQLite via `sqflite` + `sqflite_migration_plan`
- **Navigation:** GoRouter
- **UI:** Material 3 avec support **Light & Dark mode complet**
- **Packages requis:**
  - `sqflite` — base de données locale
  - `telephony` — lecture SMS entrants en temps réel
  - `url_launcher` — lancement USSD
  - `local_auth` — empreinte digitale / biométrie
  - `flutter_secure_storage` — stockage sécurisé du PIN
  - `fl_chart` — graphiques dashboard
  - `intl` — formatage dates et montants FCFA
  - `uuid` — génération d'IDs
  - `permission_handler` — gestion permissions Android
  - `flex_color_scheme` — gestion thème light/dark avancée

---

## 🎨 Thème Light & Dark

### Couleurs principales
```dart
// Couleur primaire : Bleu profond moderne
static const Color primaryColor     = Color(0xFF1565C0); // Bleu roi
static const Color primaryLight     = Color(0xFF42A5F5); // Bleu clair
static const Color primaryDark      = Color(0xFF0D47A1); // Bleu nuit

// Couleur secondaire (accents uniquement)
static const Color accentColor      = Color(0xFFFF6B35); // Orange doux

// Couleur succès / dépôt
static const Color depositColor     = Color(0xFF2E7D32); // Vert
static const Color withdrawColor    = Color(0xFFC62828); // Rouge

// Light theme surfaces
static const Color lightBackground  = Color(0xFFF5F7FA);
static const Color lightSurface     = Color(0xFFFFFFFF);
static const Color lightCard        = Color(0xFFEEF2F7);

// Dark theme surfaces
static const Color darkBackground   = Color(0xFF0F1923);
static const Color darkSurface      = Color(0xFF1A2535);
static const Color darkCard         = Color(0xFF243044);
```

### Règles de thème
- **Mode clair** : fond gris très doux, cartes blanches, texte sombre
- **Mode sombre** : fond bleu nuit très sombre, cartes bleu marine, texte clair
- L'orange n'apparaît **que** pour les badges, alertes et accents ponctuels
- Vert pour les dépôts, rouge pour les retraits — dans les deux modes
- Switcher Light/Dark accessible depuis les paramètres, préférence sauvegardée en `SharedPreferences`

---

## 📁 Structure du projet
```
mobitracking/
├── lib/
│   ├── core/
│   │   ├── database/         # DatabaseHelper, migrations
│   │   ├── security/         # PinService, BiometricService
│   │   ├── ussd/             # UssdLauncher
│   │   ├── sms/              # SmsListener, SmsParser
│   │   └── theme/            # AppTheme, AppColors, ThemeNotifier
│   ├── features/
│   │   ├── auth/             # PIN + biométrie
│   │   ├── operators/        # Gestion opérateurs + config SMS dynamique
│   │   ├── transactions/     # Dépôt, retrait, historique
│   │   ├── clients/          # Gestion clients
│   │   └── dashboard/        # Tableau de bord statistiques
│   └── main.dart
├── android/
└── pubspec.yaml
```

---

## 🗄️ Schéma Base de Données SQLite

### Table `operators`
```sql
CREATE TABLE operators (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  logo_path TEXT,
  account_number TEXT,
  agent_number TEXT,
  ussd_deposit_template TEXT,
  ussd_withdraw_template TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT
);
```

### Table `sms_patterns`
```sql
CREATE TABLE sms_patterns (
  id TEXT PRIMARY KEY,
  operator_id TEXT NOT NULL,
  transaction_type TEXT NOT NULL,  -- 'deposit' | 'withdrawal'
  sender_filter TEXT,
  raw_example TEXT NOT NULL,
  pattern_json TEXT NOT NULL,
  regex_generated TEXT NOT NULL,
  created_at TEXT,
  FOREIGN KEY (operator_id) REFERENCES operators(id)
);
```

### Table `clients`
```sql
CREATE TABLE clients (
  id TEXT PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  phone_number TEXT UNIQUE NOT NULL,
  cnib_number TEXT,
  birth_date TEXT,
  created_at TEXT,
  updated_at TEXT
);
```

### Table `transactions`
```sql
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,                    -- ID interne MobiTracking
  operator_id TEXT NOT NULL,             -- opérateur concerné
  client_id TEXT,                        -- client lié (si connu)
  transaction_type TEXT NOT NULL,        -- 'deposit' | 'withdrawal'
  amount REAL NOT NULL,                  -- montant en FCFA
  client_phone TEXT NOT NULL,            -- numéro du client
  client_name TEXT,                      -- nom du client (snapshot)
  operator_transaction_id TEXT,          -- ⭐ ID transaction côté opérateur (ex: TXN20241201ABC)
  operator_reference TEXT,               -- ⭐ Référence/code de confirmation opérateur
  status TEXT DEFAULT 'completed',
  source TEXT DEFAULT 'manual',          -- 'manual' | 'sms_auto'
  sms_raw TEXT,                          -- SMS brut ayant généré la transaction
  created_at TEXT NOT NULL,
  FOREIGN KEY (operator_id) REFERENCES operators(id),
  FOREIGN KEY (client_id) REFERENCES clients(id)
);
```

---

## 🔐 PHASE 1 — Sécurité (Auth)

- Au **premier lancement** : création d'un PIN à 4 chiffres
- À chaque ouverture : écran PIN avec option empreinte digitale
- PIN stocké avec `flutter_secure_storage` (hashé SHA-256)
- Si biométrie disponible → proposer automatiquement

### Écrans :
1. `SetupPinScreen` — création PIN initial
2. `LockScreen` — saisie PIN / bouton empreinte
3. `PinDots` widget — 4 points animés

---

## ⚙️ PHASE 2 — Gestion des Opérateurs & Config SMS Dynamique

### 2A. Gestion opérateurs
- Liste des opérateurs avec logo, nom, numéros
- Ajouter / Modifier / Désactiver
- Template USSD configurable :
  - Dépôt : `*144*{numero}*{montant}#`
  - Retrait : `*144*{montant}#`

### 2B. ⭐ Configuration SMS Dynamique

**Étape 1 — Coller le SMS exemple**
```
"Depot de 5000 FCFA recu de 70123456.
Ref: TXN20241201. Code: 8821. Solde: 45200 FCFA"
```

**Étape 2 — Tagger les zones**
L'agent appuie longuement sur une valeur et choisit parmi :
- 💰 `montant`
- 📱 `numero_client`
- 🔖 `operator_transaction_id` ⭐ — ID transaction opérateur
- 🔑 `operator_reference` ⭐ — code/référence de confirmation
- 💳 `solde`
- 👤 `nom_client`

**Étape 3 — Génération regex automatique**
```dart
// Exemple de regex générée :
"Depot de (?P<montant>[\d]+) FCFA recu de (?P<numero_client>[\d]+)\. Ref: (?P<operator_transaction_id>\w+)\. Code: (?P<operator_reference>[\d]+)"
```

**Étape 4 — Test en temps réel**
Coller un 2ème SMS → afficher les valeurs extraites en surbrillance.

**Étape 5 — Sauvegarde du pattern**
```dart
class SmsPatternBuilder {
  static String buildRegex(String rawSms, List<TaggedZone> zones);
  static Map<String, String>? parseSms(String sms, String regex);
}
```

---

## 💸 PHASE 3 — Transactions

### 3A. Nouveau Dépôt
1. Sélection opérateur
2. Numéro client → auto-complétion
3. Si nouveau client : formulaire inline (nom, prénom, CNIB)
4. Montant
5. **Lancer USSD** → enregistrer transaction

### 3B. Retrait Manuel
Même flux, type = `withdrawal`.

### 3C. Détection automatique SMS
```dart
class SmsListenerService {
  // Pour chaque SMS entrant :
  // 1. Tester tous les sms_patterns actifs
  // 2. Si match → extraire montant, numero_client,
  //               operator_transaction_id, operator_reference
  // 3. Créer transaction automatiquement (source = 'sms_auto')
  // 4. Notification "MobiTracking — Retrait détecté: 5000 FCFA - 70123456"
}
```

**Permissions Android dans `AndroidManifest.xml` :**
```xml
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
<uses-permission android:name="android.permission.READ_SMS"/>
<uses-permission android:name="android.permission.CALL_PHONE"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

---

## 👥 PHASE 4 — Gestion Clients

- Liste avec recherche par nom ou numéro
- Fiche client : infos + historique transactions
- Historique filtrable par date et opérateur
- Champs : Prénom, Nom, Téléphone, CNIB, Date de naissance

---

## 📊 PHASE 5 — Dashboard

### Cartes résumé
- Total dépôts / retraits du jour, semaine, mois
- Nombre de transactions et clients uniques
- `operator_transaction_id` et `operator_reference` visibles dans le détail de chaque transaction

### Graphiques (`fl_chart`)
1. Barres — dépôts vs retraits sur 7 jours
2. Linéaire — volume sur 30 jours
3. Camembert — répartition par opérateur

### Navigation dashboard
- Vue globale (tous opérateurs)
- Vue par opérateur (tabs)

---

## 📋 Ordre d'implémentation

1. **Setup projet** — `pubspec.yaml`, structure, thème light/dark, `DatabaseHelper`
2. **Auth** — PIN + biométrie
3. **Opérateurs** — CRUD + templates USSD
4. **`SmsPatternBuilder`** — logique parsing dynamique + unit tests
5. **Config SMS UI** — interface de tagging visuel
6. **Transactions** — dépôt + retrait + USSD
7. **SMS Listener** — service background
8. **Clients** — CRUD + historique
9. **Dashboard** — stats + graphiques
10. **Polish** — animations, erreurs, cas limites

---

## ✅ Critères qualité

- Nom de l'app : **MobiTracking** partout (titre, notifications, splash screen)
- Support **Light & Dark mode** sur tous les écrans
- Tout commenté en **français**
- `operator_transaction_id` et `operator_reference` extraits via SMS dynamique et affichés dans l'historique
- **100% offline**
- Aucune donnée en dur — tout paramétrable
- Unit tests sur `SmsPatternBuilder`

---

## 🚀 Commencer par

Créer le projet Flutter (`flutter create mobitracking`), configurer `pubspec.yaml` avec toutes les dépendances, mettre en place la structure complète des dossiers, puis implémenter phase par phase dans l'ordre indiqué.