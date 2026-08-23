import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: `${API_URL}/api`,
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('admin_token');
    if (token) {
      config.headers.Authorization = `Token ${token}`;
    }
  }
  // Le Content-Type par défaut de l'instance (application/json) écrase
  // sinon la détection automatique du multipart par axios pour un upload
  // de fichier (ex: logo d'opérateur) — DRF refuse alors le fichier avec
  // "La donnée soumise n'est pas un fichier".
  if (config.data instanceof FormData) {
    config.headers.delete('Content-Type');
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && typeof window !== 'undefined') {
      localStorage.removeItem('admin_token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Auth
export async function login(username: string, password: string) {
  const res = await api.post('/admin/login/', { username, password });
  return res.data;
}

// Dashboard stats
export async function getStats() {
  const res = await api.get('/admin/stats/');
  return res.data;
}

// Licences
export async function getLicences(search?: string) {
  const params = search ? { search } : {};
  const res = await api.get('/admin/licences/', { params });
  return res.data;
}

export async function genererLicence(data: {
  agence_id: number;
  duree_mois: number;
  montant_paye: number;
  device_id?: string;
}) {
  const res = await api.post('/admin/licences/generer/', data);
  return res.data;
}

// Agences (unité facturable — une par agence, D8)
export async function getAgences(clientId?: number) {
  const params = clientId ? { client_id: clientId } : {};
  const res = await api.get('/admin/agences/', { params });
  return res.data;
}

// Grille tarifaire (PricingTier, D4)
export async function getPricingTiers() {
  const res = await api.get('/admin/pricing-tiers/');
  return res.data;
}

export async function updatePricingTier(id: number, data: Partial<{ remise_pct: number; is_active: boolean }>) {
  const res = await api.patch(`/admin/pricing-tiers/${id}/`, data);
  return res.data;
}

// Catalogue — Pays
export async function getCountries() {
  const res = await api.get('/admin/catalog/countries/');
  return res.data;
}

export async function createCountry(data: { code: string; name: string; dial_code: string }) {
  const res = await api.post('/admin/catalog/countries/', data);
  return res.data;
}

export async function updateCountry(id: number, data: Partial<{ name: string; dial_code: string; is_active: boolean }>) {
  const res = await api.patch(`/admin/catalog/countries/${id}/`, data);
  return res.data;
}

// Catalogue — Opérateurs (POST en FormData pour le logo)
export async function getOperators(countryId?: number) {
  const params = countryId ? { country_id: countryId } : {};
  const res = await api.get('/admin/catalog/operators/', { params });
  return res.data;
}

export async function getOperatorDetail(id: number) {
  const res = await api.get(`/admin/catalog/operators/${id}/`);
  return res.data;
}

export async function createOperator(data: FormData) {
  const res = await api.post('/admin/catalog/operators/', data);
  return res.data;
}

export async function updateOperator(id: number, data: FormData | Partial<{ name: string; sms_sender: string; is_active: boolean }>) {
  const res = await api.patch(`/admin/catalog/operators/${id}/`, data);
  return res.data;
}

// Catalogue — Types de transaction (catalogue GLOBAL, D3)
export async function getTransactionTypes() {
  const res = await api.get('/admin/catalog/transaction-types/');
  return res.data;
}

export async function createTransactionType(data: { code: string; label: string; default_direction: 'in' | 'out' }) {
  const res = await api.post('/admin/catalog/transaction-types/', data);
  return res.data;
}

export async function updateTransactionType(id: number, data: Partial<{ label: string; default_direction: string; is_active: boolean }>) {
  const res = await api.patch(`/admin/catalog/transaction-types/${id}/`, data);
  return res.data;
}

// Catalogue — Liaison Opérateur x Type (USSD/commission propres à la paire)
export async function getOperatorTypes(operatorId?: number) {
  const params = operatorId ? { operator_id: operatorId } : {};
  const res = await api.get('/admin/catalog/operator-types/', { params });
  return res.data;
}

export async function attachTransactionType(data: {
  operator: number;
  transaction_type: number;
  ussd_code?: string;
  commission_taux?: number;
}) {
  const res = await api.post('/admin/catalog/operator-types/', data);
  return res.data;
}

export async function updateOperatorType(id: number, data: Partial<{ ussd_code: string; commission_taux: number; is_active: boolean }>) {
  const res = await api.patch(`/admin/catalog/operator-types/${id}/`, data);
  return res.data;
}

export async function deleteOperatorType(id: number) {
  const res = await api.delete(`/admin/catalog/operator-types/${id}/`);
  return res.data;
}

// Catalogue — Patterns SMS (raw_example + tagged_zones, pas de regex côté web — D2)
export async function getSmsPatterns(operatorTransactionTypeId: number) {
  const res = await api.get('/admin/catalog/sms-patterns/', {
    params: { operator_transaction_type_id: operatorTransactionTypeId },
  });
  return res.data;
}

export async function createSmsPattern(data: {
  operator_transaction_type: number;
  raw_example: string;
  tagged_zones: { start: number; end: number; fieldName: string }[];
  direction_override?: 'in' | 'out' | null;
  cible_compte?: 'tous' | 'particulier' | 'agence';
}) {
  const res = await api.post('/admin/catalog/sms-patterns/', data);
  return res.data;
}

export async function deleteSmsPattern(id: number) {
  const res = await api.delete(`/admin/catalog/sms-patterns/${id}/`);
  return res.data;
}

// Demandes
export async function getDemandes() {
  const res = await api.get('/admin/demandes/');
  return res.data;
}

export async function validerDemande(id: number) {
  const res = await api.post(`/admin/demandes/${id}/valider/`);
  return res.data;
}

export async function rejeterDemande(id: number, motif: string) {
  const res = await api.post(`/admin/demandes/${id}/rejeter/`, { motif });
  return res.data;
}

// Clients
export async function getClients(search?: string) {
  const params = search ? { search } : {};
  const res = await api.get('/admin/clients/', { params });
  return res.data;
}

// Notifications
export async function getNotifications() {
  const res = await api.get('/admin/notifications/');
  return res.data;
}

export async function envoyerNotification(data: {
  titre: string;
  message: string;
  cible: 'all' | 'individual' | 'group';
  telephones?: string;
}) {
  const res = await api.post('/admin/notifications/envoyer/', data);
  return res.data;
}

// Achats Historique
export async function getAchatsHistorique() {
  const res = await api.get('/admin/achats-historique/');
  return res.data;
}

export async function validerAchatHistorique(id: number) {
  const res = await api.post(`/admin/achats-historique/${id}/valider/`);
  return res.data;
}

export default api;
