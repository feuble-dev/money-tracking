import React from 'react';
import Pricing from '@/components/site/Pricing';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Tarifs - MoneyTracking',
  description: 'Découvrez nos tarifs simples et transparents. Essai gratuit de 30 jours inclus.',
};

const faq = [
  {
    question: 'L\'essai gratuit inclut-il toutes les fonctionnalités ?',
    answer:
      'Oui, pendant les 30 jours d\'essai, vous avez accès à toutes les fonctionnalités de MoneyTracking sans restriction.',
  },
  {
    question: 'Comment effectuer le paiement ?',
    answer:
      'Le paiement se fait par Mobile Money (Orange Money, Moov Money ou Coris Money). Vous recevrez une licence activée après paiement.',
  },
  {
    question: 'Puis-je changer de plan ?',
    answer:
      'Oui, vous pouvez passer du plan mensuel au plan annuel à tout moment. La différence sera calculée au prorata.',
  },
  {
    question: 'Que se passe-t-il quand ma licence expire ?',
    answer:
      'Vos données restent accessibles en lecture seule. Vous pourrez renouveler votre licence pour retrouver toutes les fonctionnalités.',
  },
];

export default function PricingPage() {
  return (
    <>
      {/* Header */}
      <section className="gradient-hero py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h1 className="text-4xl sm:text-5xl font-extrabold text-white mb-4">Tarifs</h1>
          <p className="text-lg text-blue-100 max-w-2xl mx-auto">
            Des prix adaptés aux agents Mobile Money du Burkina Faso. Commencez gratuitement.
          </p>
        </div>
      </section>

      {/* Pricing Cards */}
      <Pricing />

      {/* FAQ */}
      <section className="py-20 bg-white">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-2xl sm:text-3xl font-bold text-dark text-center mb-12">
            Questions fréquentes sur les tarifs
          </h2>
          <div className="space-y-6">
            {faq.map((item) => (
              <div key={item.question} className="p-6 bg-soft rounded-2xl">
                <h3 className="text-base font-bold text-dark mb-2">{item.question}</h3>
                <p className="text-gray-500 text-sm leading-relaxed">{item.answer}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
