import React from 'react';
import Hero from '@/components/site/Hero';
import Features from '@/components/site/Features';
import Pricing from '@/components/site/Pricing';
import Link from 'next/link';
import Image from 'next/image';

const steps = [
  {
    number: '01',
    title: 'Installez l\'application',
    description: 'Téléchargez MoneyTracking sur votre Android et créez votre code PIN de sécurité.',
    emoji: '📥',
  },
  {
    number: '02',
    title: 'Configurez vos opérateurs',
    description: 'Ajoutez Orange Money, Moov Money ou Coris Money. Collez un SMS exemple et l\'app fait le reste.',
    emoji: '⚙️',
  },
  {
    number: '03',
    title: 'Gérez votre activité',
    description: 'Les transactions se créent automatiquement par SMS. Suivez vos stats, commissions et clients.',
    emoji: '📊',
  },
];

export default function HomePage() {
  return (
    <>
      <Hero />

      {/* Comment ça marche */}
      <section className="py-24 bg-soft relative overflow-hidden">
        <div className="absolute top-0 right-0 w-96 h-96 bg-primary/5 rounded-full blur-3xl -translate-y-1/2" />
        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary-50 text-primary text-sm font-semibold rounded-full mb-4">
              Simple & rapide
            </div>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-dark mb-4">
              Comment ça marche ?
            </h2>
            <p className="text-lg text-muted max-w-2xl mx-auto">
              Trois étapes simples pour automatiser votre gestion Mobile Money.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {steps.map((step, i) => (
              <div key={step.number} className="relative">
                {i < steps.length - 1 && (
                  <div className="hidden md:block absolute top-14 left-[60%] w-[80%] h-0.5 bg-gradient-to-r from-primary/20 to-transparent" />
                )}
                <div className="text-center">
                  <div className="inline-flex items-center justify-center w-28 h-28 rounded-3xl bg-white shadow-large text-4xl mb-6 card-hover">
                    {step.emoji}
                  </div>
                  <div className="inline-block px-3 py-1 bg-primary/10 text-primary text-sm font-bold rounded-full mb-3">
                    Étape {step.number}
                  </div>
                  <h3 className="text-xl font-bold text-dark mb-3">{step.title}</h3>
                  <p className="text-muted leading-relaxed">{step.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features preview */}
      <Features limit={6} />
      <div className="text-center pb-16 bg-white">
        <Link href="/features"
          className="inline-flex items-center gap-2 px-6 py-3 text-primary font-semibold hover:bg-primary-50 rounded-xl transition-colors">
          Voir toutes les fonctionnalités
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </Link>
      </div>

      {/* Pricing */}
      <Pricing />

      {/* Operators section */}
      <section className="py-20 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-extrabold text-dark mb-4">Opérateurs supportés</h2>
            <p className="text-lg text-muted">Compatible avec tous les opérateurs Mobile Money du Burkina Faso</p>
          </div>
          <div className="flex flex-wrap justify-center gap-8">
            {['Orange Money', 'Moov Money', 'Coris Money'].map((op) => (
              <div key={op} className="flex items-center gap-4 px-8 py-5 bg-soft rounded-2xl border border-gray-100 card-hover">
                <div className="w-12 h-12 bg-primary-50 rounded-xl flex items-center justify-center">
                  <span className="text-2xl">🏦</span>
                </div>
                <div>
                  <div className="font-bold text-dark">{op}</div>
                  <div className="text-sm text-muted">Burkina Faso</div>
                </div>
              </div>
            ))}
            <div className="flex items-center gap-4 px-8 py-5 bg-soft rounded-2xl border border-dashed border-gray-300">
              <div className="w-12 h-12 bg-gray-100 rounded-xl flex items-center justify-center">
                <span className="text-2xl">➕</span>
              </div>
              <div>
                <div className="font-bold text-dark">Tout opérateur</div>
                <div className="text-sm text-muted">Extensible & configurable</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-24 gradient-hero relative overflow-hidden">
        <div className="absolute inset-0 opacity-10" style={{
          backgroundImage: 'radial-gradient(circle at 1px 1px, white 1px, transparent 0)',
          backgroundSize: '40px 40px',
        }} />
        <div className="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <Image src="/logo.png" alt="MoneyTracking" width={72} height={72} className="mx-auto rounded-2xl shadow-2xl mb-8" />
          <h2 className="text-3xl sm:text-5xl font-black text-white mb-6">
            Prêt à simplifier votre gestion ?
          </h2>
          <p className="text-xl text-blue-100 mb-10 max-w-2xl mx-auto">
            Rejoignez les agents Mobile Money qui font confiance à MoneyTracking pour gérer leur activité quotidienne.
          </p>
          <Link href="/download"
            className="inline-flex items-center gap-3 px-10 py-5 bg-gradient-to-r from-accent to-accent-hover text-white text-xl font-bold rounded-2xl shadow-xl shadow-accent/30 hover:shadow-2xl hover:-translate-y-1 transition-all duration-300">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Télécharger MoneyTracking
          </Link>
          <p className="text-blue-200 text-sm mt-4">Essai gratuit 30 jours — Aucune carte requise</p>
        </div>
      </section>
    </>
  );
}
