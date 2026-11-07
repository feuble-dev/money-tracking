import React from 'react';
import Icon, { type IconName } from '../Icon';
import { AppBar, fcfa } from './PhoneFrame';

/*
 * Écrans de l'application reproduits fidèlement (mêmes libellés, mêmes
 * cartes, chiffres cohérents entre eux) pour illustrer le site. Statiques :
 * aucun état, rendus côté serveur.
 */

function Card({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return <div className={`rounded-2xl bg-white p-3 shadow-sm ring-1 ring-black/[0.04] ${className}`}>{children}</div>;
}

function Row({ label, value, tone }: { label: string; value: string; tone?: 'in' | 'out' | 'muted' }) {
  const color = tone === 'in' ? 'text-accent' : tone === 'out' ? 'text-dark' : 'text-muted';
  return (
    <div className="flex items-baseline justify-between gap-2 py-1 text-[11px]">
      <span className="truncate text-muted">{label}</span>
      <span className={`whitespace-nowrap font-semibold tabular-nums ${color}`}>{value}</span>
    </div>
  );
}

/** « Mon argent » : tous les comptes d'un particulier. */
export function MoneyScreen() {
  const accounts: { name: string; kind: string; amount: number; icon: IconName; color: string }[] = [
    { name: 'Orange Money', kind: 'Mobile Money', amount: 184500, icon: 'phone', color: 'bg-orange-100 text-orange-700' },
    { name: 'Coris Bank', kind: 'Banque', amount: 250000, icon: 'building', color: 'bg-primary-50 text-primary' },
    { name: 'Espèces', kind: 'Dans mon sac', amount: 52000, icon: 'wallet', color: 'bg-accent-50 text-accent' },
    { name: 'Tontine du quartier', kind: 'Épargne', amount: 60000, icon: 'users', color: 'bg-clay-light text-clay' },
  ];
  const total = accounts.reduce((s, a) => s + a.amount, 0);
  return (
    <>
      <AppBar title="Mon argent">
        <p className="mt-3 text-[10px] text-white/70">Tout mon argent</p>
        <p className="font-display text-[22px] font-bold tabular-nums">{fcfa(total)}</p>
      </AppBar>
      <div className="flex-1 space-y-2 p-3">
        {accounts.map((a) => (
          <Card key={a.name} className="flex items-center gap-2.5 !p-2.5">
            <span className={`flex h-8 w-8 items-center justify-center rounded-lg ${a.color}`}>
              <Icon name={a.icon} className="h-4 w-4" strokeWidth={1.8} />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[11px] font-semibold text-dark">{a.name}</span>
              <span className="block text-[9px] text-muted">{a.kind}</span>
            </span>
            <span className="text-[11px] font-bold tabular-nums text-dark">{fcfa(a.amount)}</span>
          </Card>
        ))}
        <Card>
          <p className="text-[10px] font-semibold text-muted">Ce mois</p>
          <Row label="Revenus" value={`+ ${fcfa(185000)}`} tone="in" />
          <Row label="Dépenses" value={`− ${fcfa(100200)}`} tone="out" />
          <div className="mt-1 border-t border-gray-100 pt-1">
            <Row label="Épargné" value={fcfa(84800)} tone="in" />
          </div>
        </Card>
      </div>
    </>
  );
}

const motifs = [
  { label: 'Nourriture', spent: 38500, budget: 50000, color: '#2E7D32' },
  { label: 'Transport', spent: 13200, budget: 15000, color: '#1565C0' },
  { label: 'Famille', spent: 30000, budget: 25000, color: '#B4532A' },
  { label: 'Factures', spent: 12500, budget: 20000, color: '#7C3AED' },
  { label: 'Crédit téléphone', spent: 6000, budget: 8000, color: '#0891B2' },
];

/** Budget du mois : plafond par motif, alerte à 80 % et au dépassement. */
export function BudgetScreen() {
  return (
    <>
      <AppBar title="Budget · novembre">
        <p className="mt-3 text-[10px] text-white/70">Dépensé ce mois</p>
        <p className="font-display text-[20px] font-bold tabular-nums">{fcfa(100200)}</p>
        <p className="text-[10px] text-white/70">sur {fcfa(118000)} prévus</p>
      </AppBar>
      <div className="flex-1 space-y-2 p-3">
        {motifs.map((m) => {
          const ratio = m.spent / m.budget;
          const over = ratio > 1;
          const warn = !over && ratio >= 0.8;
          return (
            <Card key={m.label} className="!p-2.5">
              <div className="flex items-baseline justify-between text-[11px]">
                <span className="font-semibold text-dark">{m.label}</span>
                <span className="tabular-nums text-muted">
                  <span className={over ? 'font-bold text-red-600' : 'font-semibold text-dark'}>
                    {m.spent.toLocaleString('fr-FR')}
                  </span>{' '}
                  / {m.budget.toLocaleString('fr-FR')}
                </span>
              </div>
              <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-gray-100">
                <div
                  className="h-full rounded-full"
                  style={{ width: `${Math.min(100, ratio * 100)}%`, background: over ? '#DC2626' : warn ? '#D97706' : m.color }}
                />
              </div>
              {(over || warn) && (
                <p className={`mt-1 text-[9px] font-semibold ${over ? 'text-red-600' : 'text-amber-700'}`}>
                  {over ? `Dépassé de ${fcfa(m.spent - m.budget)}` : 'Bientôt atteint'}
                </p>
              )}
            </Card>
          );
        })}
      </div>
    </>
  );
}

/** Répartition des dépenses par motif (anneau). */
export function SpendingScreen() {
  const total = motifs.reduce((s, m) => s + m.spent, 0);
  let acc = 0;
  const stops = motifs
    .map((m) => {
      const from = (acc / total) * 100;
      acc += m.spent;
      return `${m.color} ${from}% ${(acc / total) * 100}%`;
    })
    .join(', ');
  return (
    <>
      <AppBar title="Accueil">
        <p className="mt-3 text-[10px] text-white/70">Dépenses de novembre</p>
        <p className="font-display text-[20px] font-bold tabular-nums">{fcfa(total)}</p>
        <p className="text-[10px] text-white/70">−8 % par rapport à octobre</p>
      </AppBar>
      <div className="flex-1 space-y-2 p-3">
        <Card className="flex items-center gap-3">
          <div className="relative h-20 w-20 flex-shrink-0 rounded-full" style={{ background: `conic-gradient(${stops})` }}>
            <div className="absolute inset-[22%] rounded-full bg-white" />
          </div>
          <ul className="min-w-0 flex-1 space-y-1">
            {motifs.slice(0, 4).map((m) => (
              <li key={m.label} className="flex items-center gap-1.5 text-[10px]">
                <span className="h-2 w-2 flex-shrink-0 rounded-sm" style={{ background: m.color }} />
                <span className="truncate text-muted">{m.label}</span>
                <span className="ml-auto font-semibold tabular-nums text-dark">{Math.round((m.spent / total) * 100)} %</span>
              </li>
            ))}
          </ul>
        </Card>
        <Card>
          <p className="mb-1 text-[10px] font-semibold text-muted">À qui je donne le plus</p>
          <Row label="Maman · 70 12 34 56" value={fcfa(25000)} />
          <Row label="SONABEL" value={fcfa(12500)} />
          <Row label="Boutique Kaboré" value={fcfa(9800)} />
        </Card>
        <Card className="flex items-center gap-2 !bg-primary-50 !ring-primary/10">
          <Icon name="tag" className="h-4 w-4 text-primary" strokeWidth={1.8} />
          <span className="text-[10px] font-semibold text-primary">2 dépenses à ranger</span>
        </Card>
      </div>
    </>
  );
}

const last14 = [2100, 3400, 2800, 0, 4100, 3900, 2600, 3300, 4800, 3100, 1500, 3600, 5200, 4350];

/** Commissions d'un agent : période, tendance, ce qui rapporte. */
export function CommissionsScreen() {
  const max = Math.max(...last14);
  return (
    <>
      <AppBar title="Commissions">
        <div className="mt-2.5 grid grid-cols-4 gap-0.5 rounded-full bg-white/10 p-0.5 text-center text-[8.5px]">
          {["Aujourd'hui", '7 jours', 'Ce mois', 'Tout'].map((p, i) => (
            <span key={p} className={`rounded-full py-1 ${i === 0 ? 'bg-white font-semibold text-primary' : 'text-white/80'}`}>
              {p}
            </span>
          ))}
        </div>
        <p className="mt-3 text-[10px] text-white/70">Gagné · aujourd&apos;hui</p>
        <p className="font-display text-[22px] font-bold tabular-nums">{fcfa(4350)}</p>
        <p className="text-[10px] text-white/70">31 opérations · ≈ 140 FCFA / opération</p>
      </AppBar>
      <div className="flex-1 space-y-2 p-3">
        <Card>
          <p className="mb-2 text-[10px] font-semibold text-muted">Ces 14 derniers jours</p>
          <div className="flex h-14 items-end gap-[3px]">
            {last14.map((v, i) => (
              <span
                key={i}
                className={`flex-1 rounded-sm ${i === last14.length - 1 ? 'bg-accent' : 'bg-primary/80'}`}
                style={{ height: `${Math.max(4, (v / max) * 100)}%`, opacity: v ? 1 : 0.25 }}
              />
            ))}
          </div>
        </Card>
        <Card>
          <p className="mb-1 text-[10px] font-semibold text-muted">Ce qui vous rapporte</p>
          {[
            ['Retrait', 2400, 100],
            ['Dépôt', 1350, 56],
            ['Paiement marchand', 600, 25],
          ].map(([label, v, w]) => (
            <div key={label as string} className="py-1">
              <div className="flex justify-between text-[11px]">
                <span className="font-semibold text-dark">{label}</span>
                <span className="font-bold tabular-nums text-dark">{fcfa(v as number)}</span>
              </div>
              <div className="mt-1 h-1 rounded-full bg-gray-100">
                <div className="h-full rounded-full bg-primary" style={{ width: `${w}%` }} />
              </div>
            </div>
          ))}
        </Card>
      </div>
    </>
  );
}

/** Clôture du jour : espèces attendues face aux espèces comptées. */
export function ClosingScreen() {
  return (
    <>
      <AppBar title="Clôture du jour" />
      <div className="flex-1 space-y-2.5 p-3">
        <Card>
          <Row label="Espèces au départ" value={fcfa(248000)} tone="muted" />
          <Row label="+ Dépôts reçus" value={`+ ${fcfa(225000)}`} tone="in" />
          <Row label="− Retraits payés" value={`− ${fcfa(65000)}`} tone="out" />
          <div className="mt-1 flex items-baseline justify-between border-t border-gray-100 pt-2">
            <span className="text-[11px] font-bold text-dark">Vous devriez avoir</span>
            <span className="text-[13px] font-extrabold tabular-nums text-dark">{fcfa(408000)}</span>
          </div>
        </Card>
        <div>
          <p className="mb-1 text-[10px] font-semibold text-dark">J&apos;ai compté</p>
          <div className="rounded-xl border border-gray-300 bg-white px-3 py-2 font-display text-[18px] font-bold tabular-nums text-dark">
            405 000
          </div>
        </div>
        <div className="flex items-center gap-2 rounded-xl bg-amber-50 px-3 py-2.5 text-amber-800 ring-1 ring-amber-200">
          <Icon name="alert" className="h-4 w-4" strokeWidth={2} />
          <span className="text-[11px] font-bold">Il manque 3 000 FCFA.</span>
        </div>
        <div className="rounded-full bg-primary py-2.5 text-center text-[11px] font-semibold text-white">Enregistrer la clôture</div>
        <p className="text-center text-[9px] text-muted">31 opérations · 4 350 FCFA de commissions</p>
      </div>
    </>
  );
}

/** Notification Android telle que l'app l'affiche. */
export function Notification({
  title,
  text,
  time = 'maintenant',
  icon = 'bell',
  className = '',
}: {
  title: string;
  text: string;
  time?: string;
  icon?: IconName;
  className?: string;
}) {
  return (
    <div className={`w-[290px] rounded-2xl bg-white/95 p-3 shadow-[0_18px_40px_-18px_rgba(11,37,69,0.5)] ring-1 ring-black/5 ${className}`}>
      <div className="flex items-center gap-2 text-[10px] text-muted">
        <span className="flex h-5 w-5 items-center justify-center rounded-md bg-primary text-white">
          <Icon name={icon} className="h-3 w-3" strokeWidth={2} />
        </span>
        <span className="font-semibold text-dark">MoneyTracking</span>
        <span>· {time}</span>
      </div>
      <p className="mt-1.5 text-[12px] font-semibold text-dark">{title}</p>
      <p className="text-[11px] leading-snug text-muted">{text}</p>
    </div>
  );
}
