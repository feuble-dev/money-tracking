import React from 'react';
import { steps } from '@/lib/site-content';
import Reveal from './motion/Reveal';
import SectionTitle from './SectionTitle';

export default function HowItWorks() {
  return (
    <section className="bg-white py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionTitle eyebrow="En trois minutes" title="Installez, cochez, c’est parti." />
        <ol className="relative mt-14 grid gap-10 md:grid-cols-3">
          {/* Fil qui relie les étapes */}
          <div className="absolute left-0 right-0 top-5 hidden h-px bg-gradient-to-r from-primary/40 via-primary/20 to-transparent md:block" />
          {steps.map((s, i) => (
            <Reveal as="li" key={s.title} delay={i * 120} className="relative">
              <span className="relative z-10 flex h-10 w-10 items-center justify-center rounded-full bg-ink font-display text-sm font-bold text-white ring-8 ring-white">
                {i + 1}
              </span>
              <h3 className="mt-5 font-display text-xl font-semibold text-ink">{s.title}</h3>
              <p className="mt-2 leading-relaxed text-muted">{s.description}</p>
            </Reveal>
          ))}
        </ol>
      </div>
    </section>
  );
}
