import React from 'react';
import Icon from './Icon';
import Reveal from './motion/Reveal';

const agences = [
  { nom: 'Agence Tampouy', agent: 'Issa', commissions: 4350, ops: 31, sync: 'il y a 2 min', float: 'ok' },
  { nom: 'Agence Pissy', agent: 'Mariam', commissions: 3820, ops: 27, sync: 'il y a 5 min', float: 'bas' },
  { nom: 'Agence Gounghin', agent: 'Salif', commissions: 2960, ops: 19, sync: 'il y a 1 h', float: 'ok' },
];

/** Ce que voit le patron : chaque agence, ses chiffres du jour, en direct. */
export default function PatronView() {
  const total = agences.reduce((s, a) => s + a.commissions, 0);
  return (
    <Reveal className="rounded-3xl border border-gray-200 bg-white p-5 shadow-[0_24px_60px_-30px_rgba(11,37,69,0.35)] sm:p-7">
      <div className="flex flex-wrap items-end justify-between gap-4 border-b border-gray-100 pb-5">
        <div>
          <p className="text-sm text-muted">Mes agences · aujourd’hui</p>
          <p className="mt-1 font-display text-3xl font-bold tabular-nums text-ink">
            {total.toLocaleString('fr-FR')} <span className="text-lg text-muted">FCFA de commissions</span>
          </p>
        </div>
        <p className="flex items-center gap-2 rounded-full bg-accent-50 px-3 py-1.5 text-sm font-medium text-accent">
          <span className="h-2 w-2 rounded-full bg-accent" />
          Mis à jour en continu
        </p>
      </div>
      <ul className="divide-y divide-gray-100">
        {agences.map((a) => (
          <li key={a.nom} className="flex flex-wrap items-center gap-4 py-4">
            <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary-50 text-primary">
              <Icon name="building" className="h-5 w-5" strokeWidth={1.8} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="font-semibold text-ink">{a.nom}</p>
              <p className="text-sm text-muted">
                {a.agent} · {a.ops} opérations · {a.sync}
              </p>
            </div>
            {a.float === 'bas' && (
              <span className="rounded-md bg-amber-50 px-2 py-1 text-xs font-semibold text-amber-800 ring-1 ring-amber-200">
                Float Moov bas
              </span>
            )}
            <span className="w-28 text-right font-display text-lg font-bold tabular-nums text-ink">
              {a.commissions.toLocaleString('fr-FR')}
            </span>
          </li>
        ))}
      </ul>
      <p className="mt-2 text-xs text-muted">Lecture seule : le patron voit tout, les agents gardent la main sur leur téléphone.</p>
    </Reveal>
  );
}
