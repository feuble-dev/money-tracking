import React from 'react';
import { faq } from '@/lib/site-content';
import Icon from './Icon';
import Reveal from './motion/Reveal';

/** Questions fréquentes : <details> natif, accessible sans JavaScript. */
export default function Faq() {
  return (
    <section id="faq" className="bg-white py-24">
      <div className="mx-auto grid max-w-6xl gap-12 px-4 sm:px-6 lg:grid-cols-[0.8fr_1.2fr]">
        <div className="border-t border-ink/15 pt-6">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-clay">Questions fréquentes</p>
          <h2 className="mt-3 font-display text-[2rem] font-bold leading-[1.08] tracking-tight text-ink sm:text-5xl">
            Ce qu’on nous demande souvent.
          </h2>
        </div>
        <div className="divide-y divide-gray-200 border-y border-gray-200">
          {faq.map((item, i) => (
            <Reveal key={item.q} delay={i * 60}>
              <details className="group py-5">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-6 font-display text-lg font-semibold text-ink">
                  {item.q}
                  <span className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full border border-gray-200 transition-transform duration-300 group-open:rotate-45">
                    <Icon name="plus" className="h-4 w-4" strokeWidth={2} />
                  </span>
                </summary>
                <p className="mt-3 max-w-2xl leading-relaxed text-muted">{item.a}</p>
              </details>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
