import React from 'react';
import Link from 'next/link';
import Icon from './Icon';
import Reveal from './motion/Reveal';
import Annotation from './Annotation';
import PhoneFrame from './app/PhoneFrame';
import { BudgetScreen, ClosingScreen, CommissionsScreen, Notification, SpendingScreen } from './app/screens';

function Points({ items, dark = false }: { items: string[]; dark?: boolean }) {
  return (
    <ul className="mt-8 space-y-3">
      {items.map((t) => (
        <li key={t} className={`flex gap-3 ${dark ? 'text-white/85' : 'text-dark'}`}>
          <Icon name="check" className={`mt-0.5 h-5 w-5 flex-shrink-0 ${dark ? 'text-accent-light' : 'text-accent'}`} strokeWidth={2.2} />
          {t}
        </li>
      ))}
    </ul>
  );
}

/** Particulier : deux écrans (dépenses, budget) et ce qu'ils changent. */
export function ParticulierShowcase({ withLink = true }: { withLink?: boolean }) {
  return (
    <div className="grid items-center gap-14 lg:grid-cols-2">
      <Reveal>
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-clay">Pour moi · gratuit</p>
        <h2 className="mt-3 font-display text-[2rem] font-bold leading-[1.08] tracking-tight text-ink sm:text-5xl">
          À la fin du mois, vous savez où est passé l’argent.
        </h2>
        <p className="mt-5 text-lg leading-relaxed text-muted">
          Vos SMS sont rangés par motif, vos espèces et votre banque à côté. Le budget prévient avant le dépassement, pas
          après.
        </p>
        <Points
          items={[
            'Mobile Money, espèces, banque, tontine : un seul total',
            '« Toujours ranger ce numéro ici » : on ne vous redemande plus',
            'Un bilan au début de chaque mois, sans rien faire',
          ]}
        />
        {withLink && (
          <Link href="/particuliers" className="group mt-9 inline-flex items-center gap-2 font-semibold text-primary">
            Tout ce que l’app fait pour vous
            <Icon name="arrowRight" className="h-4 w-4 transition-transform group-hover:translate-x-1" strokeWidth={2} />
          </Link>
        )}
      </Reveal>
      <div className="flex min-w-0 justify-center">
      <div className="relative mx-auto flex h-[600px] w-[520px] max-w-none flex-shrink-0 origin-top items-center justify-center max-sm:-mb-48 max-sm:scale-[0.66]">
        <Reveal className="absolute left-0 top-6 sm:left-4">
          <PhoneFrame tilt={-5} width={250} height={500}>
            <SpendingScreen />
          </PhoneFrame>
        </Reveal>
        <Reveal delay={140} className="absolute right-0 top-20 sm:right-2">
          <PhoneFrame tilt={4} width={250} height={500}>
            <BudgetScreen />
          </PhoneFrame>
        </Reveal>
        <Annotation direction="down" className="absolute -bottom-2 left-1/2 hidden -translate-x-[110%] sm:flex">
          Rouge dès que la famille dépasse le prévu
        </Annotation>
      </div>
      </div>
    </div>
  );
}

/** Agence : commissions, clôture du soir, alerte de float. */
export function AgenceShowcase({ withLink = true }: { withLink?: boolean }) {
  return (
    <div className="grid items-center gap-14 lg:grid-cols-2">
      <div className="order-2 flex min-w-0 justify-center lg:order-1">
      <div className="relative mx-auto flex h-[600px] w-[520px] max-w-none flex-shrink-0 origin-top items-center justify-center max-sm:-mb-48 max-sm:scale-[0.66]">
        <Reveal className="absolute left-0 top-10 sm:left-4">
          <PhoneFrame tilt={-4} width={250} height={500}>
            <CommissionsScreen />
          </PhoneFrame>
        </Reveal>
        <Reveal delay={140} className="absolute right-0 top-24 sm:right-2">
          <PhoneFrame tilt={5} width={250} height={500}>
            <ClosingScreen />
          </PhoneFrame>
        </Reveal>
        <Reveal delay={260} className="absolute -top-2 left-1/2 -translate-x-1/2">
          <Notification
            icon="alert"
            title="Float Moov Money bas"
            text="Solde 38 000 FCFA, sous votre seuil de 50 000 FCFA. Pensez à recharger."
          />
        </Reveal>
      </div>
      </div>
      <Reveal className="order-1 lg:order-2">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-white/60">Pour mon agence · 3 mois offerts</p>
        <h2 className="mt-3 font-display text-[2rem] font-bold leading-[1.08] tracking-tight text-white sm:text-5xl">
          Le soir, la caisse tombe juste. Ou vous savez pourquoi.
        </h2>
        <p className="mt-5 text-lg leading-relaxed text-white/70">
          Chaque dépôt et chaque retrait arrive avec sa commission. Le float de chaque puce vient du dernier SMS, et la
          clôture compare ce que vous devriez avoir à ce que vous avez compté.
        </p>
        <Points
          dark
          items={[
            'Commissions du jour, de la semaine, du mois — et ce qui rapporte le plus',
            'Alerte avant de manquer de float sur une puce',
            'Vos agents travaillent, vous suivez chaque agence depuis votre téléphone',
          ]}
        />
        {withLink && (
          <Link href="/agences" className="group mt-9 inline-flex items-center gap-2 font-semibold text-white">
            Tout pour les agences
            <Icon name="arrowRight" className="h-4 w-4 transition-transform group-hover:translate-x-1" strokeWidth={2} />
          </Link>
        )}
      </Reveal>
    </div>
  );
}
