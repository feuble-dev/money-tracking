/** Formes des réponses de l'API admin (backend/licences/admin_*.py). */

export interface Point {
  date: string;
  value: number;
}

export interface Delta {
  value: number;
  delta: number | null;
}

export interface Analytics {
  periode_jours: number;
  kpis: {
    revenus: Delta;
    mrr: number;
    nouveaux_comptes: Delta;
    comptes_total: number;
    particuliers: number;
    agences_comptes: number;
    agences_actives: number;
    volume_synchronise: Delta;
    transactions_synchronisees: number;
    appareils_actifs_30j: number;
    conversion_essai: number | null;
    demandes_en_attente: number;
    achats_en_attente: number;
  };
  series: {
    revenus: Point[];
    inscriptions_particulier: Point[];
    inscriptions_agence: Point[];
    volume: Point[];
  };
  licences: { payantes: number; essai: number; suspendues: number; expirees: number };
  expirent_bientot: {
    id: number;
    agence_id: number;
    agence: string;
    telephone: string;
    statut: string;
    date_fin: string;
    jours: number;
  }[];
  top_agences: { id: number; nom: string; telephone: string; volume: number; transactions: number }[];
  operateurs: { nom: string; volume: number; transactions: number }[];
  activite: { type: 'compte' | 'paiement' | 'demande'; texte: string; detail: string; date: string }[];
}

export interface Compteurs {
  demandes: number;
  achats: number;
  expirent: number;
}

export interface SearchResults {
  clients: { id: number; telephone: string; nom: string; type: string }[];
  agences: { id: number; nom: string; client_id: number; telephone: string }[];
  licences: { id: number; code: string; agence: string; client_id: number }[];
}

export type LicenceStatut = 'essai' | 'active' | 'expiree' | 'suspendue';

export interface Licence {
  id: number;
  code: string;
  cle_hors_ligne: string | null;
  agence: number;
  agence_nom: string;
  telephone_client: string;
  account_type: 'particulier' | 'agence';
  device_id: string;
  date_debut: string;
  date_fin: string;
  duree_mois: number;
  montant_paye: number;
  statut: LicenceStatut;
  created_at: string;
}

export interface ClientRow {
  id: number;
  telephone: string;
  nom: string;
  prenom: string;
  account_type: 'particulier' | 'agence';
  created_at: string;
  agences_count: number;
}

export interface ClientDetail {
  id: number;
  telephone: string;
  nom: string;
  prenom: string;
  account_type: 'particulier' | 'agence';
  a_mot_de_passe: boolean;
  created_at: string;
  agences: {
    id: number;
    nom: string;
    is_active: boolean;
    created_at: string;
    licence: { id: number; statut: LicenceStatut; date_fin: string; jours: number; code: string } | null;
    appareils_licencies: number;
    transactions_synchronisees: number;
    volume_synchronise: number;
  }[];
  appareils: { id: number; device: string; origine: string; created_at: string; last_used_at: string | null }[];
  paiements: { id: number; agence: string; montant: number; duree_mois: number; date: string }[];
}

export interface Demande {
  id: number;
  telephone: string;
  device_id: string;
  agence: number | null;
  agence_nom: string | null;
  duree_mois: number;
  montant: number;
  statut: 'en_attente' | 'validee' | 'rejetee';
  note: string;
  licence: number | null;
  created_at: string;
}

export interface AchatHistorique {
  id: number;
  telephone: string;
  device_id: string;
  date_debut_demandee: string | null;
  statut: 'en_attente' | 'active' | 'rejete';
  token: string | null;
  montant_paye: number;
  created_at: string;
}

export interface NotificationRow {
  id: number;
  titre: string;
  message: string;
  cible: 'all' | 'individual' | 'group';
  telephones: string;
  created_at: string;
}

/** Message d'erreur lisible depuis une réponse d'API (champ `erreur` du backend). */
export function apiError(err: unknown, fallback = 'Une erreur est survenue'): string {
  const e = err as { response?: { data?: { erreur?: string; detail?: string } }; message?: string };
  return e?.response?.data?.erreur || e?.response?.data?.detail || fallback;
}
