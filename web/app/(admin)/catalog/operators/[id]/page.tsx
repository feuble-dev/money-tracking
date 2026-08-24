'use client';

import React, { useCallback, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import Button from '@/components/ui/Button';
import Badge from '@/components/ui/Badge';
import AttachTransactionTypeModal from '@/components/admin/AttachTransactionTypeModal';
import CreateSmsPatternModal from '@/components/admin/CreateSmsPatternModal';
import EditOperatorTypeModal from '@/components/admin/EditOperatorTypeModal';
import ConfirmModal from '@/components/admin/ConfirmModal';
import { getOperatorDetail, getSmsPatterns, deleteSmsPattern, deleteOperatorType } from '@/lib/api';

interface OperatorTypeLink {
  id: number;
  transaction_type: number;
  transaction_type_label: string;
  transaction_type_code: string;
  transaction_type_direction: 'in' | 'out';
  ussd_code: string;
  commission_taux: string;
  is_active: boolean;
}

interface OperatorDetail {
  id: number;
  name: string;
  logo: string | null;
  country_name: string;
  sms_sender: string;
  transaction_types: OperatorTypeLink[];
}

interface SmsPattern {
  id: number;
  raw_example: string;
  tagged_zones: { start: number; end: number; fieldName: string }[];
  direction_override: 'in' | 'out' | null;
  cible_compte: 'tous' | 'particulier' | 'agence';
}

export default function OperatorDetailPage() {
  const params = useParams<{ id: string }>();
  const operatorId = Number(params.id);

  const [operator, setOperator] = useState<OperatorDetail | null>(null);
  const [patternsByLink, setPatternsByLink] = useState<Record<number, SmsPattern[]>>({});
  const [loading, setLoading] = useState(true);
  const [attachModalOpen, setAttachModalOpen] = useState(false);
  const [patternModalLink, setPatternModalLink] = useState<OperatorTypeLink | null>(null);
  const [editLink, setEditLink] = useState<OperatorTypeLink | null>(null);
  const [deleteLink, setDeleteLink] = useState<OperatorTypeLink | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data: OperatorDetail = await getOperatorDetail(operatorId);
      setOperator(data);
      const entries = await Promise.all(
        data.transaction_types.map(async (link) => [link.id, await getSmsPatterns(link.id)] as const)
      );
      setPatternsByLink(Object.fromEntries(entries));
    } finally {
      setLoading(false);
    }
  }, [operatorId]);

  useEffect(() => {
    load();
  }, [load]);

  if (loading || !operator) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <Link href="/catalog/operators" className="inline-flex items-center gap-1.5 text-sm text-muted hover:text-primary transition-colors">
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
        </svg>
        Retour aux opérateurs
      </Link>
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          {operator.logo ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={operator.logo} alt={operator.name} className="w-12 h-12 rounded-xl object-cover" />
          ) : (
            <div className="w-12 h-12 rounded-xl bg-primary-50 flex items-center justify-center text-primary font-bold">
              {operator.name.charAt(0)}
            </div>
          )}
          <div>
            <h2 className="text-2xl font-bold text-dark">{operator.name}</h2>
            <p className="text-sm text-gray-500">
              {operator.country_name} - expéditeur SMS : {operator.sms_sender || '-'}
            </p>
          </div>
        </div>
        <Button variant="primary" onClick={() => setAttachModalOpen(true)}>
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Activer un type
        </Button>
      </div>

      <div className="space-y-4">
        {operator.transaction_types.length === 0 ? (
          <div className="bg-white rounded-2xl border border-gray-100 p-12 text-center text-gray-400 text-sm">
            Aucun type de transaction activé pour cet opérateur.
          </div>
        ) : (
          operator.transaction_types.map((link) => (
            <div key={link.id} className="bg-white rounded-2xl border border-gray-100 p-6">
              <div className="flex items-center justify-between gap-4 mb-4">
                <div className="flex items-center gap-3">
                  <h3 className="text-lg font-bold text-dark">{link.transaction_type_label}</h3>
                  <Badge variant={link.transaction_type_direction === 'in' ? 'info' : 'warning'}>
                    {link.transaction_type_direction === 'in' ? 'Entrant (défaut)' : 'Sortant (défaut)'}
                  </Badge>
                  <Badge variant={link.is_active ? 'success' : 'neutral'}>
                    {link.is_active ? 'Actif' : 'Inactif'}
                  </Badge>
                </div>
                <div className="flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() => setEditLink(link)}
                    className="text-sm font-medium text-primary hover:underline"
                  >
                    Modifier
                  </button>
                  <button
                    type="button"
                    onClick={() => setDeleteLink(link)}
                    className="text-sm font-medium text-red-600 hover:underline"
                  >
                    Supprimer
                  </button>
                  <Button variant="ghost" size="sm" onClick={() => setPatternModalLink(link)}>
                    + Pattern SMS
                  </Button>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
                <div>
                  <span className="text-gray-400">USSD : </span>
                  <span className="font-mono text-dark">{link.ussd_code || '-'}</span>
                </div>
                <div>
                  <span className="text-gray-400">Commission : </span>
                  <span className="text-dark">{link.commission_taux}%</span>
                </div>
              </div>
              <div className="space-y-2">
                {(patternsByLink[link.id] ?? []).length === 0 ? (
                  <p className="text-xs text-gray-400">Aucun pattern SMS configuré.</p>
                ) : (
                  (patternsByLink[link.id] ?? []).map((p) => (
                    <div key={p.id} className="bg-soft rounded-xl p-3 text-xs">
                      <div className="flex items-center justify-between mb-1">
                        <span className="font-mono text-gray-500 flex items-center gap-2">
                          {p.tagged_zones.length} zone(s) taguée(s)
                          {p.direction_override && (
                            <> - sens : {p.direction_override === 'in' ? 'entrant' : 'sortant'} (override)</>
                          )}
                          <span className={`px-1.5 py-0.5 rounded text-[10px] font-sans font-semibold ${
                            p.cible_compte === 'particulier' ? 'bg-blue-50 text-blue-600'
                              : p.cible_compte === 'agence' ? 'bg-purple-50 text-purple-600'
                              : 'bg-gray-100 text-gray-500'
                          }`}>
                            {p.cible_compte === 'particulier' ? 'Particulier' : p.cible_compte === 'agence' ? 'Agence' : 'Tous'}
                          </span>
                        </span>
                        <button
                          type="button"
                          onClick={async () => {
                            await deleteSmsPattern(p.id);
                            load();
                          }}
                          className="text-red-500 hover:text-red-700"
                        >
                          Supprimer
                        </button>
                      </div>
                      <p className="font-mono text-gray-700">{p.raw_example}</p>
                    </div>
                  ))
                )}
              </div>
            </div>
          ))
        )}
      </div>

      <AttachTransactionTypeModal
        isOpen={attachModalOpen}
        onClose={() => setAttachModalOpen(false)}
        onAttached={load}
        operatorId={operator.id}
        alreadyAttachedTypeIds={operator.transaction_types.map((l) => l.transaction_type)}
      />

      {patternModalLink && (
        <CreateSmsPatternModal
          isOpen={!!patternModalLink}
          onClose={() => setPatternModalLink(null)}
          onCreated={load}
          operatorTransactionTypeId={patternModalLink.id}
          defaultDirection={patternModalLink.transaction_type_direction}
        />
      )}

      <EditOperatorTypeModal
        isOpen={!!editLink}
        onClose={() => setEditLink(null)}
        onUpdated={load}
        link={editLink}
      />

      {deleteLink && (
        <ConfirmModal
          isOpen={!!deleteLink}
          onClose={() => setDeleteLink(null)}
          onConfirm={async () => { await deleteOperatorType(deleteLink.id); await load(); }}
          title={`Retirer ${deleteLink.transaction_type_label} de cet opérateur ?`}
          message="Impossible si des patterns SMS sont encore rattachés à cette association - supprimez-les d'abord."
        />
      )}
    </div>
  );
}
