import type { IconName } from '@/components/site/Icon';

/**
 * Contenu éditorial du site, en un seul endroit : les pages et composants
 * l'affichent, ils ne le dupliquent pas. Les tarifs reflètent les
 * PricingTier du backend (D4) — à tenir à jour si la grille change.
 */

export type Audience = 'particulier' | 'agence' | 'tous';

export interface Feature {
  icon: IconName;
  title: string;
  description: string;
  audience: Audience;
  points?: string[];
}

export const operators = ['Orange Money', 'Moov Money', 'Coris Money', 'Wave'];

export const features: Feature[] = [
  {
    icon: 'sms',
    title: 'Vos SMS deviennent des opérations',
    description:
      "Chaque SMS de votre opérateur est lu sur votre téléphone : montant, numéro, référence et solde sont extraits, l'opération est enregistrée. Rien à saisir.",
    audience: 'tous',
    points: [
      'Fonctionne même application fermée, même après un redémarrage',
      'Les SMS reçus pendant une coupure sont rattrapés',
      'Import de vos anciens SMS pour retrouver votre historique',
    ],
  },
  {
    icon: 'wallet',
    title: 'Tout votre argent au même endroit',
    description:
      "Mobile Money, espèces, banque, tontine : ajoutez ce qui ne passe pas par SMS en deux gestes et voyez à tout moment où est votre argent.",
    audience: 'particulier',
    points: [
      'Comptes espèces, banque, épargne avec leur solde',
      'Saisie rapide d’une dépense ou d’un revenu',
      'Un retrait vers vos espèces n’est jamais compté deux fois',
    ],
  },
  {
    icon: 'pie',
    title: 'Où part votre argent',
    description:
      'Nourriture, transport, famille, factures… vos dépenses sont rangées par motif, souvent automatiquement, pour comprendre vos habitudes.',
    audience: 'particulier',
    points: [
      'Motifs pensés pour le Burkina Faso, personnalisables',
      '« Toujours ranger ce numéro ici » : on ne vous redemande plus',
      'Les paiements réguliers sont repérés tout seuls',
    ],
  },
  {
    icon: 'target',
    title: 'Un budget qui vous prévient',
    description:
      'Fixez un plafond par motif et suivez votre mois en un coup d’œil. Un bilan vous attend au début de chaque mois.',
    audience: 'particulier',
  },
  {
    icon: 'coins',
    title: 'Commissions calculées pour vous',
    description:
      "Un taux par opérateur et par type d'opération : vos commissions du jour, de la semaine et du mois sont toujours à jour.",
    audience: 'agence',
  },
  {
    icon: 'chart',
    title: 'Caisse et float suivis au franc près',
    description:
      'Le solde de chaque puce vient du dernier SMS de l’opérateur, pas d’un calcul qui dérive. Une alerte quand le float descend sous votre seuil.',
    audience: 'agence',
  },
  {
    icon: 'building',
    title: 'Plusieurs agences, un seul patron',
    description:
      'Vos agents opèrent depuis leur téléphone ; vous voyez le détail de chaque agence depuis le vôtre, en temps réel.',
    audience: 'agence',
  },
  {
    icon: 'ussd',
    title: 'USSD en un geste',
    description:
      "Choisissez l'opération, le numéro et le montant : le code USSD est composé pour vous, le SMS de confirmation fait le reste.",
    audience: 'agence',
  },
  {
    icon: 'users',
    title: 'Fichier clients',
    description:
      'Nom, téléphone, CNIB et historique de chaque client, retrouvés à partir de son numéro.',
    audience: 'agence',
  },
  {
    icon: 'offline',
    title: 'Pensée pour fonctionner hors ligne',
    description:
      "Tout est enregistré sur votre téléphone. Internet ne sert qu'à la synchronisation et aux mises à jour.",
    audience: 'tous',
  },
  {
    icon: 'shield',
    title: 'Vos données protégées',
    description:
      'Code PIN, empreinte digitale, sauvegardes chiffrées par mot de passe. Vos dépenses personnelles ne quittent pas votre téléphone.',
    audience: 'tous',
  },
  {
    icon: 'export',
    title: 'Exports PDF et CSV',
    description:
      'Un relevé propre à imprimer ou à partager, ou un fichier à ouvrir dans Excel.',
    audience: 'tous',
  },
];

