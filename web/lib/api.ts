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
  telephone: string;
  device_id: string;
  duree: string;
  montant: number;
}) {
  const res = await api.post('/admin/licences/', data);
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
