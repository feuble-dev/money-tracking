'use client';

import React, { useCallback, useEffect, useState } from 'react';
import Button from '@/components/ui/Button';
import Badge from '@/components/ui/Badge';
import CreateCountryModal from '@/components/admin/CreateCountryModal';
import EditCountryModal from '@/components/admin/EditCountryModal';
import ConfirmModal from '@/components/admin/ConfirmModal';
import CatalogTabs from '@/components/admin/CatalogTabs';
import { getCountries, deleteCountry } from '@/lib/api';

interface Country {
  id: number;
  code: string;
  name: string;
  dial_code: string;
  is_active: boolean;
  catalog_version: number;
}

export default function CountriesPage() {
  const [countries, setCountries] = useState<Country[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Country | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Country | null>(null);

  const loadCountries = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getCountries();
      setCountries(data);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadCountries();
  }, [loadCountries]);

  return (
    <div className="space-y-6">
      <CatalogTabs />
      <div className="flex items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-dark">Catalogue — Pays</h2>
          <p className="text-sm text-gray-500 mt-1">{countries.length} pays configuré(s)</p>
        </div>
        <Button variant="primary" onClick={() => setModalOpen(true)}>
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Ajouter un pays
        </Button>
      </div>

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
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Code</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Nom</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Indicatif</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Version catalogue</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Statut</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Opérateurs</th>
                  <th className="text-right px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody>
                {countries.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="text-center py-12 text-gray-400 text-sm">
                      Aucun pays configuré
                    </td>
                  </tr>
                ) : (
                  countries.map((country) => (
                    <tr key={country.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="px-6 py-4 text-sm font-mono font-medium text-primary">{country.code}</td>
                      <td className="px-6 py-4 text-sm text-dark font-medium">{country.name}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">{country.dial_code}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">v{country.catalog_version}</td>
                      <td className="px-6 py-4">
                        <Badge variant={country.is_active ? 'success' : 'neutral'}>
                          {country.is_active ? 'Actif' : 'Inactif'}
                        </Badge>
                      </td>
                      <td className="px-6 py-4">
                        <a
                          href={`/catalog/operators?country_id=${country.id}`}
                          className="text-sm font-medium text-primary hover:underline"
                        >
                          Voir les opérateurs
                        </a>
                      </td>
                      <td className="px-6 py-4 text-right">
                        <div className="flex items-center justify-end gap-3">
                          <button onClick={() => setEditTarget(country)} className="text-sm font-medium text-primary hover:underline">
                            Modifier
                          </button>
                          <button onClick={() => setDeleteTarget(country)} className="text-sm font-medium text-red-600 hover:underline">
                            Supprimer
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <CreateCountryModal isOpen={modalOpen} onClose={() => setModalOpen(false)} onCreated={loadCountries} />

      <EditCountryModal
        isOpen={!!editTarget}
        onClose={() => setEditTarget(null)}
        onUpdated={loadCountries}
        country={editTarget}
      />

      {deleteTarget && (
        <ConfirmModal
          isOpen={!!deleteTarget}
          onClose={() => setDeleteTarget(null)}
          onConfirm={async () => { await deleteCountry(deleteTarget.id); await loadCountries(); }}
          title={`Supprimer ${deleteTarget.name} ?`}
          message="Impossible si des opérateurs sont encore rattachés à ce pays — supprimez-les d'abord."
        />
      )}
    </div>
  );
}
