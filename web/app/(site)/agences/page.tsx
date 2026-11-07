import React from 'react';
import type { Metadata } from 'next';
import SplitHeader from '@/components/site/SplitHeader';
import Chapter from '@/components/site/Chapter';
import Story from '@/components/site/Story';
import Comparison from '@/components/site/Comparison';
import PatronView from '@/components/site/PatronView';
import Pricing from '@/components/site/Pricing';
import CtaBand from '@/components/site/CtaBand';
import Icon, { type IconName } from '@/components/site/Icon';
import Reveal from '@/components/site/motion/Reveal';
import PhoneFrame from '@/components/site/app/PhoneFrame';
import { ClosingScreen, CommissionsScreen, Notification } from '@/components/site/app/screens';

export const metadata: Metadata = {
  title: 'Pour les agences Mobile Money',
  description:
    'Commissions calculées sur chaque opération, float par puce, clôture de caisse du soir, vue patron sur toutes vos agences. 3 mois offerts.',
};

const day = [
  { when: '07:30', title: 'Ouverture du kiosque', text: 'Issa compte 248 000 FCFA d’espèces. C’est le chiffre de la clôture d’hier : rien à ressaisir.' },
  { when: '10:15', title: 'Le rush du matin', text: '14 dépôts et retraits en une heure, sur trois puces. Il ne note rien.', app: 'Chaque SMS devient une opération, avec sa commission' },
  { when: '13:40', title: 'Le float Moov baisse', text: 'Il reste 38 000 FCFA sur la puce Moov, sous le seuil qu’il s’est fixé.', app: 'Notification : « Float Moov Money bas »' },
  { when: '16:00', title: 'Un client revient', text: '« J’ai déposé chez vous la semaine passée ? » Issa tape le numéro.', app: 'Historique du client en un geste' },
  { when: '19:00', title: 'Clôture', text: 'Il compte 405 000 FCFA. L’app attendait 408 000.', app: 'Il manque 3 000 FCFA — écart enregistré' },
  { when: '19:05', title: 'Chez le patron', text: 'Depuis son salon, le patron voit les trois agences et leurs commissions du jour.' },
];

const features: { icon: IconName; title: string; text: string }[] = [
  { icon: 'coins', title: 'Commissions automatiques', text: 'Un taux par opérateur et par service. Aujourd’hui, 7 jours, le mois — et ce qui rapporte le plus.' },
  { icon: 'chart', title: 'Float par puce, au franc près', text: 'Lu dans le dernier SMS de l’opérateur, jamais recalculé. Alerte sous votre seuil.' },
  { icon: 'target', title: 'Clôture du soir', text: 'Ce que vous devriez avoir, ce que vous avez compté, l’écart en clair. Historique des écarts.' },
  { icon: 'ussd', title: 'USSD en un geste', text: 'Opérateur, service, numéro ou contact, montant : le code est composé pour vous.' },
  { icon: 'users', title: 'Fichier clients', text: 'Nom, numéro, CNIB, historique, volume et commissions de chaque client. Un bouton pour l’appeler.' },
  { icon: 'building', title: 'Plusieurs agences', text: 'Chaque agent sur son téléphone ; vous, le détail de chaque agence en continu.' },
  { icon: 'export', title: 'Relevés PDF et CSV', text: 'Pour votre comptable, votre banque ou votre distributeur.' },
  { icon: 'history', title: 'Rien n’est perdu', text: 'Licence expirée ? Les SMS sont mis de côté et deviennent des opérations au renouvellement.' },
];

export default function AgencesPage() {
  return (
    <>
      <SplitHeader
        tone="ink"
        mark="Pour mon agence · 3 mois offerts"
        title={<>Vos comptes se font <span className="text-accent-light">pendant que vous servez.</span></>}
        text="Chaque SMS de dépôt ou de retrait devient une opération, avec sa commission. Float par puce, clôture du soir, clients, et une vue patron sur toutes vos agences."
        cta={{ href: '/download', label: 'Essayer 3 mois gratuits' }}
        secondary={{ href: '#tarifs', label: 'Voir les tarifs' }}
        screen={<CommissionsScreen />}
      />

      <section className="bg-white py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter mark="Une journée" title="Issa, agent à Tampouy." text="Trois puces, un kiosque, et plus de cahier." />
          <div className="mt-14 grid gap-14 lg:grid-cols-[1fr_auto]">
            <Story steps={day} />
            <div className="relative hidden lg:block">
              <div className="sticky top-28">
                <PhoneFrame width={260} height={520}>
                  <ClosingScreen />
                </PhoneFrame>
                <Notification
                  icon="alert"
                  className="absolute -bottom-10 left-1/2 -translate-x-1/2"
                  title="Float Moov Money bas"
                  text="Solde 38 000 FCFA, sous votre seuil de 50 000 FCFA."
                  time="13:40"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="bg-sand py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter
            mark="Pour le patron"
            title="Toutes vos agences, depuis votre téléphone."
            text="Vos agents rejoignent l’agence en entrant votre numéro ; vous approuvez. Ensuite, chaque opération remonte dès qu’ils ont du réseau — annulations comprises."
          />
          <div className="mt-12">
            <PatronView />
          </div>
        </div>
      </section>

      <section className="bg-white py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter mark="Au quotidien" title="Tout ce qu’un agent fait déjà. Sans le recopier." />
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

      <section className="bg-soft py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter mark="Avant / après" title="Le cahier a bien servi." />
          <div className="mt-12">
            <Comparison />
          </div>
        </div>
      </section>

      <div id="tarifs">
        <Pricing />
      </div>
      <CtaBand />
    </>
  );
}
