import React from 'react';
import Link from 'next/link';
import Icon, { type IconName } from './Icon';
import Reveal from './motion/Reveal';
import SectionTitle from './SectionTitle';

const blocks: {
  tag: string;
  title: string;
  price: string;
  points: { icon: IconName; text: string }[];
  href: string;
  cta: string;
  dark?: boolean;
}[] = [
  {
    tag: 'Pour moi',
    title: 'Savoir où part chaque franc',
    price: 'Gratuit, pour toujours',
    points: [
      { icon: 'wallet', text: 'Mobile Money, espèces, banque : un seul total' },
      { icon: 'pie', text: 'Dépenses rangées par motif, souvent toutes seules' },
      { icon: 'target', text: 'Un budget par motif, un bilan chaque mois' },
      { icon: 'history', text: 'Vos anciens SMS importés gratuitement' },
    ],
    href: '/download',
    cta: 'Télécharger',
  },
  {
    tag: 'Pour mon agence',
    title: 'Une agence qui se compte toute seule',
    price: 'Dès 450 FCFA / mois · 3 mois offerts',
    points: [
      { icon: 'coins', text: 'Commissions calculées sur chaque opération' },
      { icon: 'chart', text: 'Float par opérateur, alerte quand il baisse' },
      { icon: 'building', text: 'Vos agences et vos agents, vus d’un seul téléphone' },
      { icon: 'users', text: 'Clients, USSD, relevés PDF et CSV' },
    ],
    href: '/pricing',
    cta: 'Voir les tarifs',
    dark: true,
  },
];

export default function Audiences() {
  return (
    <section className="bg-soft py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionTitle
          eyebrow="Une application, deux usages"
          title="Que vous gériez votre budget ou une agence."
          text="Au premier lancement, choisissez votre usage : l’application s’adapte, ses écrans aussi."
        />
        <div className="mt-12 grid gap-6 lg:grid-cols-2">
          {blocks.map((b, i) => (
            <Reveal
              key={b.tag}
              delay={i * 120}
              className={`group flex flex-col rounded-3xl p-8 transition-transform duration-300 hover:-translate-y-1 sm:p-10 ${
                b.dark ? 'bg-ink text-white' : 'border border-gray-200 bg-white'
              }`}
            >
              <span
                className={`w-fit rounded-full px-3 py-1 text-xs font-semibold ${
                  b.dark ? 'bg-white/10 text-white' : 'bg-accent-50 text-accent'
                }`}
              >
                {b.tag}
              </span>
              <h3 className={`mt-5 font-display text-2xl font-bold sm:text-3xl ${b.dark ? '' : 'text-ink'}`}>
                {b.title}
              </h3>
              <p className={`mt-2 text-sm font-medium ${b.dark ? 'text-white/60' : 'text-muted'}`}>{b.price}</p>
              <ul className="mt-8 space-y-4">
                {b.points.map((p) => (
                  <li key={p.text} className="flex items-start gap-3">
                    <span
                      className={`mt-0.5 flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-lg ${
                        b.dark ? 'bg-white/10' : 'bg-primary-50 text-primary'
                      }`}
                    >
                      <Icon name={p.icon} className="h-4 w-4" />
                    </span>
                    <span className={b.dark ? 'text-white/85' : 'text-dark'}>{p.text}</span>
                  </li>
                ))}
              </ul>
              <Link
                href={b.href}
                className={`mt-10 inline-flex w-fit items-center gap-2 rounded-xl px-5 py-3 text-sm font-semibold transition-colors ${
                  b.dark ? 'bg-white text-ink hover:bg-primary-50' : 'bg-accent text-white hover:bg-accent-hover'
                }`}
              >
                {b.cta}
                <Icon name="arrowRight" className="h-4 w-4 transition-transform group-hover:translate-x-0.5" strokeWidth={2} />
              </Link>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
