'use client';

import React, { useEffect, useState, useCallback } from 'react';
import Badge from '@/components/ui/Badge';
import { getClients } from '@/lib/api';

interface Client {
  id: number;
  telephone: string;
  nom: string;
  device_id: string;
  licence_status: string;
  derniere_activite: string;
  date_inscription: string;
}

const demoClients: Client[] = [
  {
    id: 1,
    telephone: '+226 70 12 34 56',
    nom: 'Ouédraogo Ibrahim',
    device_id: 'android-abc123',
    licence_status: 'active',
    derniere_activite: '2026-03-29',
    date_inscription: '2025-11-15',
  },
  {
    id: 2,
    telephone: '+226 76 98 76 54',
    nom: 'Traoré Aminata',
    device_id: 'android-def456',
    licence_status: 'active',
    derniere_activite: '2026-03-28',
    date_inscription: '2026-01-05',
  },
  {
    id: 3,
    telephone: '+226 71 11 22 33',
    nom: 'Compaoré Moussa',
    device_id: 'android-ghi789',
    licence_status: 'expirée',
    derniere_activite: '2026-03-15',
    date_inscription: '2026-02-10',
  },
  {
    id: 4,
    telephone: '+226 65 44 55 66',
    nom: 'Kaboré Fatimata',
    device_id: 'android-jkl012',
    licence_status: 'active',
    derniere_activite: '2026-03-30',
    date_inscription: '2026-01-20',
  },
  {
    id: 5,
    telephone: '+226 78 77 88 99',
    nom: 'Sawadogo Boureima',
    device_id: 'android-mno345',
    licence_status: 'active',
    derniere_activite: '2026-03-27',
    date_inscription: '2026-03-01',
  },
  {
    id: 6,
    telephone: '+226 70 55 66 77',
    nom: 'Zongo Adama',
    device_id: 'android-pqr678',
    licence_status: 'essai',
    derniere_activite: '2026-03-30',
    date_inscription: '2026-03-25',
  },
];

export default function ClientsPage() {
  const [clients, setClients] = useState<Client[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  const loadClients = useCallback(async () => {
    try {
      const data = await getClients(search || undefined);
      setClients(data.results || data);
    } catch {
      setClients(demoClients);
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    loadClients();
  }, [loadClients]);

  const filteredClients = clients.filter((c) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      c.telephone.toLowerCase().includes(q) ||
      c.nom.toLowerCase().includes(q) ||
      c.device_id.toLowerCase().includes(q)
    );
  });

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'active':
        return <Badge variant="success">Active</Badge>;
      case 'expirée':
        return <Badge variant="danger">Expirée</Badge>;
      case 'essai':
        return <Badge variant="warning">Essai</Badge>;
      default:
        return <Badge variant="neutral">{status}</Badge>;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold text-dark">Clients</h2>
        <p className="text-sm text-gray-500 mt-1">
          {filteredClients.length} client(s) enregistré(s)
        </p>
      </div>

      {/* Search */}
      <div className="relative max-w-md">
        <svg
          className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Rechercher par nom, téléphone ou device..."
          className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
        />
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50/50">
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Client
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Téléphone
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Device ID
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Licence
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Dernière activité
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Inscription
                  </th>
                </tr>
              </thead>
              <tbody>
                {filteredClients.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center py-12 text-gray-400 text-sm">
                      Aucun client trouvé
                    </td>
                  </tr>
                ) : (
                  filteredClients.map((client) => (
                    <tr key={client.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-full bg-primary/10 text-primary flex items-center justify-center text-sm font-bold">
                            {client.nom.charAt(0)}
                          </div>
                          <span className="text-sm font-medium text-dark">{client.nom}</span>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-600">{client.telephone}</td>
                      <td className="px-6 py-4 text-sm font-mono text-gray-500">{client.device_id}</td>
                      <td className="px-6 py-4">{getStatusBadge(client.licence_status)}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">{client.derniere_activite}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">{client.date_inscription}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
