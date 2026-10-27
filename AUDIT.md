# Audit MoneyTracking — octobre 2026

Périmètre : app mobile Flutter (`mobile/`, ~23 000 lignes), backend Django (`backend/`), site et admin Next.js (`web/`).

État des outils après l'audit :
- **Mobile.** `flutter analyze` est propre : il reste seulement 3 avis de dépréciation `cacheExtent`, liés au SDK récent et sans effet sur ta version. `flutter test` : 55 tests passent (43 avant).
- **Backend.** `manage.py check` est propre. 17 tests passent (il n'y en avait aucun).
- **Web.** `tsc --noEmit` et `next build` sont propres.

---

## 1. Ce qui a été corrigé (branche `claude/stoic-gauss-pfg4b0`, 4 commits)

### 1.1 Montants qui débordent des widgets (ton problème principal)

**Cause.** Les montants étaient affichés dans des `Row` du type « libellé + `Spacer()` + montant » sans aucune contrainte de largeur. Dès qu'une somme grossissait (ex. `12 500 000 FCFA`), ou que la police système était agrandie (fréquent sur les téléphones d'entrée de gamme), Flutter levait « RenderFlex overflowed » : bandes jaunes et noires, erreur en debug.

**Correctif.**
- **Nouveau widget `AmountText`** (`shared/widgets/amount_text.dart`). Le montant reste sur une seule ligne et rétrécit automatiquement pour tenir (`FittedBox(scaleDown)`). Il est appliqué partout :
  - les deux tableaux de bord (Agence et Particulier) ;
  - la liste des transactions et son détail ;
  - la caisse, les commissions et le budget ;
  - les notifications ;
  - les transactions en attente et annulées ;
  - le détail agence et l'import d'historique.
- **Lignes « libellé + montant ».** Le libellé passe en `Expanded` avec « … » s'il est trop long, et le montant en `Flexible`.
- **Police système.** Elle est respectée jusqu'à ×1,3 (`main.dart`). Au-delà, les écrans chiffrés devenaient illisibles.
- **Graphique « Ratio entrées/sorties ».** Le donut et la légende sont maintenant côte à côte. Avant, la carte défilait *à l'intérieur* d'elle-même.
- **Légende du camembert « par opérateur ».** Elle défile au-delà d'environ 5 opérateurs. Avant : « BOTTOM OVERFLOWED ».
- **Tests.** `test/amount_overflow_test.dart` rend des montants de plusieurs milliards sur un écran de 300 px et échoue à la moindre erreur de débordement.

### 1.2 Expérience utilisateur

