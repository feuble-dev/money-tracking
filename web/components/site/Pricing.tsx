import React from 'react';
import Link from 'next/link';

const plans = [
  {
    name: 'Essai gratuit',
    price: 'Gratuit',
    period: '30 jours',
    description: 'Toutes les fonctionnalites, sans engagement.',
    features: [
      'Detection SMS automatique',
      'Dashboard complet',
      'Export PDF & CSV',
      'Gestion clients',
      '30 jours d\'essai',
    ],
    cta: 'Commencer l\'essai',
    highlighted: false,
  },
  {
    name: 'Annuel',
    price: '10 000',
    currency: 'FCFA',
    period: 'par an',
    description: '2 mois offerts par rapport au mensuel.',
    features: [
      'Toutes les fonctionnalites',
      'Detection SMS automatique',
      'Dashboard complet',
      'Export PDF & CSV',
      'Support prioritaire',
      'Mises a jour automatiques',
    ],
    cta: 'Choisir l\'annuel',
    highlighted: true,
  },
  {
    name: 'Mensuel',
    price: '1 000',
    currency: 'FCFA',
    period: 'par mois',
    description: 'Sans engagement, resiliable a tout moment.',
    features: [
      'Toutes les fonctionnalites',
      'Detection SMS automatique',
      'Dashboard complet',
      'Export PDF & CSV',
      'Support par email',
    ],
    cta: 'Choisir le mensuel',
    highlighted: false,
  },
];

export default function Pricing() {
  return (
    <section className="py-20 bg-soft">
      <div className="max-w-6xl mx-auto px-4 sm:px-6">
        <div className="mb-12">
          <h2 className="text-2xl sm:text-3xl font-bold text-dark">Tarifs</h2>
          <p className="mt-2 text-muted">Commencez gratuitement, puis choisissez le plan qui vous convient.</p>
        </div>

        <div className="grid md:grid-cols-3 gap-6 max-w-4xl">
          {plans.map((plan) => (
            <div key={plan.name}
              className={`rounded-xl p-6 ${
                plan.highlighted
                  ? 'bg-accent text-white ring-1 ring-accent'
                  : 'bg-white border border-gray-200'
              }`}>
              <p className={`text-sm font-medium ${plan.highlighted ? 'text-green-200' : 'text-muted'}`}>
                {plan.name}
              </p>
              <div className="mt-3 flex items-baseline gap-1">
                <span className={`text-3xl font-bold ${plan.highlighted ? 'text-white' : 'text-dark'}`}>
                  {plan.price}
                </span>
                {plan.currency && (
                  <span className={`text-sm ${plan.highlighted ? 'text-green-200' : 'text-muted'}`}>
                    {plan.currency}
                  </span>
                )}
              </div>
              <p className={`text-xs mt-1 ${plan.highlighted ? 'text-green-200' : 'text-muted'}`}>
                {plan.period}
              </p>
              <p className={`text-sm mt-3 ${plan.highlighted ? 'text-green-100' : 'text-muted'}`}>
                {plan.description}
              </p>

              <ul className="mt-6 space-y-2.5">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm">
                    <svg className={`w-4 h-4 mt-0.5 flex-shrink-0 ${plan.highlighted ? 'text-green-400' : 'text-green-600'}`}
                      fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className={plan.highlighted ? 'text-gray-200' : 'text-gray-600'}>{f}</span>
                  </li>
                ))}
              </ul>

              <Link href="/download"
                className={`block text-center mt-6 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                  plan.highlighted
                    ? 'bg-white text-accent hover:bg-green-50'
                    : 'bg-accent-50 text-accent hover:bg-green-100'
                }`}>
                {plan.cta}
              </Link>
            </div>
          ))}
        </div>

        <div className="mt-10 max-w-4xl">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 p-5 bg-white rounded-xl border border-gray-200">
            <div>
              <p className="font-semibold text-dark text-sm">Import historique SMS</p>
              <p className="text-muted text-sm mt-0.5">
                Recuperez vos anciennes transactions depuis vos SMS. Achat unique, illimite sur l&apos;appareil.
              </p>
            </div>
            <div className="flex items-center gap-3 flex-shrink-0">
              <span className="text-xl font-bold text-dark">2 000 <span className="text-sm font-normal text-muted">FCFA</span></span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
