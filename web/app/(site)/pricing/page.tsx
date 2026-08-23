import React from 'react';
import Pricing from '@/components/site/Pricing';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Tarifs - MoneyTracking',
  description: 'Tarifs simples et transparents, factures par agence. Essai gratuit de 3 mois.',
};

const faq = [
  {
    question: 'L\'essai gratuit inclut-il toutes les fonctionnalites ?',
    answer: 'Oui, pendant 3 mois vous avez acces a toutes les fonctionnalites sans restriction, sur chaque nouvelle agence creee.',
  },
  {
    question: 'Pourquoi la licence est-elle facturee par agence ?',
    answer: 'Un compte peut gerer plusieurs agences (Particulier comme Agence). Chaque agence a son propre abonnement et son propre essai gratuit, independamment des autres.',
  },
  {
    question: 'Comment effectuer le paiement ?',
    answer: 'Par Mobile Money (Orange Money, Moov Money ou Coris Money). Vous recevez votre licence apres paiement.',
  },
  {
    question: 'Puis-je changer de plan ?',
    answer: 'Oui, vous pouvez passer du mensuel a l\'annuel a tout moment.',
  },
  {
    question: 'Que se passe-t-il quand ma licence expire ?',
    answer: 'Vos donnees restent accessibles en lecture. Renouvelez pour retrouver toutes les fonctionnalites.',
  },
];

export default function PricingPage() {
  return (
    <>
      <section className="gradient-hero py-16">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <h1 className="text-3xl sm:text-4xl font-bold text-white">Tarifs</h1>
          <p className="mt-3 text-blue-200 max-w-lg">
            Prix adaptes aux agents Mobile Money du Burkina Faso.
          </p>
        </div>
      </section>

      <Pricing />

      <section className="py-16 bg-white">
        <div className="max-w-3xl mx-auto px-4 sm:px-6">
          <h2 className="text-xl font-bold text-dark mb-6">Questions frequentes</h2>
          <div className="space-y-4">
            {faq.map((item) => (
              <div key={item.question} className="p-4 bg-soft rounded-lg border border-gray-100">
                <p className="font-medium text-dark text-sm mb-1">{item.question}</p>
                <p className="text-sm text-muted">{item.answer}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
