'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import Icon, { type IconName } from '@/components/site/Icon';
import Button from '@/components/ui/Button';
import Badge from '@/components/ui/Badge';
import Card from '@/components/admin/ui/Card';
import KpiTile from '@/components/admin/ui/KpiTile';
import PageHeader from '@/components/admin/ui/PageHeader';
import Segmented from '@/components/admin/ui/Segmented';
import EmptyState from '@/components/admin/ui/EmptyState';
import AreaChart from '@/components/admin/charts/AreaChart';
import BarChart from '@/components/admin/charts/BarChart';
import Donut from '@/components/admin/charts/Donut';
import { getAnalytics } from '@/lib/api';
import { useAsync } from '@/lib/useAsync';
import { ago, compact, fcfa, num } from '@/lib/format';
import type { Analytics } from '@/lib/admin-types';

const BLUE = '#1565C0';
const GREEN = '#2E7D32';

const periods = [
  { value: 7, label: '7 j' },
  { value: 30, label: '30 j' },
  { value: 90, label: '90 j' },
  { value: 365, label: '12 mois' },
];

export default function DashboardPage() {
  const [jours, setJours] = useState(30);
  const { data, loading, error, reload } = useAsync(() => getAnalytics(jours), [jours]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Vue d’ensemble"
        description={data ? `Sur les ${periodLabel(jours)}, comparé à la période précédente.` : 'Chargement des indicateurs…'}
        actions={
          <>
            <Segmented value={jours} options={periods} onChange={setJours} />
            <Button variant="outline" size="md" onClick={reload} loading={loading} aria-label="Actualiser">
              <Icon name="sync" className="h-4 w-4" strokeWidth={2} />
            </Button>
          </>
        }
      />

      {error && !data ? (
        <Card>
          <EmptyState title="Impossible de charger le tableau de bord" text={error} action={<Button onClick={reload}>Réessayer</Button>} />
        </Card>
      ) : !data ? (
        <Skeleton />
      ) : (
        <Content data={data} />
      )}
    </div>
  );
}

function periodLabel(j: number) {
  return j === 365 ? '12 derniers mois' : `${j} derniers jours`;
}

