import React from 'react';
import Reveal from './motion/Reveal';

/**
 * En-tête de section éditorial : un filet, un repère court, un titre fort
 * et, si besoin, un texte à droite plutôt que dessous (moins « gabarit »).
 */
export default function Chapter({
  mark,
  title,
  text,
  dark = false,
  className = '',
}: {
  mark: string;
  title: React.ReactNode;
  text?: React.ReactNode;
  dark?: boolean;
  className?: string;
}) {
  return (
    <Reveal className={`grid gap-6 border-t pt-6 lg:grid-cols-[1.2fr_0.8fr] lg:items-end ${dark ? 'border-white/15' : 'border-ink/15'} ${className}`}>
      <div>
        <p className={`text-xs font-semibold uppercase tracking-[0.18em] ${dark ? 'text-white/60' : 'text-clay'}`}>{mark}</p>
        <h2 className={`mt-3 font-display text-[2rem] font-bold leading-[1.08] tracking-tight sm:text-5xl ${dark ? 'text-white' : 'text-ink'}`}>
          {title}
        </h2>
      </div>
      {text && <p className={`text-lg leading-relaxed ${dark ? 'text-white/70' : 'text-muted'}`}>{text}</p>}
    </Reveal>
  );
}
