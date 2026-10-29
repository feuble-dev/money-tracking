import React from 'react';
import Reveal from './motion/Reveal';

export default function SectionTitle({
  eyebrow,
  title,
  text,
  align = 'left',
  dark = false,
}: {
  eyebrow?: string;
  title: React.ReactNode;
  text?: string;
  align?: 'left' | 'center';
  dark?: boolean;
}) {
  return (
    <Reveal className={`max-w-2xl ${align === 'center' ? 'mx-auto text-center' : ''}`}>
      {eyebrow && (
        <p className={`text-sm font-semibold ${dark ? 'text-primary-200' : 'text-primary'}`}>{eyebrow}</p>
      )}
      <h2
        className={`mt-2 font-display text-3xl font-bold leading-tight tracking-tight sm:text-4xl ${
          dark ? 'text-white' : 'text-ink'
        }`}
      >
        {title}
      </h2>
      {text && <p className={`mt-4 text-lg leading-relaxed ${dark ? 'text-white/70' : 'text-muted'}`}>{text}</p>}
    </Reveal>
  );
}
