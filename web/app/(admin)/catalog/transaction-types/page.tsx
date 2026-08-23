'use client';

import React, { useCallback, useEffect, useState } from 'react';
import Button from '@/components/ui/Button';
import Badge from '@/components/ui/Badge';
import CreateTransactionTypeModal from '@/components/admin/CreateTransactionTypeModal';
import CatalogTabs from '@/components/admin/CatalogTabs';
import { getTransactionTypes } from '@/lib/api';

interface TransactionType {
  id: number;
  code: string;
  label: string;
  default_direction: 'in' | 'out';
  is_active: boolean;
}

export default function TransactionTypesPage() {
  const [types, setTypes] = useState<TransactionType[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);

  const loadTypes = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getTransactionTypes();
      setTypes(data);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTypes();
  }, [loadTypes]);

  return (
    <div className="space-y-6">
      <CatalogTabs />
      <div className="flex items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-dark">Catalogue — Types de transaction</h2>
          <p className="text-sm text-gray-500 mt-1">
            {types.length} type(s) — catalogue global, réutilisable par tous les opérateurs (D3)
          </p>
        </div>
        <Button variant="primary" onClick={() => setModalOpen(true)}>
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Créer un type
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
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Libellé</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Sens par défaut</th>
                  <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Statut</th>
                </tr>
              </thead>
              <tbody>
                {types.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="text-center py-12 text-gray-400 text-sm">
                      Aucun type créé
                    </td>
                  </tr>
                ) : (
                  types.map((t) => (
                    <tr key={t.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="px-6 py-4 text-sm font-mono text-primary">{t.code}</td>
                      <td className="px-6 py-4 text-sm text-dark font-medium">{t.label}</td>
                      <td className="px-6 py-4">
                        <Badge variant={t.default_direction === 'in' ? 'info' : 'warning'}>
                          {t.default_direction === 'in' ? 'Entrant' : 'Sortant'}
                        </Badge>
                      </td>
                      <td className="px-6 py-4">
                        <Badge variant={t.is_active ? 'success' : 'neutral'}>
                          {t.is_active ? 'Actif' : 'Inactif'}
                        </Badge>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <CreateTransactionTypeModal isOpen={modalOpen} onClose={() => setModalOpen(false)} onCreated={loadTypes} />
    </div>
  );
}
