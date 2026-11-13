# Google Play — déclaration des autorisations SMS et fiches à remplir

Ce document contient les textes à coller dans la Play Console pour faire
accepter `READ_SMS` et `RECEIVE_SMS`, et les réponses aux autres formulaires
obligatoires. Les textes de la déclaration sont en anglais : c'est une équipe
de Google qui les relit, et l'anglais évite les allers-retours.

Tout ce qui est écrit ici décrit le comportement réel de l'application
(version 1.0.0, base locale v19). Ne modifiez pas une affirmation sans
vérifier que l'app s'y conforme : une déclaration inexacte est un motif de
refus, puis de suspension.

---

## 1. Pourquoi une déclaration

Google interdit par défaut `READ_SMS` et `RECEIVE_SMS`. Une application ne
peut les garder que si elle entre dans une exception prévue. La nôtre :

> **SMS-based money management** — applications qui suivent un budget ou des
> opérations financières à partir des SMS (« Gestion financière basée sur les
> SMS »).

Conditions à respecter, et où nous en sommes :

| Exigence de Google | État |
|---|---|
| La lecture des SMS est la fonction principale, annoncée dans la fiche | Oui — voir la description (§ 6) |
| Explication à l'utilisateur **avant** la demande d'autorisation | Oui — dialogue « Pourquoi l'app lit vos SMS » avant le dialogue Android |
| Les SMS ne servent qu'à cette fonction, pas de vente ni de publicité | Oui — aucun SDK de publicité ou de suivi |
| Seul le strict nécessaire est lu et conservé | Oui — seuls les SMS des opérateurs activés sont enregistrés ; les autres sont ignorés |
| Politique de confidentialité publique qui décrit l'usage des SMS | Oui — `https://money-tracking.site/confidentialite` (**le site doit être redéployé**) |
| Vidéo de démonstration | **À tourner par vous** — scénario au § 4 |

---

## 2. Où remplir

Play Console → votre application → **Règles → Contenu de l'application** :

1. **Autorisations et API sensibles** → « SMS et journal d'appels » → c'est la
   déclaration (§ 3). Elle n'apparaît qu'après l'envoi du premier bundle.
2. **Règles de confidentialité** → coller l'URL de la politique.
3. **Sécurité des données** → § 5.
4. **Accès aux applications** → § 4.3 (identifiants de test pour Google).
5. **Fonctionnalités financières**, **Classification du contenu**, **Public
   cible**, **Annonces** → § 7.

---

## 3. La déclaration SMS — textes à coller

### 3.1 Fonctionnalité principale (core functionality)

Cocher : **SMS-based money management** (« Gestion financière basée sur les
SMS »). Ne cocher aucune autre case.

### 3.2 Description de l'usage (champ libre, 500 caractères max)

```
MoneyTracking is a Mobile Money tracker for Burkina Faso. Operators (Orange Money, Moov Money, Coris Money, Wave) confirm every transaction only by SMS. The app reads these operator SMS on the device and turns each one into a transaction (amount, type, reference, balance) to build the user's budget and history. Only SMS from operators the user selected are processed; all other SMS are ignored and never stored. SMS content never leaves the device.
```

### 3.3 Pourquoi il n'existe pas d'autre moyen (si le champ est proposé)

```
Mobile Money operators in Burkina Faso offer no API, no export and no notification other than SMS: the confirmation SMS is the only record of a transaction. The SMS Retriever and User Consent APIs only deliver one-time codes addressed to the app, not operator messages. RECEIVE_SMS detects a transaction in real time, even when the app is closed; READ_SMS imports past operator messages on the user's request and catches up on messages received while the phone was off.
```

### 3.4 Version française (pour vous, à ne pas coller)

> MoneyTracking suit le Mobile Money au Burkina Faso. Les opérateurs ne
> confirment une opération que par SMS. L'app lit ces SMS sur le téléphone et
> en fait des opérations (montant, type, référence, solde) pour construire le
> budget et l'historique. Seuls les SMS des opérateurs choisis sont traités ;
> les autres sont ignorés et jamais enregistrés. Le contenu des SMS ne quitte
> pas le téléphone.
>
> Il n'y a pas d'alternative : ni API, ni export, ni autre notification. Les
> API « SMS Retriever » ne livrent que des codes de vérification destinés à
> l'app. `RECEIVE_SMS` détecte l'opération à l'arrivée du SMS, même app
> fermée ; `READ_SMS` sert à l'import des anciens SMS, à la demande, et au
> rattrapage des SMS reçus téléphone éteint.

