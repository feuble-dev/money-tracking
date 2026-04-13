'use client';

import React, { useEffect, useState, useCallback } from 'react';
import Button from '@/components/ui/Button';
import Badge from '@/components/ui/Badge';
import GenerateLicenceModal from '@/components/admin/GenerateLicenceModal';
import { getLicences } from '@/lib/api';

interface Licence {
  id: number;
  code: string;
  telephone: string;
  telephone_client?: string;
  device_id: string;
  duree: string;
  duree_mois?: number;
  montant: number;
  montant_paye?: number;
  statut: string;
  date_creation: string;
  created_at?: string;
  date_expiration: string;
  date_fin?: string;
}

const demoLicences: Licence[] = [
  {
    id: 1,
    code: 'MT-A1B2-C3D4',
    telephone: '+226 70 12 34 56',
    device_id: 'android-abc123',
    duree: 'annuel',
    montant: 10000,
    statut: 'active',
    date_creation: '2025-12-01',
    date_expiration: '2026-12-01',
  },
  {
    id: 2,
    code: 'MT-E5F6-G7H8',
    telephone: '+226 76 98 76 54',
    device_id: 'android-def456',
    duree: 'mensuel',
    montant: 1000,
    statut: 'active',
    date_creation: '2026-03-01',
    date_expiration: '2026-04-01',
  },
  {
    id: 3,
    code: 'MT-I9J0-K1L2',
    telephone: '+226 71 11 22 33',
    device_id: 'android-ghi789',
    duree: 'essai',
    montant: 0,
    statut: 'expirée',
    date_creation: '2026-02-15',
    date_expiration: '2026-03-17',
  },
  {
    id: 4,
    code: 'MT-M3N4-O5P6',
    telephone: '+226 65 44 55 66',
    device_id: 'android-jkl012',
    duree: 'annuel',
    montant: 10000,
    statut: 'active',
    date_creation: '2026-01-10',
    date_expiration: '2027-01-10',
  },
  {
    id: 5,
    code: 'MT-Q7R8-S9T0',
    telephone: '+226 78 77 88 99',
    device_id: 'android-mno345',
    duree: 'mensuel',
    montant: 1000,
    statut: 'active',
    date_creation: '2026-03-15',
    date_expiration: '2026-04-15',
  },
];

export default function LicencesPage() {
  const [licences, setLicences] = useState<Licence[]>([]);
  const [search, setSearch] = useState('');
  const [filterStatut, setFilterStatut] = useState<string>('all');
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);

  const loadLicences = useCallback(async () => {
    try {
      const data = await getLicences(search || undefined);
      setLicences(data.results || data);
    } catch {
      setLicences(demoLicences);
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    loadLicences();
  }, [loadLicences]);

  const filteredLicences = licences.filter((l) => {
    if (filterStatut !== 'all' && l.statut !== filterStatut) return false;
    if (search) {
      const q = search.toLowerCase();
      return (
        l.telephone.toLowerCase().includes(q) ||
        l.code.toLowerCase().includes(q) ||
        l.device_id.toLowerCase().includes(q)
      );
    }
    return true;
  });

  const getStatutBadge = (statut: string) => {
    switch (statut) {
      case 'active':
        return <Badge variant="success">Active</Badge>;
      case 'expirée':
        return <Badge variant="danger">Expirée</Badge>;
      case 'révoquée':
        return <Badge variant="warning">Révoquée</Badge>;
      default:
        return <Badge variant="neutral">{statut}</Badge>;
    }
  };

  const getDureeBadge = (duree: string) => {
    switch (duree) {
      case '12':
      case 'annuel':
        return <Badge variant="info">Annuel</Badge>;
      case '24':
        return <Badge variant="info">2 ans</Badge>;
      case '1':
      case 'mensuel':
        return <Badge variant="neutral">Mensuel</Badge>;
      case 'essai':
        return <Badge variant="warning">Essai</Badge>;
      default:
        return <Badge variant="neutral">{duree} mois</Badge>;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-dark">Licences</h2>
          <p className="text-sm text-gray-500 mt-1">
            {filteredLicences.length} licence(s) trouvée(s)
          </p>
        </div>
        <Button variant="primary" onClick={() => setModalOpen(true)}>
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Générer une licence
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
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
            placeholder="Rechercher par téléphone, code ou device..."
            className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
          />
        </div>
        <select
          value={filterStatut}
          onChange={(e) => setFilterStatut(e.target.value)}
          className="px-4 py-2.5 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
        >
          <option value="all">Tous les statuts</option>
          <option value="active">Active</option>
          <option value="expirée">Expirée</option>
          <option value="révoquée">Révoquée</option>
        </select>
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
                    Code
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Téléphone
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Durée
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Montant
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Expiration
                  </th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                    Statut
                  </th>
                </tr>
              </thead>
              <tbody>
                {filteredLicences.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center py-12 text-gray-400 text-sm">
                      Aucune licence trouvée
                    </td>
                  </tr>
                ) : (
                  filteredLicences.map((licence) => (
                    <tr key={licence.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="px-6 py-4 text-sm font-mono font-medium text-primary">
                        {licence.code}
                      </td>
                      <td className="px-6 py-4 text-sm text-dark font-medium">{licence.telephone_client ?? licence.telephone ?? '—'}</td>
                      <td className="px-6 py-4">{getDureeBadge(licence.duree_mois ? String(licence.duree_mois) : licence.duree)}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">
                        {(licence.montant_paye ?? licence.montant ?? 0).toLocaleString('fr-FR')} FCFA
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-600">{licence.date_fin ?? licence.date_expiration ?? '—'}</td>
                      <td className="px-6 py-4">{getStatutBadge(licence.statut)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modal */}
      <GenerateLicenceModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        onGenerated={loadLicences}
      />
    </div>
  );
}
