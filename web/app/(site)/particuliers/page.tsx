import React from 'react';
import type { Metadata } from 'next';
import SplitHeader from '@/components/site/SplitHeader';
import Chapter from '@/components/site/Chapter';
import Story from '@/components/site/Story';
import Icon, { type IconName } from '@/components/site/Icon';
import Reveal from '@/components/site/motion/Reveal';
import PhoneFrame from '@/components/site/app/PhoneFrame';
import { BudgetScreen, MoneyScreen, Notification, SpendingScreen } from '@/components/site/app/screens';
import CtaBand from '@/components/site/CtaBand';

export const metadata: Metadata = {
  title: 'Pour les particuliers',
  description:
    'Suivez votre Mobile Money, vos espèces et votre banque au même endroit. Dépenses rangées par motif, budget mensuel, bilan du mois. Gratuit.',
};

const week = [
  { when: 'Lundi', title: 'Le salaire tombe sur Orange Money', text: '185 000 FCFA arrivent. Awa n’ouvre même pas l’application.', app: 'Rangé en « Salaire », solde Orange mis à jour' },
  { when: 'Mardi', title: 'Marché de Koudougou, en espèces', text: '3 500 FCFA de légumes. Deux gestes : le montant, « Nourriture ».', app: 'Ajouté au compte Espèces' },
  { when: 'Mercredi', title: 'Envoi à sa maman', text: '10 000 FCFA par Orange Money, comme chaque début de mois.', app: 'Rangé tout seul en « Famille » (règle apprise)' },
  { when: 'Vendredi', title: 'Facture SONABEL payée par Moov', text: '12 500 FCFA. Le budget Factures passe à 63 %.', app: 'Rangé en « Factures »' },
  { when: 'Dimanche', title: 'Retrait pour la tontine', text: '20 000 FCFA retirés pour la cotisation. Ce n’est pas une dépense : c’est de l’épargne.', app: 'Compté comme « Entre mes comptes », pas comme une dépense' },
];

const features: { icon: IconName; title: string; text: string }[] = [
  { icon: 'sms', title: 'Vos SMS, rangés', text: 'Orange Money, Moov Money, Coris Money, Wave : chaque SMS devient une opération, même application fermée.' },
  { icon: 'wallet', title: 'Tout votre argent', text: 'Espèces, banque, tontine, épargne à côté de vos portefeuilles Mobile Money. Un seul total.' },
  { icon: 'tag', title: 'Par motif, souvent tout seul', text: 'Nourriture, transport, famille, factures… Dites une fois « toujours ici » pour un numéro, c’est fini.' },
  { icon: 'target', title: 'Un budget qui prévient', text: 'Un plafond par motif, une alerte à 80 % et au dépassement. Rien de plus à configurer.' },
  { icon: 'sync', title: 'Paiements réguliers repérés', text: 'Loyer, abonnement, envoi mensuel : l’app les reconnaît et vous les montre.' },
  { icon: 'history', title: 'Vos anciens SMS, gratuitement', text: 'Récupérez des années d’historique dès l’installation. Gratuit pour un particulier.' },
  { icon: 'phone', title: 'Deux puces, un compte', text: 'Un téléphone pour Orange, un autre pour Moov ? Reliez-les : tout est réuni.' },
  { icon: 'export', title: 'Relevé PDF ou Excel', text: 'Pour un dossier de prêt, une tontine ou simplement garder une trace.' },
];

export default function ParticuliersPage() {
  return (
    <>
      <SplitHeader
        mark="Pour moi · gratuit"
        title={<>Savoir où va <span className="text-primary">chaque franc.</span></>}
        text="Vos SMS Mobile Money se rangent tout seuls. Ajoutez ce que vous payez en espèces en deux gestes : vous voyez enfin ce qui entre, ce qui sort, et ce qui reste."
        cta={{ href: '/download', label: 'Télécharger gratuitement' }}
        secondary={{ href: '/docs#mon-argent', label: 'Comment ça marche' }}
        screen={<MoneyScreen />}
      />

      <section className="bg-white py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter
            mark="Une semaine ordinaire"
            title="Awa, enseignante à Koudougou."
            text="Ce que l’application a fait pendant sa semaine — sans qu’elle ait à y penser."
          />
          <div className="mt-14 grid gap-14 lg:grid-cols-[1fr_auto]">
            <Story steps={week} />
            <div className="relative hidden lg:block">
              <div className="sticky top-28">
                <PhoneFrame width={260} height={520}>
                  <BudgetScreen />
                </PhoneFrame>
                <Notification
                  className="absolute -bottom-10 left-1/2 -translate-x-1/2"
                  title="Bilan d’octobre"
                  text="98 300 FCFA dépensés (−8 % vs septembre). Top : Nourriture 38 500 FCFA."
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="bg-soft py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter mark="Tout ce qu’elle fait" title="Simple tous les jours. Complète quand vous en avez besoin." />
          <div className="mt-14 grid gap-px overflow-hidden rounded-3xl border border-gray-200 bg-gray-200 sm:grid-cols-2 lg:grid-cols-4">
            {features.map((f, i) => (
              <Reveal key={f.title} delay={(i % 4) * 60} className="bg-white p-6">
                <Icon name={f.icon} className="h-6 w-6 text-primary" strokeWidth={1.7} />
                <p className="mt-4 font-display text-lg font-bold text-ink">{f.title}</p>
                <p className="mt-1.5 text-sm leading-relaxed text-muted">{f.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="overflow-hidden bg-white py-24 sm:py-28">
        <div className="mx-auto grid max-w-6xl items-center gap-14 px-4 sm:px-6 lg:grid-cols-2">
          <Reveal className="mx-auto">
            <PhoneFrame width={280} height={540} tilt={-3}>
              <SpendingScreen />
            </PhoneFrame>
          </Reveal>
          <Reveal>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-clay">Vie privée</p>
            <h2 className="mt-3 font-display text-[2rem] font-bold leading-[1.08] tracking-tight text-ink sm:text-5xl">
              Ce que vous achetez ne regarde que vous.
            </h2>
            <p className="mt-5 text-lg leading-relaxed text-muted">
              Vos dépenses, vos motifs et votre budget restent sur votre téléphone. Pas de publicité, pas de revente de
              données, pas de compte bancaire à relier. Un code PIN protège l’ouverture, et vos sauvegardes sont
              chiffrées avec votre mot de passe.
            </p>
            <ul className="mt-8 grid gap-3 sm:grid-cols-2">
              {['Aucune publicité', 'Aucune donnée vendue', 'Fonctionne sans Internet', 'Gratuit, pour toujours'].map((t) => (
                <li key={t} className="flex items-center gap-2 text-dark">
                  <Icon name="check" className="h-5 w-5 text-accent" strokeWidth={2.2} />
                  {t}
                </li>
              ))}
            </ul>
          </Reveal>
        </div>
      </section>

      <CtaBand />
    </>
  );
}