---

## 4. La vidéo de démonstration

Google demande un lien vers une vidéo (YouTube « non répertoriée » ou Google
Drive en lecture publique), 30 à 90 secondes, filmée sur un vrai téléphone
avec l'enregistreur d'écran. Pas de montage nécessaire.

### 4.1 Scénario

1. Ouvrir l'app fraîchement installée, créer un compte « Pour moi ».
2. Montrer le dialogue d'explication (« pourquoi l'app lit vos SMS ») **puis**
   le dialogue d'autorisation Android, et accepter.
3. Recevoir un vrai SMS d'opérateur (faites-vous envoyer 100 FCFA par un
   proche pendant l'enregistrement).
4. Montrer la notification « opération détectée », puis l'opération dans la
   liste et le solde mis à jour sur l'accueil.
5. Ouvrir « Récupérer mes anciens SMS », lancer l'import, montrer les
   opérations importées.
6. Finir sur le tableau de bord (dépenses par motif) : c'est la preuve que la
   lecture des SMS sert bien la fonction principale.

À éviter : montrer des SMS personnels, masquer des étapes, ajouter une voix
ou un texte qui promet autre chose que ce que fait l'app.

### 4.2 Titre et description de la vidéo

```
MoneyTracking – SMS permission demo (SMS-based money management)
```

### 4.3 « Accès aux applications » (identifiants pour le testeur de Google)

L'app demande un compte : Google doit pouvoir entrer. Créez un compte de
démonstration dédié (numéro que vous contrôlez, mot de passe simple), puis
collez :

```
Login: tap "J'ai déjà un compte", enter the phone number and password below.
Phone: <numéro du compte de démonstration>
Password: <mot de passe>
The app then asks to create a 4-digit PIN (any value).
No operator SMS can be received outside Burkina Faso: to see detection work,
open the menu > "Un SMS n'a pas été détecté ?" > "Tester un SMS" and paste a
sample operator message. The demo video shows the real flow on a live SIM.
```

---

## 5. Formulaire « Sécurité des données »

**Collecte ou partage de données : Oui.** — **Chiffrées en transit : Oui.**
— **Suppression possible : Oui**, URL : `https://money-tracking.site/confidentialite#suppression`

Google entend par « collectée » une donnée **envoyée hors du téléphone**. Ce
qui reste sur l'appareil ne se déclare pas.

