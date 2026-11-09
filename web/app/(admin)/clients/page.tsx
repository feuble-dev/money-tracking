'use client';

import React, { Suspense, useMemo, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Badge from '@/components/ui/Badge';
import DataTable, { type Column } from '@/components/admin/ui/DataTable';
import PageHeader from '@/components/admin/ui/PageHeader';
import Segmented from '@/components/admin/ui/Segmented';
import { getClients } from '@/lib/api';
import { useAsync } from '@/lib/useAsync';
import type { ClientRow } from '@/lib/admin-types';
import { ago, dateFr } from '@/lib/format';

type Filtre = 'tous' | 'particulier' | 'agence';

export default function ClientsPage() {
  return (
    <Suspense>
      <Clients />
    </Suspense>
  );
}

function initials(c: Pick<ClientRow, 'nom' | 'prenom' | 'telephone'>) {
  const s = `${c.prenom?.[0] ?? ''}${c.nom?.[0] ?? ''}`.toUpperCase();
  return s || c.telephone.slice(-2);
}

function Clients() {
  const router = useRouter();
  const params = useSearchParams();
  const { data, loading, error } = useAsync(getClients);
  const [filtre, setFiltre] = useState<Filtre>('tous');

  const all = data ?? [];
  const rows = useMemo(() => (filtre === 'tous' ? all : all.filter((c) => c.account_type === filtre)), [all, filtre]);
  const nb = (t: Filtre) => (t === 'tous' ? all.length : all.filter((c) => c.account_type === t).length);

  const columns: Column<ClientRow>[] = [
    {
      key: 'compte',
      header: 'Compte',
      sortValue: (c) => c.telephone,
      render: (c) => (
        <div className="flex items-center gap-3">
          <span
            className={`flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full text-xs font-bold ${
              c.account_type === 'agence' ? 'bg-accent-50 text-accent' : 'bg-primary-50 text-primary'
            }`}
          >
            {initials(c)}
          </span>
          <div className="min-w-0">
            <p className="font-medium tabular-nums text-ink">{c.telephone}</p>
            <p className="truncate text-xs text-muted">{`${c.prenom} ${c.nom}`.trim() || 'Sans nom'}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Type',
      sortValue: (c) => c.account_type,
      render: (c) =>
        c.account_type === 'agence' ? <Badge variant="success">Agence</Badge> : <Badge variant="info">Particulier</Badge>,
    },
    {
      key: 'agences',
      header: 'Agences',
      hideOnMobile: true,
      sortValue: (c) => c.agences_count,
      render: (c) => (c.account_type === 'agence' ? <span className="tabular-nums">{c.agences_count}</span> : <span className="text-muted">—</span>),
    },
    {
      key: 'inscrit',
      header: 'Inscrit',
      sortValue: (c) => c.created_at,
      render: (c) => (
        <span title={dateFr(c.created_at, true)} className="text-muted">
          {ago(c.created_at)}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader title="Clients" description="Tous les comptes créés depuis l’application. Cliquez sur un compte pour sa fiche complète." />
      <Segmented
        value={filtre}
        onChange={setFiltre}
        options={[
          { value: 'tous', label: `Tous · ${nb('tous')}` },
          { value: 'particulier', label: `Particuliers · ${nb('particulier')}` },
          { value: 'agence', label: `Agences · ${nb('agence')}` },
        ]}
      />
      <DataTable
        rows={rows}
        columns={columns}
        rowKey={(c) => c.id}
        loading={loading}
        error={error}
        searchText={(c) => `${c.telephone} ${c.nom} ${c.prenom}`}
        searchPlaceholder="Numéro ou nom…"
        initialQuery={params.get('q') ?? ''}
        initialSort={{ key: 'inscrit', dir: 'desc' }}
        emptyTitle="Aucun compte"
        emptyText="Les comptes apparaissent dès la première inscription dans l’application."
        onRowClick={(c) => router.push(`/clients/${c.id}`)}
      />
    </div>
  );
}
