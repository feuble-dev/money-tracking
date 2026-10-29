import React from 'react';
import { features, type Audience } from '@/lib/site-content';
import Icon from './Icon';
import Reveal from './motion/Reveal';

/** Grille de fonctionnalités, filtrable par public. */
export default function FeatureGrid({
  audience,
  limit,
  dark = false,
}: {
  audience?: Audience;
  limit?: number;
  dark?: boolean;
}) {
  const list = features
    .filter((f) => !audience || f.audience === audience || f.audience === 'tous')
    .slice(0, limit);
  return (
    <div
      className={`grid overflow-hidden rounded-2xl border sm:grid-cols-2 lg:grid-cols-3 ${
        dark ? 'gap-px border-white/10 bg-white/10' : 'gap-px border-gray-200 bg-gray-200'
      }`}
    >
      {list.map((f, i) => (
        <Reveal key={f.title} delay={(i % 3) * 90} className={dark ? 'bg-ink p-7' : 'bg-white p-7'}>
          <span
            className={`flex h-10 w-10 items-center justify-center rounded-xl ${
              dark ? 'bg-white/10 text-white' : 'bg-primary-50 text-primary'
            }`}
          >
            <Icon name={f.icon} />
          </span>
          <h3 className={`mt-5 font-display text-lg font-semibold ${dark ? 'text-white' : 'text-ink'}`}>{f.title}</h3>
          <p className={`mt-2 text-[15px] leading-relaxed ${dark ? 'text-white/65' : 'text-muted'}`}>{f.description}</p>
        </Reveal>
      ))}
    </div>
  );
}
