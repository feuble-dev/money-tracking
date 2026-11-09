import React from 'react';
import Icon, { type IconName } from './Icon';
import Reveal from './motion/Reveal';

const points: { icon: IconName; title: string; text: string }[] = [
  { icon: 'lock', title: 'Code PIN et empreinte', text: 'L’app se verrouille quand vous la quittez. Après 5 erreurs, le code est bloqué un moment.' },
  { icon: 'shield', title: 'Sauvegarde chiffrée', text: 'Protégée par votre mot de passe (AES-256). Envoyez-la sur WhatsApp ou Drive sans crainte.' },
  { icon: 'phone', title: 'Rien ne part de votre téléphone', text: 'Vos SMS et vos dépenses personnelles restent chez vous. Seule une agence partage ses opérations avec son patron.' },
];

// Aperçu d'un fichier de sauvegarde : sans le mot de passe, illisible.
const bytes = 'MMTBAK2·9f2c71e0·a83d4b19·c40e77f2·51b9d0aa·e61f3c28·0b94a7d5·3ce812f0·7a5d19c6·f02be841·94c7a3e5·1d6f08b2';

export default function Privacy() {
  return (
    <section className="bg-white py-24 sm:py-28">
      <div className="mx-auto grid max-w-6xl items-center gap-14 px-4 sm:px-6 lg:grid-cols-[0.9fr_1.1fr]">
        <Reveal>
          <div className="rounded-3xl bg-ink p-6 text-white shadow-[0_30px_70px_-30px_rgba(11,37,69,0.6)]">
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-white/10">
                <Icon name="shield" className="h-5 w-5" strokeWidth={1.8} />
              </span>
              <div>
                <p className="font-mono text-sm">moneytracking_2026-11-07.mmtbak</p>
                <p className="text-xs text-white/50">Sauvegarde · 1,2 Mo</p>
              </div>
            </div>
            <p className="mt-5 break-all font-mono text-[13px] leading-relaxed text-white/40">{bytes}</p>
            <div className="mt-5 flex items-center gap-2 rounded-xl bg-white/5 px-3 py-2.5 text-sm text-white/80 ring-1 ring-white/10">
              <Icon name="lock" className="h-4 w-4" strokeWidth={2} />
              Sans votre mot de passe, personne ne peut la lire. Pas même nous.
            </div>
          </div>
        </Reveal>
        <Reveal delay={100}>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-clay">Vos données</p>
          <h2 className="mt-3 font-display text-[2rem] font-bold leading-[1.08] tracking-tight text-ink sm:text-5xl">
            Votre argent, c’est privé. L’app le traite comme tel.
          </h2>
          <ul className="mt-9 space-y-6">
            {points.map((p) => (
              <li key={p.title} className="flex gap-4">
                <span className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl bg-primary-50 text-primary">
                  <Icon name={p.icon} className="h-5 w-5" strokeWidth={1.8} />
                </span>
                <div>
                  <p className="font-display text-lg font-bold text-ink">{p.title}</p>
                  <p className="mt-1 leading-relaxed text-muted">{p.text}</p>
                </div>
              </li>
            ))}
          </ul>
        </Reveal>
      </div>
    </section>
  );
}
