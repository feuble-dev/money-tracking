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
import Field, { FormError, inputCls } from '@/components/admin/ui/Field';
import { useAdmin } from '@/components/admin/shell/AdminContext';
import { getDemandes, rejeterDemande, validerDemande } from '@/lib/api';
import { useAsync } from '@/lib/useAsync';
import { apiError, type Demande } from '@/lib/admin-types';
import { ago, dateFr, fcfa } from '@/lib/format';

type Filtre = Demande['statut'] | 'toutes';

const statut: Record<Demande['statut'], { label: string; variant: 'warning' | 'success' | 'danger' }> = {
  en_attente: { label: 'À traiter', variant: 'warning' },
  validee: { label: 'Validée', variant: 'success' },
  rejetee: { label: 'Rejetée', variant: 'danger' },
};

/**
 * Demandes de licence envoyées depuis l'application après un paiement
 * Mobile Money : l'admin vérifie la réception du montant, puis valide (la
 * licence est créée et l'app la récupère seule) ou rejette avec un motif.
 */
export default function DemandesPage() {
  const { toast, refreshCompteurs } = useAdmin();
  const { data, setData, loading, error, reload } = useAsync(getDemandes);
  const [filtre, setFiltre] = useState<Filtre>('en_attente');
  const [open, setOpen] = useState<Demande | null>(null);

  const all = data ?? [];
  const rows = useMemo(() => (filtre === 'toutes' ? all : all.filter((d) => d.statut === filtre)), [all, filtre]);
  const nb = (s: Filtre) => (s === 'toutes' ? all.length : all.filter((d) => d.statut === s).length);

  const update = (d: Demande) => {
    setData((list) => (list ?? []).map((x) => (x.id === d.id ? d : x)));
    refreshCompteurs();
  };

  const columns: Column<Demande>[] = [
    {
      key: 'compte',
      header: 'Demandeur',
      sortValue: (d) => d.telephone,
      render: (d) => (
        <div className="min-w-0">
          <p className="font-medium tabular-nums text-ink">{d.telephone}</p>
          <p className="truncate text-xs text-muted">{d.agence_nom ?? 'Agence inconnue'}</p>
        </div>
      ),
    },
    {
      key: 'offre',
      header: 'Offre',
      sortValue: (d) => d.montant,
      render: (d) => (
        <div>
          <p className="font-semibold tabular-nums text-ink">{fcfa(d.montant)}</p>
          <p className="text-xs text-muted">{d.duree_mois} mois</p>
        </div>
      ),
    },
    {
      key: 'statut',
      header: 'Statut',
      sortValue: (d) => d.statut,
      render: (d) => <Badge variant={statut[d.statut].variant} dot>{statut[d.statut].label}</Badge>,
    },
    {
      key: 'date',
      header: 'Reçue',
      sortValue: (d) => d.created_at,
      hideOnMobile: true,
      render: (d) => <span title={dateFr(d.created_at, true)} className="text-muted">{ago(d.created_at)}</span>,
    },
    {
      key: 'action',
      header: '',
      className: 'text-right',
      render: (d) =>
        d.statut === 'en_attente' ? (
          <Button size="sm" variant="accent" onClick={(e) => { e.stopPropagation(); setOpen(d); }}>
            Traiter
          </Button>
        ) : null,
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Demandes d’activation"
        description="Vérifiez la réception du paiement Mobile Money avant de valider : la licence arrive alors seule dans l’application."
      />
      <Segmented
        value={filtre}
        onChange={setFiltre}
        options={[
          { value: 'en_attente', label: `À traiter · ${nb('en_attente')}` },
          { value: 'validee', label: `Validées · ${nb('validee')}` },
          { value: 'rejetee', label: `Rejetées · ${nb('rejetee')}` },
          { value: 'toutes', label: `Toutes · ${nb('toutes')}` },
        ]}
      />
      <DataTable
        rows={rows}
        columns={columns}
        rowKey={(d) => d.id}
        loading={loading}
        error={error}
        searchText={(d) => `${d.telephone} ${d.agence_nom ?? ''} ${d.note}`}
        searchPlaceholder="Numéro, agence, note…"
        initialSort={{ key: 'date', dir: 'desc' }}
        emptyTitle={filtre === 'en_attente' ? 'Tout est traité' : 'Aucune demande'}
        emptyText={filtre === 'en_attente' ? 'Aucune demande n’attend de validation.' : undefined}
        onRowClick={setOpen}
        toolbar={
          <Button variant="ghost" size="sm" onClick={reload}>
            <Icon name="sync" className="h-3.5 w-3.5" strokeWidth={2} />
            Actualiser
          </Button>
        }
      />
      <DemandeModal
        demande={open}
        onClose={() => setOpen(null)}
        onDone={(d, message) => {
          update(d);
          toast(message);
        }}
      />
    </div>
  );
}

function DemandeModal({
  demande: d,
  onClose,
  onDone,
}: {
  demande: Demande | null;
  onClose: () => void;
  onDone: (d: Demande, message: string) => void;
}) {
  const [mode, setMode] = useState<'view' | 'reject'>('view');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [cle, setCle] = useState<string | null>(null);

  const close = () => {
    setMode('view');
    setNote('');
    setError('');
    setCle(null);
    onClose();
  };

  if (!d) return null;

  const valider = async () => {
    setBusy(true);
    setError('');
    try {
      const r = await validerDemande(d.id, note.trim());
      setCle(r.cle_hors_ligne);
      onDone({ ...d, statut: 'validee', note: note.trim() || d.note }, 'Licence activée');
    } catch (e) {
      setError(apiError(e, 'La validation a échoué'));
    } finally {
      setBusy(false);
    }
  };

  const rejeter = async () => {
    if (!note.trim()) return setError('Indiquez le motif du rejet.');
    setBusy(true);
    setError('');
    try {
      await rejeterDemande(d.id, note.trim());
      onDone({ ...d, statut: 'rejetee', note: note.trim() }, 'Demande rejetée');
      close();
    } catch (e) {
      setError(apiError(e, 'Le rejet a échoué'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal isOpen onClose={close} title={cle ? 'Licence activée' : `Demande de ${d.telephone}`} description={cle ? undefined : d.agence_nom ?? undefined}>
      {cle ? (
        <div className="space-y-5">
          <p className="text-sm text-muted">
            L’application récupère la licence automatiquement à sa prochaine connexion. Si l’agent n’a pas Internet,
            envoyez-lui cette clé.
          </p>
          <CopyField label="Clé d’activation" value={cle} />
          <Button onClick={close} className="w-full">Terminé</Button>
        </div>
      ) : (
        <div className="space-y-5">
          <div className="rounded-xl bg-soft p-4">
            <p className="text-xs text-muted">Montant attendu</p>
            <p className="mt-0.5 font-display text-2xl font-bold tabular-nums text-ink">{fcfa(d.montant)}</p>
            <p className="mt-1 text-sm text-muted">
              {d.duree_mois} mois · demandé {ago(d.created_at)} depuis le {d.telephone}
            </p>
          </div>
          {d.statut !== 'en_attente' ? (
            <>
              <Badge variant={statut[d.statut].variant} dot>{statut[d.statut].label}</Badge>
              {d.note && <p className="text-sm text-gray-600">Note : {d.note}</p>}
            </>
          ) : (
            <>
              <FormError>{error}</FormError>
              <Field
                label={mode === 'reject' ? 'Motif du rejet' : 'Référence du paiement (facultatif)'}
                hint={mode === 'reject' ? 'Ex. : paiement non reçu. Gardé dans l’historique de la demande.' : 'L’identifiant de la transaction Mobile Money reçue.'}
              >
                <input
                  autoFocus
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  className={inputCls}
                  placeholder={mode === 'reject' ? 'Motif…' : 'Ex. : CI240529.1234.A56789'}
                />
              </Field>
              <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-between">
                {mode === 'view' ? (
                  <>
                    <Button variant="ghost" onClick={() => { setMode('reject'); setError(''); }} className="text-red-600 hover:bg-red-50">
                      Rejeter…
                    </Button>
                    <Button variant="accent" loading={busy} onClick={valider}>
                      <Icon name="check" className="h-4 w-4" strokeWidth={2} />
                      Paiement reçu, activer
                    </Button>
                  </>
                ) : (
                  <>
                    <Button variant="ghost" onClick={() => { setMode('view'); setError(''); }}>Retour</Button>
                    <Button variant="danger" loading={busy} onClick={rejeter}>Rejeter la demande</Button>
                  </>
                )}
              </div>
            </>
          )}
        </div>
      )}
    </Modal>
  );
}
