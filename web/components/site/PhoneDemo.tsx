'use client';

import React, { useEffect, useRef, useState } from 'react';
import Icon from './Icon';

export type DemoMode = 'particulier' | 'agence';

interface DemoEvent {
  sender: string;
  sms: string;
  title: string;
  subtitle: string;
  amount: number; // signé
}

// Scénarios réalistes (montants FCFA, opérateurs du Burkina Faso).
const scripts: Record<
  DemoMode,
  {
    header: string;
    label: string;
    start: number;
    events: DemoEvent[];
    // Carte du bas : budget du mois (particulier) ou commissions (agence).
    footer: { label: string; base: number; perEvent: number[]; max: number };
  }
> = {
  particulier: {
    header: 'Mon argent',
    label: 'Tout mon argent',
    start: 214500,
    events: [
      { sender: 'OrangeMoney', sms: 'Vous avez reçu 75 000 FCFA de 70 12 34 56…', title: 'Salaire', subtitle: 'Orange Money · Revenu', amount: 75000 },
      { sender: 'MOOV', sms: 'Paiement de 12 500 FCFA à SONABEL effectué…', title: 'Facture SONABEL', subtitle: 'Moov Money · Factures', amount: -12500 },
      { sender: 'OrangeMoney', sms: 'Transfert de 10 000 FCFA vers 76 54 32 10…', title: 'Envoi à Maman', subtitle: 'Orange Money · Famille', amount: -10000 },
      { sender: 'Wave', sms: 'Achat de crédit de 1 000 FCFA réussi…', title: 'Crédit téléphone', subtitle: 'Wave · Crédit', amount: -1000 },
    ],
    footer: { label: 'Budget du mois', base: 61000, perEvent: [0, 12500, 10000, 1000], max: 100000 },
  },
  agence: {
    header: 'Agence Tampouy',
    label: 'Float total',
    start: 1_850_000,
    events: [
      { sender: 'OrangeMoney', sms: 'Dépôt de 50 000 FCFA sur 70 12 34 56. Commission 250…', title: 'Dépôt · 70 12 34 56', subtitle: 'Orange Money · +250 de commission', amount: -50000 },
      { sender: 'MOOV', sms: 'Retrait de 25 000 FCFA par 65 98 76 54…', title: 'Retrait · 65 98 76 54', subtitle: 'Moov Money · +175 de commission', amount: 25000 },
      { sender: 'CorisMoney', sms: 'Dépôt de 100 000 FCFA sur 76 54 32 10…', title: 'Dépôt · 76 54 32 10', subtitle: 'Coris Money · +400 de commission', amount: -100000 },
    ],
    footer: { label: 'Commissions du jour', base: 3150, perEvent: [250, 175, 400], max: 5000 },
  },
};

const fcfa = (n: number) => `${Math.abs(n).toLocaleString('fr-FR')} FCFA`;

/**
 * Téléphone de démonstration : un SMS d'opérateur arrive, puis devient une
 * ligne dans l'application et le solde se met à jour — la promesse du
 * produit montrée plutôt que décrite. En boucle ; statique si l'utilisateur
 * réduit les animations.
 */