export const steps = [
  {
    title: 'Installez l’application',
    description: 'Téléchargez l’APK, choisissez « Pour moi » ou « Pour mon agence » et votre pays.',
  },
  {
    title: 'Cochez vos opérateurs',
    description:
      'Orange Money, Moov Money, Coris Money, Wave… sont déjà configurés pour votre pays.',
  },
  {
    title: 'Laissez faire vos SMS',
    description:
      'Chaque opération arrive toute seule dans l’application. Vous n’avez plus qu’à regarder.',
  },
];

export interface Plan {
  name: string;
  audience: string;
  price: string;
  unit?: string;
  period: string;
  description: string;
  features: string[];
  cta: string;
  highlighted?: boolean;
}

export const plans: Plan[] = [
  {
    name: 'Particulier',
    audience: 'Pour moi',
    price: '0',
    unit: 'FCFA',
    period: 'pour toujours',
    description: 'Tout pour suivre et maîtriser votre argent personnel. Sans limite, sans publicité.',
    features: [
      'Détection automatique de vos SMS',
      'Espèces, banque, épargne : tout votre argent',
      'Motifs de dépense et budget mensuel',
      'Import de vos anciens SMS, gratuit',
      'Plusieurs téléphones sur le même compte',
    ],
    cta: 'Télécharger gratuitement',
    highlighted: true,
  },
  {
    name: 'Agence — Mensuel',
    audience: 'Pour mon agence',
    price: '450',
    unit: 'FCFA',
    period: 'par mois et par agence',
    description: '3 mois d’essai offerts pour chaque nouvelle agence. Sans engagement.',
    features: [
      'Commissions automatiques',
      'Caisse et float par opérateur',
      'Clients, USSD, exports',
      'Vue patron multi-agence',
    ],
    cta: 'Essayer 3 mois gratuits',
  },
  {
    name: 'Agence — Annuel',
    audience: 'Pour mon agence',
    price: '4 480',
    unit: 'FCFA',
    period: 'par an et par agence',
    description: 'Environ deux mois offerts par rapport au mensuel.',
    features: [
      'Tout le mensuel',
      'Un seul paiement par an',
      'Support prioritaire',
    ],
    cta: 'Choisir l’annuel',
  },
];

export const faq = [
  {
    q: 'Est-ce vraiment gratuit pour un particulier ?',
    a: 'Oui. Le compte Particulier est gratuit, sans limite de durée ni de nombre d’opérations, import des anciens SMS compris.',
  },
  {
    q: 'Est-ce que l’application envoie mes SMS sur Internet ?',
    a: 'Non. Les SMS sont lus et analysés sur votre téléphone. Vos dépenses personnelles restent sur votre téléphone ; seul un compte Agence synchronise ses opérations avec le patron.',
  },
  {
    q: 'Et si je paie en espèces ?',
    a: 'Ajoutez-le en deux gestes depuis « Mon argent ». Vos espèces, votre banque et votre Mobile Money sont réunis dans le même tableau de bord.',
  },
  {
    q: 'Comment payer la licence d’une agence ?',
    a: 'Par Mobile Money. Votre licence est activée dès la validation, ou par une clé que nous vous envoyons et qui fonctionne même sans Internet.',
  },
  {
    q: 'Que se passe-t-il quand la licence d’une agence expire ?',
    a: 'Vos données restent consultables et les SMS reçus sont mis de côté : ils deviennent des opérations dès le renouvellement, rien n’est perdu.',
  },
  {
    q: 'J’ai changé de téléphone, je perds tout ?',
    a: 'Non. Reconnectez-vous avec votre numéro et votre mot de passe, ou restaurez une sauvegarde chiffrée.',
  },
];
