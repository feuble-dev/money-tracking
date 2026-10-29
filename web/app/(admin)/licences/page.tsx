'use client';

import React, { Suspense, useMemo, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import Icon from '@/components/site/Icon';
import Badge from '@/components/ui/Badge';
import Button from '@/components/ui/Button';
import Modal from '@/components/ui/Modal';
import DataTable, { type Column } from '@/components/admin/ui/DataTable';
import PageHeader from '@/components/admin/ui/PageHeader';
import Segmented from '@/components/admin/ui/Segmented';
import CopyField from '@/components/admin/ui/CopyField';
import GenerateLicenceModal from '@/components/admin/GenerateLicenceModal';
import { useAdmin } from '@/components/admin/shell/AdminContext';
import { getLicences, licenceAction } from '@/lib/api';
import { useAsync } from '@/lib/useAsync';
import { apiError, type Licence } from '@/lib/admin-types';
import { daysLeft as daysUntil, effectiveStatut, statutBadge } from '@/lib/licence-status';
import { dateFr, fcfa } from '@/lib/format';

type Filtre = 'toutes' | 'en_cours' | 'bientot' | 'expirees' | 'suspendues';

const daysLeft = (l: Licence) => daysUntil(l.date_fin);

export default function LicencesPage() {
  return (
    <Suspense>
      <Licences />
    </Suspense>
  );
}

function Licences() {
  const params = useSearchParams();
  const { toast, refreshCompteurs } = useAdmin();
  const { data, setData, loading, error, reload } = useAsync(getLicences);
  const [filtre, setFiltre] = useState<Filtre>('en_cours');
  const [showGenerate, setShowGenerate] = useState(false);
  const [selected, setSelected] = useState<Licence | null>(null);
  const [busy, setBusy] = useState(false);

  // Les comptes Particulier sont gratuits : leurs licences n'ont rien à gérer.
  const agenceLicences = useMemo(() => (data ?? []).filter((l) => l.account_type !== 'particulier'), [data]);

  const counts = useMemo(() => {
    const c = { toutes: agenceLicences.length, en_cours: 0, bientot: 0, expirees: 0, suspendues: 0 };
    for (const l of agenceLicences) {
      const s = effectiveStatut(l);
      if (s === 'suspendue') c.suspendues++;
      else if (s === 'expiree') c.expirees++;
      else {
        c.en_cours++;
        if (daysLeft(l) <= 14) c.bientot++;
      }
    }
    return c;
  }, [agenceLicences]);

  const rows = useMemo(
    () =>
      agenceLicences.filter((l) => {
        const s = effectiveStatut(l);
        switch (filtre) {
          case 'en_cours': return s === 'active' || s === 'essai';
          case 'bientot': return (s === 'active' || s === 'essai') && daysLeft(l) <= 14;
          case 'expirees': return s === 'expiree';
          case 'suspendues': return s === 'suspendue';
          default: return true;
        }
      }),
    [agenceLicences, filtre],
  );

  const toggleSuspension = async (l: Licence) => {
    const action = l.statut === 'suspendue' ? 'reactiver' : 'suspendre';
    setBusy(true);
    try {
      const r = await licenceAction(l.id, action);
      setData((list) => (list ?? []).map((x) => (x.id === l.id ? { ...x, statut: r.statut } : x)));
      setSelected((s) => (s && s.id === l.id ? { ...s, statut: r.statut } : s));
      toast(action === 'suspendre' ? 'Licence suspendue' : 'Licence réactivée');
      refreshCompteurs();
    } catch (e) {
      toast(apiError(e), 'error');
    } finally {
      setBusy(false);
    }
  };

  const columns: Column<Licence>[] = [
    {
      key: 'agence',
      header: 'Agence',
      sortValue: (l) => l.agence_nom.toLowerCase(),
      render: (l) => (
        <div className="min-w-0">
          <p className="truncate font-medium text-ink">{l.agence_nom}</p>
          <p className="text-xs text-muted">{l.telephone_client}</p>
        </div>
      ),
    },
    {
      key: 'statut',
      header: 'Statut',
      sortValue: (l) => effectiveStatut(l),
      render: (l) => {
        const b = statutBadge[effectiveStatut(l)];
        return <Badge variant={b.variant} dot>{b.label}</Badge>;
      },
    },
    {
      key: 'fin',
      header: 'Fin',
      sortValue: (l) => l.date_fin,
      render: (l) => {
        const s = effectiveStatut(l);
        const d = daysLeft(l);
        return (
          <div>
            <p className="tabular-nums text-ink">{dateFr(l.date_fin)}</p>
            {(s === 'active' || s === 'essai') && (
              <p className={`text-xs ${d <= 7 ? 'font-medium text-amber-700' : 'text-muted'}`}>
                {d <= 0 ? 'expire aujourd’hui' : `dans ${d} j`}
              </p>
            )}
          </div>
        );
      },
    },
    {
      key: 'duree',
      header: 'Durée',
      hideOnMobile: true,
      sortValue: (l) => l.duree_mois,
      render: (l) => <span className="tabular-nums">{l.duree_mois} mois</span>,
    },
    {
      key: 'montant',
      header: 'Payé',
      hideOnMobile: true,
      sortValue: (l) => l.montant_paye,
      className: 'text-right',
      render: (l) => (l.montant_paye > 0 ? <span className="tabular-nums">{fcfa(l.montant_paye)}</span> : <span className="text-muted">—</span>),
    },
    {
      key: 'cree',
      header: 'Créée le',
      hideOnMobile: true,
      sortValue: (l) => l.created_at,
      render: (l) => <span className="text-muted">{dateFr(l.created_at)}</span>,
    },
  ];

  const filters: { value: Filtre; label: string }[] = [
    { value: 'toutes', label: `Toutes · ${counts.toutes}` },
    { value: 'en_cours', label: `En cours · ${counts.en_cours}` },
    { value: 'bientot', label: `Bientôt · ${counts.bientot}` },
    { value: 'expirees', label: `Expirées · ${counts.expirees}` },
    { value: 'suspendues', label: `Suspendues · ${counts.suspendues}` },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Licences"
        description="Une licence par agence et par téléphone. Les comptes Particulier sont gratuits et n’apparaissent pas ici."
        actions={
          <Button onClick={() => setShowGenerate(true)}>
            <Icon name="plus" className="h-4 w-4" strokeWidth={2} />
            Nouvelle licence
          </Button>
        }
      />

      <div className="-mx-1 overflow-x-auto px-1">
        <Segmented value={filtre} options={filters} onChange={setFiltre} />
      </div>

      <DataTable
        rows={rows}
        columns={columns}
        rowKey={(l) => l.id}
        loading={loading}
        error={error}
        searchText={(l) => `${l.agence_nom} ${l.telephone_client} ${l.code} ${l.cle_hors_ligne ?? ''}`}
        searchPlaceholder="Agence, numéro, code…"
        initialQuery={params.get('q') ?? ''}
        initialSort={{ key: 'fin', dir: 'asc' }}
        emptyTitle="Aucune licence"
        emptyText="Les licences apparaissent dès qu’une agence est créée depuis l’application."
        onRowClick={setSelected}
        toolbar={
          <Button variant="ghost" size="sm" onClick={reload}>
            <Icon name="sync" className="h-3.5 w-3.5" strokeWidth={2} />
            Actualiser
          </Button>
        }
      />

      <Modal isOpen={!!selected} onClose={() => setSelected(null)} title={selected?.agence_nom ?? ''} description={selected?.telephone_client}>
        {selected && (
          <LicenceDetail licence={selected} busy={busy} onToggle={() => toggleSuspension(selected)} />
        )}
      </Modal>

      <GenerateLicenceModal isOpen={showGenerate} onClose={() => setShowGenerate(false)} onGenerated={reload} />
    </div>
  );
}

function LicenceDetail({ licence: l, busy, onToggle }: { licence: Licence; busy: boolean; onToggle: () => void }) {
  const s = effectiveStatut(l);
  const b = statutBadge[s];
  return (
    <div className="space-y-5">
      <dl className="grid grid-cols-2 gap-4 text-sm">
        <Info label="Statut"><Badge variant={b.variant} dot>{b.label}</Badge></Info>
        <Info label="Payé">{l.montant_paye > 0 ? fcfa(l.montant_paye) : 'Gratuit'}</Info>
        <Info label="Début">{dateFr(l.date_debut)}</Info>
        <Info label="Fin">{dateFr(l.date_fin)}</Info>
        <Info label="Durée">{l.duree_mois} mois</Info>
        <Info label="Téléphone (appareil)"><span className="font-mono text-xs">{l.device_id.slice(0, 16)}…</span></Info>
      </dl>
      {l.cle_hors_ligne && <CopyField label="Clé d’activation (à coller dans l’application)" value={l.cle_hors_ligne} />}
      <div className="flex flex-col-reverse gap-2 border-t border-gray-100 pt-4 sm:flex-row sm:justify-between">
        <Link href={`/clients?q=${encodeURIComponent(l.telephone_client)}`} className="inline-flex h-10 items-center justify-center gap-1.5 rounded-lg px-3 text-sm font-semibold text-primary hover:bg-primary-50">
          Voir le compte
          <Icon name="arrowRight" className="h-4 w-4" strokeWidth={2} />
        </Link>
        {(s === 'active' || s === 'essai' || s === 'suspendue') && (
          <Button variant={l.statut === 'suspendue' ? 'accent' : 'outline'} loading={busy} onClick={onToggle}>
            <Icon name={l.statut === 'suspendue' ? 'play' : 'pause'} className="h-4 w-4" strokeWidth={2} />
            {l.statut === 'suspendue' ? 'Réactiver' : 'Suspendre'}
          </Button>
        )}
      </div>
    </div>
  );
}

function Info({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="text-xs text-muted">{label}</dt>
      <dd className="mt-1 text-ink">{children}</dd>
    </div>
  );
}