- **Saisie des montants groupée par milliers** pendant la frappe (`1 500 000`), via `AmountInputFormatter`. Elle s'applique au montant USSD, à la caisse, à la recharge et au budget.
- **Caisse → « Modifier ».** Le champ s'ouvrait **vide**, et « Enregistrer » sans rien saisir **remettait le solde à 0**. Il est maintenant pré-rempli avec le solde actuel, et un solde vide est refusé.
- **Commissions → « Solde opérateur ».** Ce solde était recalculé avec une regex qui lisait `1 521,00` (format Moov) comme **152 100**. Il vient maintenant de la caisse, qui est la source de vérité.
- **Recherche dans les transactions :**
  - attente de 300 ms au lieu d'une requête SQL par lettre ;
  - les réponses périmées sont ignorées (avant, en tapant vite, un ancien résultat pouvait s'afficher) ;
  - la recherche marche aussi par **référence opérateur** ;
  - `%` et `_` sont cherchés tels quels.
- **En-tête de la liste.** Avec 500 transactions ou plus, il affiche « 500 dernières » au lieu d'un total trompeur (la liste est limitée à 500).
- **USSD.** Un numéro saisi « 70 12 34 56 » ou « +226… » cassait le code USSD. Seuls les chiffres sont maintenant injectés.
- **Plantage sur les fiches clients.** `client.firstName[0]` levait une RangeError si un nom était vide, ce qui cassait la liste et la fiche client. Corrigé par un getter `initials`.
- **Détail agence (patron).** Les dates s'affichaient en ISO brut (`2026-10-27T14:03:22`). Elles sont maintenant formatées.
- **Tendance des dépenses (Particulier).** Une hausse s'affiche en orange et une baisse en vert. Avant, plus de dépenses s'affichait en vert.

### 1.3 Sécurité backend (critique)

> Un numéro de téléphone **n'est pas un secret**. Or plusieurs endpoints se contentaient du numéro.

| Faille | Impact | Correctif |
|---|---|---|
| `GET /api/sync/agence-detail/<id>/?telephone=…` | N'importe qui connaissant le numéro d'un patron lisait **toutes ses transactions et tous ses clients** | Appareil du propriétaire exigé |
| `demander-affiliation` puis `approuver` avec le numéro du patron | Un tiers **s'auto-approuvait**, obtenait une licence sur l'agence et pouvait y pousser de fausses données | Idem |
| `POST /api/licence/essai/` sur un numéro existant | Rattachement libre au compte d'autrui, **sans mot de passe** | Mot de passe ou appareil du propriétaire exigé (réponse 403 avec un message clair) |
| `GET /api/licence/agences/` | Exposait les codes de licence | Appareil du propriétaire exigé |
| `POST /api/licence/verifier-cle/` | Seul le format était vérifié : `MT-00000000-0000000020991231` était acceptée | La clé doit exister en base pour cet appareil |
| Import d'historique | Un import **gratuit** (≤ 1 an) débloquait ensuite **5 ans sans payer** | L'achat ne couvre que la période payée, et seul l'écart est facturé |
| Logins (compte et admin) | Aucune limite, force brute possible | 10 essais/min |

- **Règle commune** dans `backend/licences/auth.py` : une action « en tant que propriétaire » exige un `device_id` autorisé par le propriétaire lui-même, soit à la création du compte, soit par connexion avec mot de passe. Un agent affilié opère l'agence mais n'agit pas au nom du patron.
- **Admin Django réparé.** `LicenceAdmin` et l'action « Valider » utilisaient un champ `Licence.client` qui n'existe plus : la page plantait.
- **Avertissement au démarrage** si la production tourne avec les clés par défaut (`DJANGO_SECRET_KEY` / `LICENCE_SECRET`), qui sont publiques dans le dépôt.
- **Preuve.** Sur les 16 tests de `backend/licences/tests.py`, **10 échouaient sur l'ancien code**.

**Côté mobile :**
- `PatronApi` envoie le `device_id`.
- L'URL d'API est centralisée dans `core/config/api_config.dart` (elle était recopiée dans 8 fichiers). On peut la changer au build avec `--dart-define=API_BASE_URL=…`.
- L'activation par clé est vérifiée par le serveur quand le réseau est disponible.

### 1.4 Fiabilité des données

- **Sauvegarde incomplète.** La base est en mode WAL et la sauvegarde ne copiait que le fichier `.db` : **les dernières transactions manquaient**. Un `wal_checkpoint(TRUNCATE)` est maintenant fait avant la copie.
- **Restauration risquée.** Les fichiers `-wal`/`-shm` de l'ancienne base pouvaient être rejoués sur la base restaurée, avec un risque de corruption. Maintenant :
  - le fichier est vérifié (en-tête SQLite) ;
  - la base actuelle est gardée en `.avant_restauration` ;
  - les fichiers WAL sont supprimés ;
  - `close()` est réellement attendu.
- **Synchro patron.** Le curseur était basé sur `created_at`. Les transactions **rétrodatées** (rattrapage SMS au démarrage D15, import d'historique) **n'étaient jamais poussées**. Le curseur suit maintenant l'ordre d'insertion (rowid), table par table.
- **Code PIN.** Il n'y avait aucune limite d'essais. Il y a maintenant un blocage progressif après 5 erreurs, de 30 s jusqu'à 15 min. Le blocage est conservé même si l'app redémarre.

### ⚠️ Ordre de déploiement

Le backend durci **refuse** les vues « patron » d'une app qui n'envoie pas le `device_id`.

Déploie **le backend et la nouvelle APK en même temps**. Les anciennes versions de l'app gardent tout le reste ; seuls les écrans « Mes agences » et « Mes téléphones » apparaîtront vides jusqu'à la mise à jour.

Vérifie aussi que nginx transmet `X-Forwarded-For`. Sans lui, la limite de 10 essais/min de connexion est partagée par tous les utilisateurs.

---

## 2. À décider ensemble (pas corrigé, choix produit ou migration nécessaire)

Classé par priorité.

### 🔴 P1 — L'« identifiant d'appareil » n'est pas unique

**Constat.** `LicenceService.getDeviceId()` renvoie `androidInfo.id`. Dans `device_info_plus`, c'est **`Build.ID`**, le numéro de version du firmware (ex. `TP1A.220624.014`). **Tous les téléphones du même modèle avec la même mise à jour ont le même « device_id ».**

**Conséquences.** Elles concernent tout ce qui est indexé par `device_id` :
- **Import d'historique.** `historique/demander` cherche l'achat actif par `device_id` seul, donc un utilisateur peut récupérer **le jeton payé par un inconnu** qui a le même modèle de téléphone.
- **Statut d'affiliation.** `affiliation-statut/?device_id=` peut renvoyer la demande, et le code de licence, d'une autre personne.
- **Push de synchro et contrôle « appareil du propriétaire ».** Un `Build.ID` se devine (il est public pour chaque firmware), ce qui affaiblit le correctif 1.3.
- **Plantage serveur.** Une collision de code de licence peut planter le serveur (500) si un agent affilié a le même modèle que son patron.

**Proposition**, en deux temps :
1. **Côté app.** Générer un **identifiant d'installation aléatoire** (UUID), stocké de façon sécurisée. Pour les installations existantes, garder l'ancien ID afin de ne casser aucune licence.
2. **Côté serveur (le vrai correctif).** Émettre un **jeton secret par appareil** à `/essai/` et `/login/`, et l'exiger sur tous les endpoints client à la place du couple téléphone + device_id.

> Question pour toi : OK pour imposer une mise à jour de l'app, et pour que la réinstallation sur un même téléphone demande le mot de passe du compte ?

### 🔴 P2 — Clés de licence hors ligne non signées

**Constat.** L'app hors ligne n'accepte que le **format** de la clé, plus une date d'expiration lue *dans* la clé. N'importe qui peut taper `MT-AAAAAAAA-AAAAAAAA20991231` en mode avion et obtenir une licence jusqu'en 2099. Le correctif 1.3 ferme ce trou seulement quand l'app est en ligne.

**Proposition.** Signer les clés avec une **signature asymétrique** (Ed25519). Le serveur garde la clé privée et l'app ne contient que la clé publique, impossible à forger. Les clés seraient plus longues (environ 40 caractères au lieu de 28), donc à fournir en QR code ou par copier-coller.

**Alternative plus simple.** Exiger le réseau pour activer une clé. L'agent a de toute façon Internet quand il reçoit sa clé par WhatsApp.

### 🟠 P3 — SMS reçus pendant une licence expirée : perdus définitivement

**Constat** (`sms_processing_pipeline.dart` §7). Le SMS est enregistré, mais aucune transaction n'est créée. Ensuite :
- quand la licence est renouvelée, **rien ne rejoue ces SMS** ;
- le rattrapage du démarrage (D15) ne regarde que les SMS « plus récents que le dernier connu » ;
- la déduplication par empreinte empêche tout retraitement.

En plus, la notification affichée passe l'**id du SMS** comme id de transaction : la toucher ouvre un écran « introuvable ».

**Proposition.** Ajouter `SmsReplayService.replayUnprocessed()`, appelé après chaque activation ou renouvellement de licence, qui retraite les `sms_messages.processed = 0`. Et corriger la notification.

### 🟠 P4 — Déduplication SMS permanente par contenu

L'index UNIQUE `content_hash` (SHA-1 de expéditeur + texte) est **définitif**, pas limité dans le temps.

Deux SMS légitimes **identiques au caractère près** produisent un seul enregistrement. C'est le cas par exemple de deux achats de crédit de 500 F si l'opérateur n'indique ni solde ni référence.

**Proposition.** Inclure la minute de réception dans l'empreinte, ou n'appliquer l'unicité que sur une fenêtre de quelques minutes.

### 🟠 P5 — Sauvegardes non chiffrées, sauvegarde Android automatique

- **Fichiers `.mmtbak`.** Ce sont des **copies brutes de la base SQLite** : toutes les transactions et tous les clients, en clair. Ils sont partagés via WhatsApp ou Drive. Le `CLAUDE.md` parle de « sauvegarde chiffrée » et le paquet `encrypt` est dans `pubspec.yaml`, mais il n'est pas utilisé.
- **Sauvegarde Android automatique.** `android:allowBackup` n'est pas désactivé : Android sauvegarde aussi la base dans Google Drive. Après une restauration sur un nouveau téléphone, `flutter_secure_storage` (le PIN et la licence) **ne peut plus déchiffrer ses données** (problème connu), ce qui peut faire planter l'app au démarrage.

**Proposition.** Chiffrer en AES-GCM avec un mot de passe choisi à la sauvegarde. Et exclure `FlutterSecureStorage` de l'auto-backup (règles `dataExtractionRules`), ou désactiver l'auto-backup.

### 🟠 P6 — APK de release signée avec la clé debug

**Constat.** `android/app/build.gradle.kts` contient `signingConfig = signingConfigs.getByName("debug")`. Ce n'est **pas publiable** sur le Play Store. Et le jour où tu changes de clé, les utilisateurs devront désinstaller l'app, ce qui **efface leurs données**.

**Proposition.** Créer un keystore de release **maintenant**, le garder précieusement (et le sauvegarder), et le référencer via `key.properties`.

### 🟡 P7 — Synchro patron : les modifications ne remontent pas

Une transaction **annulée ou corrigée** après sa première synchronisation reste « completed » chez le patron. Le corriger demande une colonne `updated_at` sur `transactions` (migration DB v16) mise à jour à chaque modification, et un curseur basé dessus.

### 🟡 P8 — Divers

**Backend**
- **URL d'API.** `CLAUDE.md` indique `api-money-tracking.rf-appdev.online`, alors que tout le code mobile utilise `api.money-tracking.site`. À aligner. Elle est maintenant à un seul endroit (`ApiConfig`).
- **Réglages permissifs.** `ALLOWED_HOSTS='*'` et `CORS_ALLOW_ALL_ORIGINS=True` par défaut. À restreindre en production : le domaine de l'admin web et celui de l'API.
- **`PushSyncView`** n'est pas dans une transaction `atomic`, et une valeur invalide (champ trop long en MySQL strict) provoque une erreur 500 à chaque tentative. La synchro reste alors **bloquée pour toujours** sur ce lot. Il faudrait tronquer les champs et rejeter la ligne fautive, pas tout le lot.

**Mobile**
- **Transactions.** La liste est plafonnée à 500 sans pagination. Il faudrait un défilement infini, et des totaux calculés en SQL plutôt que sur la liste chargée.
- **Fiche client.** Elle relance sa requête à chaque reconstruction (`FutureBuilder` dont le `future` est recréé dans `build`).

**Web**
- **Jeton admin.** Il est stocké dans `localStorage` et la protection est uniquement côté client, ce qui le rend lisible en cas de faille XSS. Acceptable pour un admin interne, mais un cookie `HttpOnly` serait plus sûr.
- **Avertissement `metadataBase`** au build. Il faut le définir pour que les aperçus OpenGraph pointent vers le vrai domaine.

---

## 3. Ce qui va bien 👍

- **Architecture claire et bien documentée.** Les décisions D1–D20 sont tracées et le code les respecte. Les commentaires expliquent le *pourquoi*, ce qui est rare.
- **Chaîne SMS solide :**
  - un seul pipeline pour les 3 points d'entrée ;
  - une déduplication atomique entre isolates ;
  - des regex compilées uniquement sur le mobile ;
  - une détection approchée par niveaux de confiance, testée ;
  - un solde de caisse « annoncé » protégé par date plutôt qu'une somme de deltas.
- **Migrations SQLite additives et testées** (v9 couverte par des tests). Le PIN est stocké avec PBKDF2 et migré de façon transparente.
- **Backend.** `on_delete=RESTRICT` est appliqué systématiquement et les suppressions renvoient un 409 lisible. Le catalogue a un ETag et un numéro de version.
- **Analyse statique propre** avant même l'audit : 0 erreur sur ~23 000 lignes.