export default function PhoneDemo({ mode }: { mode: DemoMode }) {
  const script = scripts[mode];
  const [rows, setRows] = useState<(DemoEvent & { key: number })[]>([]);
  const [toast, setToast] = useState<(DemoEvent & { key: number }) | null>(null);
  const [balance, setBalance] = useState(script.start);
  const [footer, setFooter] = useState(script.footer.base);
  const counter = useRef(0);

  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    setToast(null);
    if (reduce) {
      setRows(script.events.map((e, i) => ({ ...e, key: i })).reverse());
      setBalance(script.start + script.events.reduce((s, e) => s + e.amount, 0));
      setFooter(script.footer.base + script.footer.perEvent.reduce((a, b) => a + b, 0));
      return;
    }
    setRows([]);
    setBalance(script.start);
    setFooter(script.footer.base);
    let i = 0;
    const timers: ReturnType<typeof setTimeout>[] = [];
    const play = () => {
      if (i >= script.events.length) {
        // Courte pause puis on recommence le scénario.
        timers.push(setTimeout(() => {
          i = 0;
          setRows([]);
          setBalance(script.start);
          setFooter(script.footer.base);
          play();
        }, 2600));
        return;
      }
      const ev = { ...script.events[i], key: ++counter.current };
      const bump = script.footer.perEvent[i] ?? 0;
      i += 1;
      setToast(ev);
      timers.push(setTimeout(() => {
        setRows((r) => [ev, ...r].slice(0, 4));
        setBalance((b) => b + ev.amount);
        setFooter((f) => f + bump);
      }, 1100));
      timers.push(setTimeout(play, 3000));
    };
    timers.push(setTimeout(play, 700));
    return () => timers.forEach(clearTimeout);
  }, [mode, script]);

  return (
    <div className="relative mx-auto w-[290px]" aria-hidden="true">
      <div className="rounded-[2.6rem] bg-[#0E1621] p-3 shadow-[0_30px_80px_-20px_rgba(11,37,69,0.55)] ring-1 ring-black/10">
        <div className="relative flex h-[560px] flex-col overflow-hidden rounded-[2rem] bg-[#F5F7FA]">
          {/* Barre d'état */}
          <div className="flex items-center justify-between bg-primary px-5 pb-2 pt-3 text-[10px] font-medium text-white/80">
            <span>09:41</span>
            <span className="h-4 w-20 rounded-full bg-black/40" />
            <span>4G</span>
          </div>

          {/* Notification SMS */}
          {toast && (
            <div key={toast.key} className="sms-toast-enter absolute inset-x-3 top-9 z-20 rounded-2xl bg-white p-3 shadow-lg ring-1 ring-black/5">
              <div className="flex items-center gap-2 text-[10px] text-muted">
                <span className="flex h-5 w-5 items-center justify-center rounded-md bg-accent text-white">
                  <Icon name="sms" className="h-3 w-3" strokeWidth={2} />
                </span>
                <span className="font-semibold text-dark">{toast.sender}</span>
                <span>· maintenant</span>
              </div>
              <p className="mt-1.5 text-[11px] leading-snug text-dark">{toast.sms}</p>
            </div>
          )}

          {/* En-tête de l'app */}
          <div className="bg-primary px-5 pb-6 pt-3 text-white">
            <p className="font-display text-base font-semibold">{script.header}</p>
            <div className="mt-4 rounded-2xl bg-white/10 p-4">
              <p className="text-[11px] text-white/70">{script.label}</p>
              <p className="mt-1 font-display text-2xl font-bold tabular-nums transition-all duration-500">
                {fcfa(balance)}
              </p>
            </div>
          </div>

          {/* Fil des opérations */}
          <div className="flex-1 px-4 pt-4">
            <p className="mb-2 text-[11px] font-semibold text-muted">Aujourd&apos;hui</p>
            <ul className="space-y-2">
              {rows.map((r) => (
                <li key={r.key} className="row-enter flex items-center gap-3 rounded-xl bg-white p-2.5 shadow-sm ring-1 ring-black/[0.04]">
                  <span className={`flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-lg ${r.amount >= 0 ? 'bg-accent-50 text-accent' : 'bg-primary-50 text-primary'}`}>
                    <Icon name={r.amount >= 0 ? 'arrowDown' : 'arrowUp'} className="h-4 w-4" strokeWidth={2} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[12px] font-semibold text-dark">{r.title}</span>
                    <span className="block truncate text-[10px] text-muted">{r.subtitle}</span>
                  </span>
                  <span className={`text-[12px] font-bold tabular-nums ${r.amount >= 0 ? 'text-accent' : 'text-dark'}`}>
                    {r.amount >= 0 ? '+' : '−'}{Math.abs(r.amount).toLocaleString('fr-FR')}
                  </span>
                </li>
              ))}
              {rows.length === 0 && (
                <li className="rounded-xl border border-dashed border-gray-300 p-4 text-center text-[11px] text-muted">
                  En attente d&apos;un SMS…
                </li>
              )}
            </ul>
          </div>

          <div className="m-4 rounded-2xl bg-white p-4 shadow-sm ring-1 ring-black/[0.04]">
            <div className="flex items-baseline justify-between">
              <span className="text-[11px] font-semibold text-muted">{script.footer.label}</span>
              <span className="text-[12px] font-bold tabular-nums text-ink">
                {footer.toLocaleString('fr-FR')}
                {mode === 'particulier' && (
                  <span className="font-medium text-muted"> / {script.footer.max.toLocaleString('fr-FR')}</span>
                )}
              </span>
            </div>
            <div className="mt-2.5 h-2 overflow-hidden rounded-full bg-gray-100">
              <div
                className={`h-full rounded-full transition-[width] duration-700 ease-out ${
                  mode === 'particulier' && footer / script.footer.max > 0.8 ? 'bg-amber-500' : 'bg-accent'
                }`}
                style={{ width: `${Math.min(100, (footer / script.footer.max) * 100)}%` }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
