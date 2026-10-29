'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import Icon from '@/components/site/Icon';
import Badge from '@/components/ui/Badge';
import Button from '@/components/ui/Button';
import Card from '@/components/admin/ui/Card';
import EmptyState from '@/components/admin/ui/EmptyState';
import ConfirmModal from '@/components/admin/ConfirmModal';
import GenerateLicenceModal from '@/components/admin/GenerateLicenceModal';
import { useAdmin } from '@/components/admin/shell/AdminContext';
import { getClient, revokeDevice } from '@/lib/api';
import { useAsync } from '@/lib/useAsync';
import type { ClientDetail } from '@/lib/admin-types';
import { statutBadge } from '@/lib/licence-status';
import { ago, compact, dateFr, fcfa, num } from '@/lib/format';

type Appareil = ClientDetail['appareils'][number];

export default function ClientDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { toast } = useAdmin();
  const { data: c, setData, loading, error, reload } = useAsync(() => getClient(Number(id)), [id]);
  const [revoking, setRevoking] = useState<Appareil | null>(null);
  const [licenceFor, setLicenceFor] = useState<number | null>(null);

  if (error) {
    return (
      <Card>
        <EmptyState title="Compte introuvable" text={error} action={<Button href="/clients" variant="outline">Retour aux clients</Button>} />
      </Card>
    );
  }
  if (loading && !c) {
    return (
      <div className="space-y-4">
        <div className="h-28 animate-pulse rounded-2xl border border-gray-200/80 bg-white" />
        <div className="h-64 animate-pulse rounded-2xl border border-gray-200/80 bg-white" />
      </div>
    );
  }
  if (!c) return null;

  const isAgence = c.account_type === 'agence';
  const nom = `${c.prenom} ${c.nom}`.trim();
  const totalPaye = c.paiements.reduce((s, p) => s + p.montant, 0);
  const totalOps = c.agences.reduce((s, a) => s + a.transactions_synchronisees, 0);
  const totalVolume = c.agences.reduce((s, a) => s + a.volume_synchronise, 0);

  return (
    <div className="space-y-6">
      <Link href="/clients" className="inline-flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-ink">
        <Icon name="arrowRight" className="h-4 w-4 rotate-180" strokeWidth={2} />
        Clients
      </Link>

      <section className="flex flex-col gap-5 rounded-2xl border border-gray-200/80 bg-white p-5 sm:flex-row sm:items-center sm:p-6">
        <span
          className={`flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-2xl ${
            isAgence ? 'bg-accent-50 text-accent' : 'bg-primary-50 text-primary'
          }`}
        >
          <Icon name={isAgence ? 'building' : 'users'} className="h-7 w-7" strokeWidth={1.6} />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="font-display text-2xl font-bold tabular-nums text-ink">{c.telephone}</h1>
            {isAgence ? <Badge variant="success">Agence</Badge> : <Badge variant="info">Particulier · gratuit</Badge>}
          </div>
          <p className="mt-1 text-sm text-muted">
            {nom || 'Sans nom'} · inscrit le {dateFr(c.created_at)} ·{' '}
            {c.a_mot_de_passe ? 'mot de passe défini' : 'sans mot de passe (compte ancien)'}
          </p>
        </div>
      </section>

      <div className="grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-gray-200/80 bg-gray-200/80 lg:grid-cols-4">
        <Stat label={isAgence ? 'Agences' : 'Espace de suivi'} value={num(c.agences.length)} />
        <Stat label="Téléphones autorisés" value={num(c.appareils.length)} />
        <Stat label="Opérations synchronisées" value={num(totalOps)} hint={totalVolume ? `${compact(totalVolume)} FCFA` : undefined} />
        <Stat label="Total payé" value={isAgence ? fcfa(totalPaye) : "Gratuit"} />
      </div>

      {isAgence && (
        <Card title="Agences" subtitle="Chaque agence a sa propre licence" padded={false}>
          {c.agences.length === 0 ? (
            <p className="px-5 pb-6 pt-3 text-sm text-muted">Aucune agence.</p>
          ) : (
            <ul className="divide-y divide-gray-100">
              {c.agences.map((a) => {
                const b = a.licence ? statutBadge[a.licence.statut] : null;
                return (
                  <li key={a.id} className="flex flex-col gap-3 px-5 py-4 sm:flex-row sm:items-center">
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="font-medium text-ink">{a.nom}</p>
                        {b && <Badge variant={b.variant} dot>{b.label}</Badge>}
                        {!a.is_active && <Badge>Désactivée</Badge>}
                      </div>
                      <p className="mt-1 text-xs text-muted">
                        {a.licence
                          ? a.licence.jours >= 0
                            ? `Jusqu’au ${dateFr(a.licence.date_fin)} (${a.licence.jours} j)`
                            : `Expirée depuis le ${dateFr(a.licence.date_fin)}`
                          : 'Aucune licence'}
                        {' · '}
                        {a.appareils_licencies} téléphone(s) · {num(a.transactions_synchronisees)} opérations synchronisées
                      </p>
                    </div>
                    <Button variant="subtle" size="sm" onClick={() => setLicenceFor(a.id)}>
                      <Icon name="key" className="h-3.5 w-3.5" strokeWidth={2} />
                      Prolonger
                    </Button>
                  </li>
                );
              })}
            </ul>
          )}
        </Card>
      )}

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <Card title="Téléphones autorisés" subtitle="Révoquez un téléphone perdu ou volé : il devra se reconnecter avec le mot de passe." padded={false}>
          {c.appareils.length === 0 ? (
            <p className="px-5 pb-6 pt-3 text-sm text-muted">Aucun téléphone enregistré (application pas encore mise à jour).</p>
          ) : (
            <ul className="divide-y divide-gray-100">
              {c.appareils.map((d) => (
                <li key={d.id} className="flex items-center gap-3 px-5 py-3">
                  <Icon name="phone" className="h-5 w-5 flex-shrink-0 text-gray-400" strokeWidth={1.6} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-mono text-xs text-ink">{d.device}</p>
                    <p className="text-xs text-muted">
                      {d.origine} · {d.last_used_at ? `vu ${ago(d.last_used_at)}` : 'jamais utilisé'}
                    </p>
                  </div>
                  <Button variant="ghost" size="sm" onClick={() => setRevoking(d)} className="text-red-600 hover:bg-red-50 hover:text-red-700">
                    Révoquer
                  </Button>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card title="Paiements" subtitle="Licences payées" padded={false}>
          {c.paiements.length === 0 ? (
            <p className="px-5 pb-6 pt-3 text-sm text-muted">{isAgence ? 'Aucun paiement pour le moment.' : 'Compte gratuit.'}</p>
          ) : (
            <ul className="divide-y divide-gray-100">
              {c.paiements.map((p) => (
                <li key={p.id} className="flex items-center gap-3 px-5 py-3 text-sm">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-ink">{p.agence} · {p.duree_mois} mois</p>
                    <p className="text-xs text-muted">{dateFr(p.date)}</p>
                  </div>
                  <span className="font-semibold tabular-nums text-ink">{fcfa(p.montant)}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <ConfirmModal
        isOpen={!!revoking}
        onClose={() => setRevoking(null)}
        title="Révoquer ce téléphone ?"
        confirmLabel="Révoquer"
        message={
          <>
            Le téléphone <span className="font-mono">{revoking?.device}</span> ne pourra plus utiliser ce compte. Si c’est
            bien son propriétaire, il lui suffira de se reconnecter avec son numéro et son mot de passe.
          </>
        }
        onConfirm={async () => {
          const target = revoking!;
          await revokeDevice(target.id);
          setData((d) => (d ? { ...d, appareils: d.appareils.filter((x) => x.id !== target.id) } : d));
          toast('Téléphone révoqué');
        }}
      />

      <GenerateLicenceModal
        isOpen={licenceFor !== null}
        agenceId={licenceFor ?? undefined}
        onClose={() => setLicenceFor(null)}
        onGenerated={reload}
      />
    </div>
  );
}

function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="bg-white p-4 sm:p-5">
      <p className="text-xs font-medium text-muted">{label}</p>
      <p className="mt-1.5 font-display text-xl font-bold tabular-nums text-ink">{value}</p>
      {hint && <p className="mt-0.5 text-xs text-muted">{hint}</p>}
    </div>
  );
}