function Content({ data }: { data: Analytics }) {
  const { kpis, series, licences } = data;
  const inscriptions = series.inscriptions_particulier.map((p, i) => p.value + (series.inscriptions_agence[i]?.value ?? 0));
  const licenceTotal = licences.payantes + licences.essai + licences.suspendues + licences.expirees;

  return (
    <>
      <TodoStrip data={data} />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <KpiTile
          label="Revenus encaissés"
          value={fcfa(kpis.revenus.value)}
          delta={kpis.revenus.delta}
          hint="vs période préc."
          trend={series.revenus.map((p) => p.value)}
          color={GREEN}
        />
        <KpiTile
          label="Revenu mensuel récurrent"
          value={fcfa(kpis.mrr)}
          hint="licences payantes en cours, ramenées au mois"
        />
        <KpiTile
          label="Nouveaux comptes"
          value={num(kpis.nouveaux_comptes.value)}
          delta={kpis.nouveaux_comptes.delta}
          hint="vs période préc."
          trend={inscriptions}
          href="/clients"
        />
        <KpiTile
          label="Volume synchronisé"
          value={`${compact(kpis.volume_synchronise.value)} FCFA`}
          delta={kpis.volume_synchronise.delta}
          hint={`${num(kpis.transactions_synchronisees)} opérations`}
          trend={series.volume.map((p) => p.value)}
        />
      </div>

      <div className="grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-gray-200/80 bg-gray-200/80 lg:grid-cols-4">
        <MiniStat label="Comptes au total" value={num(kpis.comptes_total)} hint={`${num(kpis.particuliers)} particuliers · ${num(kpis.agences_comptes)} agences`} />
        <MiniStat label="Agences actives" value={num(kpis.agences_actives)} hint="hors comptes particuliers" />
        <MiniStat label="Téléphones actifs" value={num(kpis.appareils_actifs_30j)} hint="ont appelé l’API sur 30 jours" />
        <MiniStat
          label="Conversion après essai"
          value={kpis.conversion_essai === null ? '—' : `${kpis.conversion_essai} %`}
          hint="agences de plus de 3 mois ayant payé"
        />
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <Card title="Revenus" subtitle="Licences payées, par jour (par semaine sur 12 mois)" className="xl:col-span-2">
          <AreaChart data={series.revenus} color={GREEN} format={fcfa} />
        </Card>
        <Card title="Licences d’agence" subtitle="État actuel, une agence comptée une fois">
          <div className="pt-2">
            <Donut
              slices={[
                { label: 'Payantes', value: licences.payantes, color: GREEN },
                { label: 'En essai', value: licences.essai, color: BLUE },
                { label: 'Suspendues', value: licences.suspendues, color: '#D97706' },
                { label: 'Expirées', value: licences.expirees, color: '#64748B' },
              ]}
              center={
                <>
                  <span className="font-display text-2xl font-bold text-ink">{num(licenceTotal)}</span>
                  <span className="text-[11px] text-muted">agences</span>
                </>
              }
            />
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <Card
          title="Inscriptions"
          subtitle="Nouveaux comptes par type"
          action={
            <div className="flex gap-3 text-xs text-muted">
              <Legend color={BLUE} label="Particulier" />
              <Legend color={GREEN} label="Agence" />
            </div>
          }
        >
          <BarChart
            dates={series.inscriptions_particulier.map((p) => p.date)}
            series={[
              { label: 'Particulier', color: BLUE, values: series.inscriptions_particulier.map((p) => p.value) },
              { label: 'Agence', color: GREEN, values: series.inscriptions_agence.map((p) => p.value) },
            ]}
          />
        </Card>
        <Card title="Volume Mobile Money" subtitle="Opérations synchronisées par les agences">
          <AreaChart data={series.volume} color={BLUE} format={fcfa} />
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <Card title="Expirent dans les 14 jours" subtitle="À relancer avant la coupure" padded={false}>
          {data.expirent_bientot.length === 0 ? (
            <p className="px-5 pb-6 pt-3 text-sm text-muted">Aucune licence n’expire bientôt.</p>
          ) : (
            <ul className="divide-y divide-gray-100">
              {data.expirent_bientot.map((l) => (
                <li key={l.id}>
                  <Link href={`/licences?q=${encodeURIComponent(l.telephone)}`} className="flex items-center gap-3 px-5 py-3 transition-colors hover:bg-soft/70">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-ink">{l.agence}</p>
                      <p className="text-xs text-muted">{l.telephone} · {l.statut === 'essai' ? 'essai' : 'payante'}</p>
                    </div>
                    <Badge variant={l.jours <= 3 ? 'danger' : 'warning'}>
                      {l.jours === 0 ? 'aujourd’hui' : `${l.jours} j`}
                    </Badge>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <RankCard
          title="Agences les plus actives"
          subtitle="Volume synchronisé sur la période"
          rows={data.top_agences.map((a) => ({ key: a.id, label: a.nom, hint: `${num(a.transactions)} op.`, value: a.volume }))}
          empty="Aucune opération synchronisée sur la période."
        />
        <RankCard
          title="Opérateurs"
          subtitle="Volume synchronisé par opérateur"
          rows={data.operateurs.map((o) => ({ key: o.nom, label: o.nom, hint: `${num(o.transactions)} op.`, value: o.volume }))}
          empty="Aucune opération synchronisée sur la période."
        />
      </div>

      <Card title="Activité récente" padded={false}>
        {data.activite.length === 0 ? (
          <p className="px-5 pb-6 pt-3 text-sm text-muted">Rien pour le moment.</p>
        ) : (
          <ul className="divide-y divide-gray-100">
            {data.activite.map((e, i) => (
              <li key={i} className="flex items-center gap-3 px-5 py-3">
                <span className={`flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-lg ${activityStyle[e.type].cls}`}>
                  <Icon name={activityStyle[e.type].icon} className="h-4 w-4" strokeWidth={1.8} />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm text-ink">{e.texte}</p>
                  <p className="truncate text-xs text-muted">{e.detail}</p>
                </div>
                <span className="flex-shrink-0 text-xs text-muted">{ago(e.date)}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </>
  );
}

const activityStyle: Record<Analytics['activite'][number]['type'], { icon: IconName; cls: string }> = {
  compte: { icon: 'users', cls: 'bg-primary-50 text-primary' },
  paiement: { icon: 'coins', cls: 'bg-accent-50 text-accent' },
  demande: { icon: 'inbox', cls: 'bg-amber-50 text-amber-700' },
};

/** Ce qui attend une action de l'admin, en tête de page. */
function TodoStrip({ data }: { data: Analytics }) {
  const items = [
    { n: data.kpis.demandes_en_attente, label: 'demande(s) d’activation à valider', href: '/demandes', icon: 'inbox' as IconName },
    { n: data.kpis.achats_en_attente, label: 'achat(s) d’import SMS à valider', href: '/achats-historique', icon: 'history' as IconName },
    { n: data.expirent_bientot.length, label: 'licence(s) expirent sous 14 jours', href: '/licences', icon: 'clock' as IconName },
  ].filter((i) => i.n > 0);
  if (items.length === 0) return null;
  return (
    <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
      {items.map((i) => (
        <Link
          key={i.href}
          href={i.href}
          className="group flex items-center gap-3 rounded-2xl border border-amber-200 bg-amber-50/70 px-4 py-3 transition-colors hover:border-amber-300"
        >
          <Icon name={i.icon} className="h-5 w-5 text-amber-700" strokeWidth={1.8} />
          <p className="text-sm text-amber-900">
            <span className="font-semibold">{i.n}</span> {i.label}
          </p>
          <Icon name="arrowRight" className="ml-auto h-4 w-4 text-amber-700 transition-transform group-hover:translate-x-0.5" strokeWidth={2} />
        </Link>
      ))}
    </div>
  );
}

function MiniStat({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="bg-white p-4 sm:p-5">
      <p className="text-xs font-medium text-muted">{label}</p>
      <p className="mt-1.5 font-display text-xl font-bold tabular-nums text-ink">{value}</p>
      <p className="mt-1 truncate text-xs text-muted">{hint}</p>
    </div>
  );
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <span className="flex items-center gap-1.5">
      <span className="h-2.5 w-2.5 rounded-sm" style={{ background: color }} />
      {label}
    </span>
  );
}

/** Classement avec barre proportionnelle (top agences, opérateurs). */
function RankCard({
  title,
  subtitle,
  rows,
  empty,
}: {
  title: string;
  subtitle: string;
  rows: { key: string | number; label: string; hint: string; value: number }[];
  empty: string;
}) {
  const max = Math.max(...rows.map((r) => r.value), 1);
  return (
    <Card title={title} subtitle={subtitle}>
      {rows.length === 0 ? (
        <p className="text-sm text-muted">{empty}</p>
      ) : (
        <ul className="space-y-3.5">
          {rows.map((r) => (
            <li key={r.key}>
              <div className="flex items-baseline justify-between gap-3 text-sm">
                <span className="truncate font-medium text-ink">{r.label}</span>
                <span className="flex-shrink-0 tabular-nums text-ink">
                  {compact(r.value)} <span className="text-xs text-muted">FCFA · {r.hint}</span>
                </span>
              </div>
              <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-gray-100">
                <div className="h-full rounded-full bg-primary transition-[width] duration-700" style={{ width: `${(r.value / max) * 100}%` }} />
              </div>
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

function Skeleton() {
  const block = 'animate-pulse rounded-2xl border border-gray-200/80 bg-white';
  return (
    <>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className={`${block} h-[118px]`} />
        ))}
      </div>
      <div className={`${block} h-[92px]`} />
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <div className={`${block} h-[300px] xl:col-span-2`} />
        <div className={`${block} h-[300px]`} />
      </div>
    </>
  );
}
