'use client';

import React, { useMemo, useState } from 'react';
import Icon from '@/components/site/Icon';
import Badge from '@/components/ui/Badge';
import Button from '@/components/ui/Button';
import Modal from '@/components/ui/Modal';
import DataTable, { type Column } from '@/components/admin/ui/DataTable';
import PageHeader from '@/components/admin/ui/PageHeader';
import Segmented from '@/components/admin/ui/Segmented';
import CopyField from '@/components/admin/ui/CopyField';
import { useAdmin } from '@/components/admin/shell/AdminContext';
import { getAchatsHistorique, validerAchatHistorique } from '@/lib/api';
import { useAsync } from '@/lib/useAsync';
import { apiError, type AchatHistorique } from '@/lib/admin-types';
import { ago, dateFr, fcfa } from '@/lib/format';

type Filtre = 'en_attente' | 'active' | 'toutes';

const statut: Record<AchatHistorique['statut'], { label: string; variant: 'warning' | 'success' | 'danger' }> = {
  en_attente: { label: 'À valider', variant: 'warning' },
  active: { label: 'Activé', variant: 'success' },
  rejete: { label: 'Rejeté', variant: 'danger' },
};

/**
 * Import des anciens SMS pour les agences (gratuit jusqu'à un an, puis
 * 200 FCFA par année — D5). Les Particuliers n'en ont pas besoin : c'est
 * gratuit pour eux et ne passe jamais par ici.
 */
export default function AchatsHistoriquePage() {
  const { toast, refreshCompteurs } = useAdmin();
  const { data, setData, loading, error, reload } = useAsync(getAchatsHistorique);
  const [filtre, setFiltre] = useState<Filtre>('en_attente');
  const [busy, setBusy] = useState<number | null>(null);
  const [token, setToken] = useState<string | null>(null);

  const all = data ?? [];
  const rows = useMemo(() => (filtre === 'toutes' ? all : all.filter((a) => a.statut === filtre)), [all, filtre]);
  const nb = (s: Filtre) => (s === 'toutes' ? all.length : all.filter((a) => a.statut === s).length);

  const valider = async (a: AchatHistorique) => {
    setBusy(a.id);
    try {
      const r = await validerAchatHistorique(a.id);
      setData((l) => (l ?? []).map((x) => (x.id === a.id ? { ...x, statut: 'active', token: r.token } : x)));
      setToken(r.token);
      refreshCompteurs();
    } catch (e) {
      toast(apiError(e, 'La validation a échoué'), 'error');
    } finally {
      setBusy(null);
    }
  };

  const columns: Column<AchatHistorique>[] = [
    {
      key: 'tel',
      header: 'Compte',
      sortValue: (a) => a.telephone,
      render: (a) => <span className="font-medium tabular-nums text-ink">{a.telephone}</span>,
    },
    {
      key: 'depuis',
      header: 'Import depuis',
      sortValue: (a) => a.date_debut_demandee ?? '',
      render: (a) => (a.date_debut_demandee ? dateFr(a.date_debut_demandee) : <span className="text-muted">—</span>),
    },
    {
      key: 'montant',
      header: 'Montant',
      sortValue: (a) => a.montant_paye,
      render: (a) => (a.montant_paye > 0 ? <span className="font-semibold tabular-nums">{fcfa(a.montant_paye)}</span> : <Badge variant="info">Gratuit</Badge>),
    },
    {
      key: 'statut',
      header: 'Statut',
      sortValue: (a) => a.statut,
      render: (a) => <Badge variant={statut[a.statut].variant} dot>{statut[a.statut].label}</Badge>,
    },
    {
      key: 'date',
      header: 'Demandé',
      hideOnMobile: true,
      sortValue: (a) => a.created_at,
      render: (a) => <span title={dateFr(a.created_at, true)} className="text-muted">{ago(a.created_at)}</span>,
    },
    {
      key: 'action',
      header: '',
      className: 'text-right',
      render: (a) =>
        a.statut === 'en_attente' ? (
          <Button size="sm" variant="accent" loading={busy === a.id} onClick={() => valider(a)}>
            Paiement reçu
          </Button>
        ) : a.token ? (
          <Button size="sm" variant="ghost" onClick={() => setToken(a.token)}>
            Voir le jeton
          </Button>
        ) : null,
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Import des anciens SMS"
        description="Agences uniquement : gratuit jusqu’à un an en arrière, puis 200 FCFA par année. Validez après réception du paiement."
      />
      <Segmented
        value={filtre}
        onChange={setFiltre}
        options={[
          { value: 'en_attente', label: `À valider · ${nb('en_attente')}` },
          { value: 'active', label: `Activés · ${nb('active')}` },
          { value: 'toutes', label: `Tous · ${nb('toutes')}` },
        ]}
      />
      <DataTable
        rows={rows}
        columns={columns}
        rowKey={(a) => a.id}
        loading={loading}
        error={error}
        searchText={(a) => a.telephone}
        searchPlaceholder="Numéro…"
        initialSort={{ key: 'date', dir: 'desc' }}
        emptyTitle={filtre === 'en_attente' ? 'Tout est traité' : 'Aucun achat'}
        toolbar={
          <Button variant="ghost" size="sm" onClick={reload}>
            <Icon name="sync" className="h-3.5 w-3.5" strokeWidth={2} />
            Actualiser
          </Button>
        }
      />
      <Modal isOpen={!!token} onClose={() => setToken(null)} title="Import activé">
        {token && (
          <div className="space-y-5">
            <p className="text-sm text-muted">
              L’application débloque l’import seule à sa prochaine connexion. En cas de besoin, transmettez ce jeton à l’agent.
            </p>
            <CopyField label="Jeton d’import" value={token} />
            <Button onClick={() => setToken(null)} className="w-full">Terminé</Button>
          </div>
        )}
      </Modal>
    </div>
  );
}
