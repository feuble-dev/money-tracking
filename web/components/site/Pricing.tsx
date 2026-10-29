import React from 'react';
import Link from 'next/link';
import { plans } from '@/lib/site-content';
import Icon from './Icon';
import Reveal from './motion/Reveal';
import SectionTitle from './SectionTitle';

export default function Pricing({ withTitle = true }: { withTitle?: boolean }) {
  return (
    <section className="bg-soft py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        {withTitle && (
          <SectionTitle
            eyebrow="Tarifs"
            title="Gratuit pour vous. Juste pour votre agence."
            text="Un particulier ne paie jamais. Une agence paie sa licence, avec 3 mois offerts à la création."
          />
        )}
        <div className="mt-12 grid gap-6 lg:grid-cols-3">
          {plans.map((p, i) => (
            <Reveal
              key={p.name}
              delay={i * 100}
              className={`relative flex flex-col rounded-3xl p-8 ${
                p.highlighted ? 'bg-ink text-white' : 'border border-gray-200 bg-white'
              }`}
            >
              {p.highlighted && (
                <span className="absolute right-6 top-6 rounded-full bg-accent px-3 py-1 text-xs font-semibold text-white">
                  Le plus choisi
                </span>
              )}
              <p className={`text-sm font-medium ${p.highlighted ? 'text-white/60' : 'text-muted'}`}>{p.audience}</p>
              <h3 className={`mt-1 font-display text-xl font-bold ${p.highlighted ? '' : 'text-ink'}`}>{p.name}</h3>
              <p className="mt-6 flex items-baseline gap-1.5">
                <span className={`font-display text-5xl font-bold ${p.highlighted ? '' : 'text-ink'}`}>{p.price}</span>
                {p.unit && <span className={p.highlighted ? 'text-white/60' : 'text-muted'}>{p.unit}</span>}
              </p>
              <p className={`text-sm ${p.highlighted ? 'text-white/60' : 'text-muted'}`}>{p.period}</p>
              <p className={`mt-5 text-[15px] leading-relaxed ${p.highlighted ? 'text-white/80' : 'text-muted'}`}>
                {p.description}
              </p>
              <ul className="mt-6 flex-1 space-y-3">
                {p.features.map((f) => (
                  <li key={f} className="flex items-start gap-2.5 text-[15px]">
                    <Icon
                      name="check"
                      className={`mt-0.5 h-4 w-4 flex-shrink-0 ${p.highlighted ? 'text-accent-light' : 'text-accent'}`}
                      strokeWidth={2.4}
                    />
                    <span className={p.highlighted ? 'text-white/85' : 'text-dark'}>{f}</span>
                  </li>
                ))}
              </ul>
              <Link
                href="/download"
                className={`mt-8 block rounded-xl py-3 text-center text-sm font-semibold transition-colors ${
                  p.highlighted ? 'bg-accent text-white hover:bg-accent-hover' : 'bg-soft text-ink hover:bg-gray-200'
                }`}
              >
                {p.cta}
              </Link>
            </Reveal>
          ))}
        </div>
        <Reveal className="mt-6 flex flex-col justify-between gap-4 rounded-2xl border border-gray-200 bg-white p-6 sm:flex-row sm:items-center">
          <div>
            <p className="font-display font-semibold text-ink">Import de l’historique SMS (agences)</p>
            <p className="mt-1 text-sm text-muted">
              Gratuit jusqu’à un an en arrière, puis 200 FCFA par année supplémentaire. Toujours gratuit pour un particulier.
            </p>
          </div>
          <p className="font-display text-2xl font-bold text-ink">Dès 0 FCFA</p>
        </Reveal>
      </div>
    </section>
  );
}
