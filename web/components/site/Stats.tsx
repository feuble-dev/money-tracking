import React from 'react';
import CountUp from './motion/CountUp';
import Reveal from './motion/Reveal';

const stats = [
  { value: 4, suffix: '', label: 'opérateurs reconnus au Burkina Faso' },
  { value: 0, suffix: ' FCFA', label: 'pour un particulier, pour toujours' },
  { value: 100, suffix: ' %', label: 'de vos données sur votre téléphone' },
  { value: 3, suffix: ' mois', label: 'd’essai offerts à chaque agence' },
];

export default function Stats() {
  return (
    <section className="border-y border-gray-200 bg-white">
      <div className="mx-auto grid max-w-6xl grid-cols-2 divide-x divide-y divide-gray-200 sm:px-6 lg:grid-cols-4 lg:divide-y-0">
        {stats.map((s, i) => (
          <Reveal key={s.label} delay={i * 80} className="px-6 py-10">
            <p className="font-display text-4xl font-bold text-ink sm:text-5xl">
              <CountUp to={s.value} suffix={s.suffix} />
            </p>
            <p className="mt-2 text-sm text-muted">{s.label}</p>
          </Reveal>
        ))}
      </div>
    </section>
  );
}
