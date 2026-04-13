import React from 'react';
import Link from 'next/link';

const plans = [
  {
    name: 'Essai Gratuit',
    price: 'Gratuit',
    period: '30 jours',
    description: 'Testez toutes les fonctionnalités sans engagement.',
    features: [
      'Toutes les fonctionnalités',
      'Détection SMS automatique',
      'Dashboard complet',
      'Export PDF & CSV',
      '30 jours d\'essai',
    ],
    cta: 'Commencer l\'essai',
    highlighted: false,
  },
  {
    name: 'Annuel',
    price: '10 000',
    currency: 'FCFA',
    period: '/an',
    badge: 'Populaire',
    discount: 'Économisez 2 000 FCFA',
    description: 'La meilleure offre pour votre agence.',
    features: [
      'Toutes les fonctionnalités',
      'Détection SMS automatique',
      'Dashboard complet',
      'Export PDF & CSV',
      'Support prioritaire',
      'Mises à jour automatiques',
      '2 mois offerts',
    ],
    cta: 'Choisir le plan annuel',
    highlighted: true,
  },
  {
    name: 'Mensuel',
    price: '1 000',
    currency: 'FCFA',
    period: '/mois',
    description: 'Flexibilité totale sans engagement.',
    features: [
      'Toutes les fonctionnalités',
      'Détection SMS automatique',
      'Dashboard complet',
      'Export PDF & CSV',
      'Support par email',
      'Sans engagement',
    ],
    cta: 'Choisir ce plan',
    highlighted: false,
  },
];

export default function Pricing() {
  return (
    <section className="py-24 bg-soft relative overflow-hidden">
      <div className="absolute inset-0 opacity-30">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-primary/5 rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-accent/5 rounded-full blur-3xl" />
      </div>

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-white text-primary text-sm font-semibold rounded-full shadow-soft mb-4">
            Tarifs
          </div>
          <h2 className="text-3xl sm:text-4xl font-extrabold text-dark mb-4">
            Des tarifs simples et transparents
          </h2>
          <p className="text-lg text-muted max-w-2xl mx-auto">
            Choisissez le plan qui correspond à vos besoins. Commencez gratuitement.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto items-start">
          {plans.map((plan) => (
            <div key={plan.name}
              className={`relative rounded-3xl p-8 transition-all duration-300 hover:-translate-y-2 ${
                plan.highlighted
                  ? 'bg-white border-2 border-accent shadow-2xl scale-[1.02] z-10'
                  : 'bg-white border border-gray-100 shadow-medium'
              }`}>
              {plan.badge && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2">
                  <span className="px-5 py-1.5 bg-gradient-to-r from-accent to-accent-hover text-white text-sm font-bold rounded-full shadow-orange">
                    {plan.badge}
                  </span>
                </div>
              )}

              <div className="text-center mb-8">
                <h3 className="text-lg font-bold text-dark mb-3">{plan.name}</h3>
                <div className="flex items-baseline justify-center gap-1">
                  <span className="text-5xl font-black text-dark">{plan.price}</span>
                  {plan.currency && (
                    <span className="text-lg font-semibold text-muted ml-1">{plan.currency}</span>
                  )}
                </div>
                {plan.period && (
                  <div className="mt-1 text-sm text-muted">{plan.period}</div>
                )}
                {plan.discount && (
                  <div className="mt-2 inline-flex px-3 py-1 bg-green-50 text-green-700 text-xs font-bold rounded-full">
                    {plan.discount}
                  </div>
                )}
                <p className="text-sm text-muted mt-3">{plan.description}</p>
              </div>

              <ul className="space-y-3 mb-8">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-start gap-3 text-sm text-gray-600">
                    <svg className={`w-5 h-5 flex-shrink-0 mt-0.5 ${plan.highlighted ? 'text-accent' : 'text-primary'}`}
                      fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                    </svg>
                    {f}
                  </li>
                ))}
              </ul>

              <Link href="/download"
                className={`block text-center w-full py-3.5 rounded-2xl font-bold transition-all duration-300 ${
                  plan.highlighted
                    ? 'bg-gradient-to-r from-accent to-accent-hover text-white shadow-orange hover:shadow-xl hover:-translate-y-0.5'
                    : 'bg-primary-50 text-primary hover:bg-primary hover:text-white'
                }`}>
                {plan.cta}
              </Link>
            </div>
          ))}
        </div>

        {/* Import Historique */}
        <div className="max-w-3xl mx-auto mt-16">
          <div className="relative bg-white rounded-3xl border-2 border-indigo-200 p-8 shadow-medium overflow-hidden">
            <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-100 rounded-full -translate-y-1/2 translate-x-1/2 opacity-50" />
            <div className="relative flex flex-col md:flex-row items-center gap-8">
              <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-indigo-500 to-indigo-600 flex items-center justify-center shadow-lg flex-shrink-0">
                <span className="text-3xl">📥</span>
              </div>
              <div className="flex-1 text-center md:text-left">
                <h3 className="text-xl font-extrabold text-dark mb-1">Import Historique SMS</h3>
                <p className="text-muted text-sm mb-3">
                  Récupérez toutes vos anciennes transactions depuis vos SMS. Choisissez la période, l&apos;app analyse et crée les transactions automatiquement.
                </p>
                <div className="flex flex-wrap gap-3 justify-center md:justify-start text-xs text-gray-500">
                  <span className="flex items-center gap-1"><svg className="w-3.5 h-3.5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" /></svg> Illimité sur l&apos;appareil</span>
                  <span className="flex items-center gap-1"><svg className="w-3.5 h-3.5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" /></svg> Tous opérateurs</span>
                  <span className="flex items-center gap-1"><svg className="w-3.5 h-3.5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" /></svg> Paiement unique</span>
                </div>
              </div>
              <div className="text-center flex-shrink-0">
                <div className="text-3xl font-black text-dark">2 000</div>
                <div className="text-sm text-muted font-semibold">FCFA</div>
                <div className="text-xs text-indigo-600 font-bold mt-1">Achat unique</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
