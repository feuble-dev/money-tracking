import React from 'react';
import type { Metadata } from 'next';
import { features } from '@/lib/site-content';
import PageHeader from '@/components/site/PageHeader';
import Icon from '@/components/site/Icon';
import Reveal from '@/components/site/motion/Reveal';
import CtaBand from '@/components/site/CtaBand';

export const metadata: Metadata = {
  title: 'Fonctionnalités',
  description:
    'Détection automatique des SMS Mobile Money, suivi de tout votre argent, budget, commissions, multi-agence.',
};

const groups = [
  { id: 'tous', title: 'Pour tout le monde', text: 'Le socle : vos SMS deviennent des opérations, sur votre téléphone.' },
  { id: 'particulier', title: 'Pour les particuliers', text: 'Comprendre et maîtriser son argent, gratuitement.' },
  { id: 'agence', title: 'Pour les agences', text: 'Tenir une agence Mobile Money sans cahier ni calculatrice.' },
] as const;

export default function FeaturesPage() {
  return (
    <>
      <PageHeader
        eyebrow="Fonctionnalités"
        title="Tout ce qu’il faut, rien de compliqué."
        text="Une application qui lit vos SMS d’opérateur et en tire des comptes clairs — que vous suiviez votre budget ou que vous teniez une agence."
      />
      {groups.map((g, gi) => (
        <section key={g.id} className={gi % 2 ? 'bg-soft py-20' : 'bg-white py-20'}>
          <div className="mx-auto grid max-w-6xl gap-10 px-4 sm:px-6 lg:grid-cols-[0.7fr_1.3fr]">
            <Reveal className="lg:sticky lg:top-24 lg:self-start">
              <h2 className="font-display text-3xl font-bold text-ink">{g.title}</h2>
              <p className="mt-3 text-muted">{g.text}</p>
            </Reveal>
            <div className="space-y-4">
              {features
                .filter((f) => f.audience === g.id)
                .map((f, i) => (
                  <Reveal
                    key={f.title}
                    delay={i * 80}
                    className="rounded-2xl border border-gray-200 bg-white p-6 transition-colors hover:border-primary/30"
                  >
                    <div className="flex items-start gap-4">
                      <span className="flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-xl bg-primary-50 text-primary">
                        <Icon name={f.icon} />
                      </span>
                      <div>
                        <h3 className="font-display text-lg font-semibold text-ink">{f.title}</h3>
                        <p className="mt-1.5 leading-relaxed text-muted">{f.description}</p>
                        {f.points && (
                          <ul className="mt-4 space-y-2">
                            {f.points.map((p) => (
                              <li key={p} className="flex items-start gap-2 text-sm text-dark">
                                <Icon name="check" className="mt-0.5 h-4 w-4 flex-shrink-0 text-accent" strokeWidth={2.4} />
                                {p}
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                    </div>
                  </Reveal>
                ))}
            </div>
          </div>
        </section>
      ))}
      <CtaBand />
    </>
  );
}
