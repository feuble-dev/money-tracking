import React from 'react';
import Hero from '@/components/site/Hero';
import Features from '@/components/site/Features';
import Pricing from '@/components/site/Pricing';
import Link from 'next/link';

export default function HomePage() {
  return (
    <>
      <Hero />

      {/* Comment ca marche */}
      <section className="py-20 bg-white border-b border-gray-100">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <h2 className="text-2xl sm:text-3xl font-bold text-dark mb-3">Comment ca marche</h2>
          <p className="text-muted mb-12 max-w-lg">Trois etapes pour automatiser votre gestion.</p>

          <div className="grid md:grid-cols-3 gap-10">
            {[
              {
                step: '1',
                title: 'Installez l\'app',
                description: 'Telechargez le fichier APK sur votre Android, indiquez votre pays et creez votre agence.',
              },
              {
                step: '2',
                title: 'Selectionnez vos operateurs',
                description: 'Orange Money, Moov Money, Coris Money... deja configures par MoneyTracking pour votre pays. Cochez, c\'est importe.',
              },
              {
                step: '3',
                title: 'Gerez votre activite',
                description: 'Les transactions se creent automatiquement a partir des SMS. Suivez vos stats, commissions et clients.',
              },
            ].map((s) => (
              <div key={s.step}>
                <span className="text-xs font-bold text-primary">{s.step}.</span>
                <h3 className="text-lg font-semibold text-dark mt-1 mb-2">{s.title}</h3>
                <p className="text-sm text-muted leading-relaxed">{s.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <Features limit={6} />
      <div className="pb-12 bg-white">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <Link href="/features"
            className="text-sm text-accent font-medium hover:underline">
            Voir toutes les fonctionnalites &rarr;
          </Link>
        </div>
      </div>

      {/* Pricing */}
      <Pricing />

      {/* Operateurs */}
      <section className="py-16 bg-white border-t border-gray-100">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <h2 className="text-2xl font-bold text-dark mb-2">Operateurs supportes</h2>
          <p className="text-muted text-sm mb-8">Compatible avec les operateurs Mobile Money du Burkina Faso.</p>
          <div className="flex flex-wrap gap-3">
            {['Orange Money', 'Moov Money', 'Coris Money'].map((op) => (
              <div key={op} className="px-5 py-3 bg-soft rounded-lg border border-gray-200 text-sm font-medium text-dark">
                {op}
              </div>
            ))}
            <div className="px-5 py-3 rounded-lg border border-dashed border-gray-300 text-sm text-muted">
              + tout operateur ajoute au catalogue par pays
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20 gradient-hero">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 text-center">
          <h2 className="text-2xl sm:text-3xl font-bold text-white mb-3">
            Pret a simplifier votre gestion ?
          </h2>
          <p className="text-blue-200 mb-8 max-w-md mx-auto text-sm">
            Essai gratuit 3 mois par agence. Aucune carte requise.
          </p>
          <Link href="/download"
            className="inline-flex items-center gap-2 px-6 py-3 bg-accent text-white font-semibold text-sm rounded-lg hover:bg-accent-hover transition-colors">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Telecharger MoneyTracking
          </Link>
        </div>
      </section>
    </>
  );
}