| Type de données | Collectée | Partagée | Finalité | Obligatoire |
|---|---|---|---|---|
| Infos personnelles → Numéro de téléphone | Oui | Non | Gestion du compte, fonctionnalités | Oui |
| Infos personnelles → Nom (clients d'une agence) | Oui | Non | Fonctionnalités de l'app | Non (Agence seulement) |
| Infos financières → Historique d'achats / autres infos financières (opérations d'une agence) | Oui | Non | Fonctionnalités de l'app | Non (Agence seulement) |
| Identifiants de l'appareil ou autres (identifiant d'installation) | Oui | Non | Gestion du compte, sécurité | Oui |
| **Messages → SMS ou MMS** | **Non** | Non | — (traités sur l'appareil uniquement) | — |
| Contacts | Non | Non | — (lecture ponctuelle, rien n'est envoyé) | — |
| Position, photos, audio, santé, navigation, diagnostics | Non | Non | — | — |

Un compte Particulier n'envoie que son numéro, son mot de passe (haché) et
l'identifiant d'installation.

---

## 6. Fiche du Play Store

La description doit annoncer la lecture des SMS dès les premières lignes :
c'est vérifié pendant l'examen de la déclaration.

**Description courte (80 caractères max)**

```
Suivez votre Mobile Money : vos SMS d'opérateur deviennent vos comptes.
```

**Description complète**

```
MoneyTracking lit les SMS de vos opérateurs Mobile Money (Orange Money, Moov Money, Coris Money, Wave) et les transforme en opérations claires : montant, type, référence, solde. Vous n'avez rien à saisir.

POUR VOUS
• Toutes vos opérations Mobile Money, de tous vos opérateurs, au même endroit
• Où part votre argent : dépenses par motif, budget du mois, paiements récurrents
• « Mon argent » : espèces, banque, tontine, épargne, à côté du Mobile Money
• Gratuit, sans publicité

POUR VOTRE AGENCE
• Opérations, commissions et float mis à jour à chaque SMS
• Fichier clients, clôture de caisse du jour, alerte de float bas
• Plusieurs agences : le patron suit chaque point de vente à distance

VOS SMS RESTENT CHEZ VOUS
L'application a besoin de l'autorisation de lire les SMS : c'est sa fonction principale. L'analyse se fait sur votre téléphone, même sans Internet. Seuls les SMS de vos opérateurs sont utilisés ; vos autres messages sont ignorés et ne sont jamais enregistrés. Le texte de vos SMS n'est jamais envoyé sur Internet.

Code PIN, empreinte digitale, sauvegardes chiffrées par mot de passe.

Compte Particulier : gratuit. Compte Agence : 3 mois d'essai, puis licence par agence.
```

---

## 7. Autres déclarations

- **Fonctionnalités financières** : l'app ne prête pas d'argent, ne détient
  pas de fonds et n'exécute aucun paiement (elle compose un code USSD de
  l'opérateur, c'est l'opérateur qui exécute). Choisir l'option qui
  correspond à « aucune de ces fonctionnalités » ; si une case « suivi de
  budget / gestion des finances personnelles » est proposée, la cocher.
- **Annonces** : Non.
- **Public cible** : 18 ans et plus.
- **Classification du contenu** : catégorie « Utilitaire / Productivité »,
  répondre Non à toutes les questions de contenu sensible.
- **Catégorie de l'app** : Finance.

### Autorisation « ignorer l'optimisation de la batterie »

`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` n'a pas de formulaire, mais Google
peut la signaler. Réponse à donner si on vous la demande :

```
Core functionality depends on receiving the operator's SMS at the moment a transaction happens. On many devices sold in Burkina Faso (Tecno, Infinix, Itel, Xiaomi), the manufacturer's battery manager stops the app and SMS are no longer delivered to it. The exemption is never requested automatically: it is offered from the help screen "An SMS was not detected?", after an explanation dialog, and the user can decline.
```

Si Google la refuse malgré tout, elle se retire en une ligne du manifeste
sans casser l'app (la détection continue, moins fiable sur ces téléphones).

---

## 8. Ce qui peut encore bloquer

1. **Suppression de compte dans l'app** — faite : Paramètres → Mon compte →
   « Supprimer mon compte ». Dans le formulaire « Sécurité des données »,
   indiquez ce chemin et l'URL de la page web (pour ceux qui n'ont plus
   l'app). **Le backend doit être redéployé** pour que le bouton fonctionne.
2. **Test fermé.** Un compte développeur personnel créé après novembre 2023
   doit faire tourner un test fermé avec 12 testeurs pendant 14 jours avant
   de pouvoir publier en production.
3. **Refus de la déclaration.** C'est fréquent au premier envoi. Le courriel
   de Google cite la raison ; on corrige (souvent la vidéo ou la
   description) et on renvoie. Ne retirez pas les autorisations SMS : sans
   elles l'app n'a plus de fonction.

## 9. Liste de contrôle

- [ ] Site redéployé, `https://money-tracking.site/confidentialite` répond
- [ ] Bundle `.aab` envoyé sur une piste de test (interne ou fermée)
- [ ] Vidéo tournée et lien collé
- [ ] Déclaration SMS remplie (§ 3)
- [ ] Sécurité des données remplie (§ 5)
- [ ] Compte de démonstration créé et identifiants collés (§ 4.3)
- [ ] Fiche : descriptions, icône 512 px, image 1024 × 500, au moins 2 captures
- [x] Suppression de compte dans l'app (§ 8.1) — backend redéployé
