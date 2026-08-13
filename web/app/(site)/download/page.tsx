import React from 'react';
import Image from 'next/image';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Telecharger - MoneyTracking',
  description: 'Telechargez MoneyTracking pour Android.',
};

export default function DownloadPage() {
  return (
    <>
      {/* Hero */}
      <section className="gradient-hero py-16 sm:py-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 text-center">
          <Image src="/logo.png" alt="MoneyTracking" width={80} height={80} className="mx-auto rounded-2xl mb-6" priority />
          <h1 className="text-3xl sm:text-4xl font-bold text-white mb-3">
            Telecharger MoneyTracking
          </h1>
          <p className="text-blue-200 mb-8 max-w-md mx-auto">
            La solution de gestion Mobile Money pour les agents au Burkina Faso.
          </p>
          <a href="#"
            className="inline-flex items-center gap-2 px-8 py-3.5 bg-accent text-white font-semibold rounded-lg hover:bg-accent-hover transition-colors text-sm">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Telecharger la v1.1.0
          </a>
          <p className="text-blue-300 text-xs mt-3">Fichier APK &middot; Android uniquement &middot; ~60 Mo</p>
        </div>
      </section>

      {/* Installation */}
      <section className="py-16 bg-white">
        <div className="max-w-3xl mx-auto px-4 sm:px-6">
          <h2 className="text-2xl font-bold text-dark mb-8">Installation</h2>
          <ol className="space-y-6">
            {[
              { title: 'Telecharger le fichier APK', desc: 'Cliquez sur le bouton ci-dessus pour obtenir le fichier d\'installation.' },
              { title: 'Autoriser les sources inconnues', desc: 'Dans Parametres > Securite, activez l\'installation depuis des sources inconnues.' },
              { title: 'Installer et lancer', desc: 'Ouvrez le fichier APK, suivez les instructions, puis creez votre code PIN.' },
            ].map((s, i) => (
              <li key={i} className="flex gap-4">
                <span className="w-7 h-7 rounded-full bg-primary text-white text-xs font-bold flex items-center justify-center flex-shrink-0 mt-0.5">
                  {i + 1}
                </span>
                <div>
                  <p className="font-semibold text-dark text-sm">{s.title}</p>
                  <p className="text-muted text-sm mt-0.5">{s.desc}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* Configuration requise */}
      <section className="py-16 bg-soft">
        <div className="max-w-3xl mx-auto px-4 sm:px-6">
          <h2 className="text-2xl font-bold text-dark mb-6">Configuration requise</h2>
          <div className="grid sm:grid-cols-2 gap-4">
            {[
              { label: 'Systeme', value: 'Android 6.0 (Marshmallow) ou superieur' },
              { label: 'Stockage', value: '60 Mo d\'espace libre' },
              { label: 'Permissions', value: 'Lecture des SMS pour la detection automatique' },
              { label: 'Internet', value: 'Non requis (fonctionne 100% hors ligne)' },
            ].map((r) => (
              <div key={r.label} className="p-4 bg-white rounded-lg border border-gray-200">
                <p className="text-xs text-muted uppercase tracking-wide mb-0.5">{r.label}</p>
                <p className="text-sm font-medium text-dark">{r.value}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Versions */}
      <section className="py-16 bg-white">
        <div className="max-w-3xl mx-auto px-4 sm:px-6">
          <h2 className="text-2xl font-bold text-dark mb-6">Historique des versions</h2>
          <div className="space-y-4">
            <div className="p-4 border border-gray-200 rounded-lg">
              <div className="flex items-center gap-3 mb-2">
                <span className="px-2 py-0.5 bg-primary/10 text-primary text-xs font-semibold rounded">v1.1.0</span>
                <span className="text-xs text-muted">Avril 2026</span>
                <span className="w-1.5 h-1.5 bg-green-500 rounded-full" />
              </div>
              <p className="text-sm text-gray-600">
                Import historique SMS, notifications admin, confirmation avancee avec CNIB/date naissance,
                annulation et revalidation, filtre commissions par operateur, licence non-bloquante.
              </p>
            </div>
            <div className="p-4 border border-gray-200 rounded-lg">
              <div className="flex items-center gap-3 mb-2">
                <span className="px-2 py-0.5 bg-gray-100 text-gray-600 text-xs font-semibold rounded">v1.0.0</span>
                <span className="text-xs text-muted">Mars 2026</span>
              </div>
              <p className="text-sm text-gray-600">
                Version initiale. Detection SMS, USSD, dashboard, commissions, gestion de caisse,
                export PDF/CSV, securite PIN/biometrique, sauvegarde.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Google Play */}
      <section className="py-16 bg-soft">
        <div className="max-w-3xl mx-auto px-4 sm:px-6">
          <div className="p-6 bg-white rounded-xl border border-dashed border-gray-300 text-center">
            <p className="font-semibold text-dark mb-1">Bientot sur Google Play</p>
            <p className="text-sm text-muted mb-3">
              MoneyTracking sera prochainement disponible sur le Play Store. Disponibilite prevue courant 2026.
            </p>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-14 gradient-hero">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 text-center">
          <p className="text-white font-semibold mb-1">Pret a commencer ?</p>
          <p className="text-blue-200 text-sm mb-6">30 jours d&apos;essai gratuit, toutes les fonctionnalites incluses.</p>
          <a href="#"
            className="inline-flex items-center gap-2 px-6 py-3 bg-accent text-white font-semibold text-sm rounded-lg hover:bg-accent-hover transition-colors">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Telecharger maintenant
          </a>
        </div>
      </section>
    </>
  );
}
