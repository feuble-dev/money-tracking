import React from 'react';
import Link from 'next/link';
import Icon from './Icon';
import Reveal from './motion/Reveal';

export default function CtaBand() {
  return (
    <section className="bg-white px-4 pb-24 sm:px-6">
      <Reveal className="relative mx-auto max-w-6xl overflow-hidden rounded-3xl bg-ink px-8 py-16 text-center sm:px-16">
        <div className="bg-grid absolute inset-0 opacity-[0.07] invert" />
        <div className="relative">
          <h2 className="mx-auto max-w-2xl font-display text-3xl font-bold text-white sm:text-4xl">
            Votre prochain SMS Mobile Money pourrait déjà être rangé.
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-white/70">
            Gratuit pour vous, 3 mois offerts pour votre agence. Android 6 et plus.
          </p>
          <Link
            href="/download"
            className="mt-9 inline-flex items-center gap-2 rounded-xl bg-accent px-7 py-3.5 text-sm font-semibold text-white transition-colors hover:bg-accent-hover"
          >
            <Icon name="download" className="h-4 w-4" strokeWidth={2} />
            Télécharger MoneyTracking
          </Link>
        </div>
      </Reveal>
    </section>
  );
}
