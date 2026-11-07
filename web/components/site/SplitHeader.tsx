import React from 'react';
import Link from 'next/link';
import Icon from './Icon';
import PhoneFrame from './app/PhoneFrame';

/** En-tête des pages Particuliers / Agences : promesse à gauche, écran réel à droite. */
export default function SplitHeader({
  mark,
  title,
  text,
  cta,
  secondary,
  screen,
  tone = 'sand',
}: {
  mark: string;
  title: React.ReactNode;
  text: string;
  cta: { href: string; label: string };
  secondary?: { href: string; label: string };
  screen: React.ReactNode;
  tone?: 'sand' | 'ink';
}) {
  const dark = tone === 'ink';
  return (
    <section className={`overflow-hidden ${dark ? 'bg-ink' : 'bg-sand'}`}>
      <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 pb-0 pt-14 sm:px-6 sm:pt-20 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="fade-up pb-14 lg:pb-24">
          <p className={`text-xs font-semibold uppercase tracking-[0.18em] ${dark ? 'text-white/60' : 'text-clay'}`}>{mark}</p>
          <h1 className={`mt-4 font-display text-[2.5rem] font-bold leading-[1.04] tracking-tight sm:text-6xl ${dark ? 'text-white' : 'text-ink'}`}>
            {title}
          </h1>
          <p className={`mt-6 max-w-xl text-lg leading-relaxed ${dark ? 'text-white/70' : 'text-muted'}`}>{text}</p>
          <div className="mt-9 flex flex-col gap-3 sm:flex-row">
            <Link
              href={cta.href}
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-accent px-6 py-3.5 text-sm font-semibold text-white transition-colors hover:bg-accent-hover"
            >
              <Icon name="download" className="h-4 w-4" strokeWidth={2} />
              {cta.label}
            </Link>
            {secondary && (
              <Link
                href={secondary.href}
                className={`inline-flex items-center justify-center gap-2 rounded-xl border px-6 py-3.5 text-sm font-semibold transition-colors ${
                  dark ? 'border-white/25 text-white hover:bg-white/10' : 'border-ink/20 text-ink hover:bg-white/60'
                }`}
              >
                {secondary.label}
              </Link>
            )}
          </div>
        </div>
        <div className="mx-auto pb-14 lg:pb-20">
          <PhoneFrame width={290} height={560}>
            {screen}
          </PhoneFrame>
        </div>
      </div>
    </section>
  );
}
