'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import Icon from './Icon';
import PhoneDemo, { type DemoMode } from './PhoneDemo';

const copy: Record<DemoMode, { title: React.ReactNode; text: string; cta: string; facts: string[] }> = {
  particulier: {
    title: (
      <>
        Votre argent Mobile Money, <span className="text-primary">enfin clair.</span>
      </>
    ),
    text: 'MoneyTracking lit les SMS de vos opérateurs et range chaque dépense pour vous. Ajoutez vos espèces et votre banque : vous savez à tout moment où est votre argent, et où il part.',
    cta: 'Télécharger gratuitement',
    facts: ['Gratuit pour les particuliers', 'Vos données restent sur votre téléphone', 'Fonctionne sans Internet'],
  },
  agence: {
    title: (
      <>
        Votre agence tourne, <span className="text-primary">vos comptes se font seuls.</span>
      </>
    ),
    text: 'Chaque SMS de dépôt ou de retrait devient une opération, avec sa commission. Float par opérateur, clients, exports, et vue patron sur toutes vos agences.',
    cta: 'Essayer 3 mois gratuits',
    facts: ['3 mois offerts par agence', 'Commissions automatiques', 'Suivi multi-agence'],
  },
};

export default function Hero() {
  const [mode, setMode] = useState<DemoMode>('particulier');
  const c = copy[mode];

  return (
    <section className="relative overflow-hidden bg-soft">
      <div className="bg-grid absolute inset-0 [mask-image:linear-gradient(to_bottom,black,transparent_85%)]" />
      <div className="relative mx-auto grid max-w-6xl items-center gap-14 px-4 pb-20 pt-14 sm:px-6 sm:pt-20 lg:grid-cols-[1.1fr_0.9fr] lg:pb-28">
        <div>
          {/* Deux publics, deux promesses */}
          <div role="tablist" aria-label="Pour qui ?" className="inline-flex rounded-full border border-gray-200 bg-white p-1 text-sm shadow-sm">
            {(
              [
                ['particulier', 'Pour moi'],
                ['agence', 'Pour mon agence'],
              ] as const
            ).map(([value, label]) => (
              <button
                key={value}
                role="tab"
                aria-selected={mode === value}
                onClick={() => setMode(value)}
                className={`rounded-full px-4 py-1.5 font-medium transition-colors ${
                  mode === value ? 'bg-ink text-white' : 'text-muted hover:text-dark'
                }`}
              >
                {label}
              </button>
            ))}
          </div>

          <h1 key={`t-${mode}`} className="row-enter mt-7 font-display text-[2.6rem] font-bold leading-[1.05] tracking-tight text-ink sm:text-6xl">
            {c.title}
          </h1>
          <p key={`p-${mode}`} className="row-enter mt-6 max-w-xl text-lg leading-relaxed text-muted [animation-delay:80ms]">
            {c.text}
          </p>

          <div className="mt-9 flex flex-col gap-3 sm:flex-row">
            <Link
              href="/download"
              className="group inline-flex items-center justify-center gap-2 rounded-xl bg-accent px-6 py-3.5 text-sm font-semibold text-white transition-colors hover:bg-accent-hover"
            >
              <Icon name="download" className="h-4 w-4" strokeWidth={2} />
              {c.cta}
            </Link>
            <Link
              href="/features"
              className="group inline-flex items-center justify-center gap-2 rounded-xl border border-gray-300 bg-white px-6 py-3.5 text-sm font-semibold text-dark transition-colors hover:border-gray-400"
            >
              Voir comment ça marche
              <Icon name="arrowRight" className="h-4 w-4 transition-transform group-hover:translate-x-0.5" strokeWidth={2} />
            </Link>
          </div>

          <ul className="mt-9 flex flex-wrap gap-x-6 gap-y-2 text-sm text-dark/80">
            {c.facts.map((f) => (
              <li key={f} className="flex items-center gap-2">
                <Icon name="check" className="h-4 w-4 text-accent" strokeWidth={2.2} />
                {f}
              </li>
            ))}
          </ul>
        </div>

        <PhoneDemo mode={mode} />
      </div>
    </section>
  );
}
