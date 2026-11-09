import React from 'react';
import { operators } from '@/lib/site-content';

/** Bandeau des opérateurs pris en charge, en défilement continu. */
export default function Operators() {
  const items = [...operators, ...operators, ...operators];
  return (
    <section className="overflow-hidden bg-soft py-10" aria-label="Opérateurs pris en charge">
      <p className="mb-6 text-center text-sm text-muted">Compatible avec les opérateurs de votre pays</p>
      <div className="relative [mask-image:linear-gradient(to_right,transparent,black_12%,black_88%,transparent)]">
        <ul className="marquee flex w-max gap-4">
          {[...items, ...items].map((op, i) => (
            <li
              key={i}
              className="whitespace-nowrap rounded-full border border-gray-200 bg-white px-6 py-2.5 font-display text-sm font-semibold text-ink"
            >
              {op}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
