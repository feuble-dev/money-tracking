import React from 'react';
import Reveal from './motion/Reveal';

export interface StoryStep {
  when: string;
  title: string;
  text: string;
  /** Ce que l'app a fait, en une phrase. */
  app?: string;
}

/** Frise d'une journée ou d'une semaine réelle, étape par étape. */
export default function Story({ steps, dark = false }: { steps: StoryStep[]; dark?: boolean }) {
  return (
    <ol className="relative">
      <span className={`absolute bottom-3 left-[6.25rem] top-3 w-px ${dark ? 'bg-white/15' : 'bg-ink/15'}`} aria-hidden="true" />
      {steps.map((s, i) => (
        <Reveal as="li" key={s.when + s.title} delay={i * 70} className="relative grid grid-cols-[5.5rem_1fr] gap-6 pb-9 last:pb-0">
          <span className={`pt-0.5 text-right font-display text-sm font-bold tabular-nums ${dark ? 'text-white/60' : 'text-clay'}`}>{s.when}</span>
          <div className="relative">
            <span
              className={`absolute -left-[1.125rem] top-1.5 h-3 w-3 rounded-full ring-4 ${
                dark ? 'bg-accent-light ring-ink' : 'bg-clay ring-white'
              }`}
              aria-hidden="true"
            />
            <p className={`font-display text-lg font-bold ${dark ? 'text-white' : 'text-ink'}`}>{s.title}</p>
            <p className={`mt-1 leading-relaxed ${dark ? 'text-white/70' : 'text-muted'}`}>{s.text}</p>
            {s.app && (
              <p
                className={`mt-3 inline-flex rounded-lg px-3 py-1.5 text-sm font-medium ${
                  dark ? 'bg-white/10 text-white' : 'bg-primary-50 text-primary'
                }`}
              >
                {s.app}
              </p>
            )}
          </div>
        </Reveal>
      ))}
    </ol>
  );
}
