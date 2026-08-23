'use client';

import React, { useCallback, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Button from '@/components/ui/Button';
import Badge from '@/components/ui/Badge';
import CreateOperatorModal from '@/components/admin/CreateOperatorModal';
import CatalogTabs from '@/components/admin/CatalogTabs';
import { getOperators, getCountries } from '@/lib/api';

interface Operator {
  id: number;
  country: number;
  country_name: string;
  name: string;
  logo: string | null;
  sms_sender: string;
  is_active: boolean;
}

interface CountryOption {
  id: number;
  name: string;
}

export default function OperatorsPage() {
  const searchParams = useSearchParams();
  const countryIdParam = searchParams.get('country_id');

  const [operators, setOperators] = useState<Operator[]>([]);
  const [countries, setCountries] = useState<CountryOption[]>([]);
  const [countryFilter, setCountryFilter] = useState<number | ''>(countryIdParam ? Number(countryIdParam) : '');
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);

  const loadOperators = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getOperators(countryFilter || undefined);
      setOperators(data);
    } finally {
      setLoading(false);
    }
  }, [countryFilter]);

  useEffect(() => {
    getCountries().then(setCountries).catch(() => setCountries([]));
  }, []);

  useEffect(() => {
    loadOperators();
  }, [loadOperators]);

  return (
    <div className="space-y-6">
      <CatalogTabs />
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-dark">Catalogue — Opérateurs</h2>
          <p className="text-sm text-gray-500 mt-1">{operators.length} opérateur(s)</p>
        </div>
        <Button variant="primary" onClick={() => setModalOpen(true)}>
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Ajouter un opérateur
        </Button>
      </div>

      <select
        value={countryFilter}
        onChange={(e) => setCountryFilter(e.target.value ? Number(e.target.value) : '')}
        className="px-4 py-2.5 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
      >
        <option value="">Tous les pays</option>
        {countries.map((c) => (
          <option key={c.id} value={c.id}>{c.name}</option>
        ))}
      </select>

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
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Opérateur</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Pays</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Expéditeur SMS</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Statut</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Configuration</th>
                </tr>
              </thead>
              <tbody>
                {operators.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="text-center py-12 text-gray-400 text-sm">
                      Aucun opérateur trouvé
                    </td>
                  </tr>
                ) : (
                  operators.map((op) => (
                    <tr key={op.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="px-6 py-4 text-sm text-dark font-medium flex items-center gap-3">
                        {op.logo ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={op.logo} alt={op.name} className="w-8 h-8 rounded-lg object-cover" />
                        ) : (
                          <div className="w-8 h-8 rounded-lg bg-primary-50 flex items-center justify-center text-primary text-xs font-bold">
                            {op.name.charAt(0)}
                          </div>
                        )}
                        {op.name}
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-600">{op.country_name}</td>
                      <td className="px-6 py-4 text-sm text-gray-600 font-mono">{op.sms_sender || '—'}</td>
                      <td className="px-6 py-4">
                        <Badge variant={op.is_active ? 'success' : 'neutral'}>
                          {op.is_active ? 'Actif' : 'Inactif'}
                        </Badge>
                      </td>
                      <td className="px-6 py-4">
                        <a href={`/catalog/operators/${op.id}`} className="text-sm font-medium text-primary hover:underline">
                          Gérer les types &amp; patterns
                        </a>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <CreateOperatorModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        onCreated={loadOperators}
        defaultCountryId={countryFilter || undefined}
      />
    </div>
  );
}
