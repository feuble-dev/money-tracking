import React from 'react';
import Image from 'next/image';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Telecharger - MoneyTracking',
  description: 'Telechargez MoneyTracking pour Android. Compatible Android 6.0 et plus.',
};

export default function DownloadPage() {
  return (
    <>
      {/* Hero Section */}
      <section className="gradient-hero py-20 relative overflow-hidden">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-20 left-1/4 w-96 h-96 bg-white rounded-full blur-3xl" />
          <div className="absolute bottom-0 right-1/4 w-72 h-72 bg-orange-300 rounded-full blur-3xl" />
        </div>
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center relative z-10">
          {/* Logo */}
          <div className="mb-8 flex justify-center">
            <div className="relative w-32 h-32 sm:w-40 sm:h-40 float-animation">
              <Image
                src="/logo.png"
                alt="MoneyTracking"
                fill
                className="object-contain drop-shadow-2xl"
                priority
              />
            </div>
          </div>

          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white mb-4">
            Telecharger{' '}
            <span className="bg-gradient-to-r from-orange-300 to-orange-500 bg-clip-text text-transparent">
              MoneyTracking
            </span>
          </h1>
          <p className="text-xl text-blue-100 mb-10 max-w-2xl mx-auto">
            La solution complete pour gerer votre agence Mobile Money au Burkina Faso.
          </p>

          {/* Download Button */}
          <a
            href="#"
            className="inline-flex items-center gap-3 px-12 py-6 bg-[#FF6B35] text-white text-xl font-bold rounded-2xl hover:brightness-110 transition-all shadow-2xl shadow-orange-500/40 hover:-translate-y-1 glow-orange mb-6"
          >
            <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Telecharger MoneyTracking v1.1.0
          </a>

          <p className="text-blue-200 text-sm">Fichier APK - Android uniquement - ~60 Mo</p>
        </div>
      </section>

      {/* Installation Steps */}
      <section className="py-20 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-14">
            <h2 className="text-3xl sm:text-4xl font-bold text-[#0F1923] mb-4">
              Installation en 3 etapes
            </h2>
            <p className="text-[#64748B] text-lg">Simple, rapide et sans compte Google Play requis.</p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {/* Step 1 */}
            <div className="relative group">
              <div className="glass-card rounded-3xl p-8 text-center card-hover h-full border border-gray-100 hover:border-[#1565C0]/20 transition-all">
                <div className="w-16 h-16 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-[#1565C0] to-[#42A5F5] flex items-center justify-center shadow-lg shadow-blue-500/20">
                  <span className="text-3xl">📥</span>
                </div>
                <div className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-[#1565C0] text-white text-sm font-bold mb-4">
                  1
                </div>
                <h3 className="text-lg font-bold text-[#0F1923] mb-3">Telecharger le fichier APK</h3>
                <p className="text-[#64748B] text-sm leading-relaxed">
                  Cliquez sur le bouton de telechargement ci-dessus pour obtenir le fichier d&apos;installation MoneyTracking.
                </p>
              </div>
              {/* Arrow */}
              <div className="hidden md:block absolute top-1/2 -right-4 transform -translate-y-1/2 z-10 text-[#1565C0]/30">
                <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z" />
                </svg>
              </div>
            </div>

            {/* Step 2 */}
            <div className="relative group">
              <div className="glass-card rounded-3xl p-8 text-center card-hover h-full border border-gray-100 hover:border-[#FF6B35]/20 transition-all">
                <div className="w-16 h-16 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-[#FF6B35] to-orange-400 flex items-center justify-center shadow-lg shadow-orange-500/20">
                  <span className="text-3xl">⚙️</span>
                </div>
                <div className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-[#FF6B35] text-white text-sm font-bold mb-4">
                  2
                </div>
                <h3 className="text-lg font-bold text-[#0F1923] mb-3">Autoriser les sources inconnues</h3>
                <p className="text-[#64748B] text-sm leading-relaxed">
                  Allez dans <span className="font-semibold text-[#0F1923]">Parametres &gt; Securite &gt; Sources inconnues</span> et activez l&apos;option pour permettre l&apos;installation.
                </p>
              </div>
              {/* Arrow */}
              <div className="hidden md:block absolute top-1/2 -right-4 transform -translate-y-1/2 z-10 text-[#1565C0]/30">
                <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z" />
                </svg>
              </div>
            </div>

            {/* Step 3 */}
            <div className="group">
              <div className="glass-card rounded-3xl p-8 text-center card-hover h-full border border-gray-100 hover:border-green-500/20 transition-all">
                <div className="w-16 h-16 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-green-500 to-green-600 flex items-center justify-center shadow-lg shadow-green-500/20">
                  <span className="text-3xl">🚀</span>
                </div>
                <div className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-green-500 text-white text-sm font-bold mb-4">
                  3
                </div>
                <h3 className="text-lg font-bold text-[#0F1923] mb-3">Installer et lancer</h3>
                <p className="text-[#64748B] text-sm leading-relaxed">
                  Ouvrez le fichier APK telecharge, suivez les instructions d&apos;installation, puis lancez MoneyTracking et creez votre PIN.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* System Requirements */}
      <section className="py-20 bg-[#F5F7FA]">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-[#0F1923] mb-3">Configuration requise</h2>
            <p className="text-[#64748B]">MoneyTracking est leger et fonctionne sur la plupart des telephones Android.</p>
          </div>

          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {[
              { icon: '📱', label: 'Systeme', value: 'Android 6.0+', sub: 'Marshmallow ou superieur' },
              { icon: '💾', label: 'Stockage', value: '60 Mo', sub: "Espace libre minimum" },
              { icon: '✉️', label: 'Permissions', value: 'SMS requise', sub: 'Pour la detection auto' },
              { icon: '🌐', label: 'Internet', value: 'Non requis', sub: '100% hors ligne' },
            ].map((req) => (
              <div key={req.label} className="bg-white rounded-2xl p-6 text-center shadow-sm hover:shadow-lg transition-shadow card-hover border border-gray-100">
                <span className="text-4xl mb-3 block">{req.icon}</span>
                <p className="text-xs font-medium text-[#64748B] uppercase tracking-wider mb-1">{req.label}</p>
                <p className="text-lg font-bold text-[#0F1923] mb-0.5">{req.value}</p>
                <p className="text-xs text-[#64748B]">{req.sub}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Version History */}
      <section className="py-20 bg-white">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-[#0F1923] mb-3">Historique des versions</h2>
            <p className="text-[#64748B]">Suivez les evolutions de MoneyTracking.</p>
          </div>

          <div className="rounded-2xl border border-gray-100 overflow-hidden">
            <table className="w-full">
              <thead>
                <tr className="bg-[#F5F7FA]">
                  <th className="text-left px-6 py-4 text-sm font-semibold text-[#0F1923]">Version</th>
                  <th className="text-left px-6 py-4 text-sm font-semibold text-[#0F1923]">Date</th>
                  <th className="text-left px-6 py-4 text-sm font-semibold text-[#0F1923]">Notes</th>
                </tr>
              </thead>
              <tbody>
                <tr className="border-t border-gray-100">
                  <td className="px-6 py-4">
                    <span className="inline-flex items-center gap-2 px-3 py-1 bg-[#1565C0]/10 text-[#1565C0] text-sm font-bold rounded-full">
                      <span className="pulse-dot w-2 h-2 bg-green-500 rounded-full inline-block" />
                      v1.1.0
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-[#64748B]">Avril 2026</td>
                  <td className="px-6 py-4 text-sm text-[#0F1923]">
                    Import historique SMS (2 000 FCFA), notifications admin, confirmation avancee avec CNIB/date naissance, annulation et revalidation des transactions, filtre commissions par operateur, systeme de licence non-bloquant.
                  </td>
                </tr>
                <tr className="border-t border-gray-100">
                  <td className="px-6 py-4">
                    <span className="inline-flex items-center gap-2 px-3 py-1 bg-gray-100 text-gray-600 text-sm font-bold rounded-full">
                      v1.0.0
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-[#64748B]">Mars 2026</td>
                  <td className="px-6 py-4 text-sm text-[#0F1923]">
                    Version initiale - Detection SMS, USSD, dashboard, commissions, gestion de caisse, export PDF/CSV, securite PIN/biometrique, sauvegarde.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Coming Soon - Google Play */}
      <section className="py-20 bg-[#F5F7FA]">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div className="relative p-10 sm:p-14 rounded-3xl bg-white border-2 border-dashed border-[#1565C0]/20 overflow-hidden">
            <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-[#1565C0] via-[#42A5F5] to-[#FF6B35]" />

            <div className="w-20 h-20 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-green-400 to-green-600 flex items-center justify-center shadow-lg">
              <svg className="w-10 h-10 text-white" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.61 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z" />
              </svg>
            </div>

            <h2 className="text-2xl sm:text-3xl font-bold text-[#0F1923] mb-3">
              Bientot sur Google Play Store
            </h2>
            <p className="text-[#64748B] mb-6 max-w-lg mx-auto">
              MoneyTracking sera prochainement disponible sur le Google Play Store pour une installation encore plus simple. Restez informe !
            </p>

            <div className="inline-flex items-center gap-2 px-6 py-3 bg-[#F5F7FA] text-[#64748B] font-medium rounded-xl border border-gray-200">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Disponibilite prevue : courant 2026
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-16 gradient-hero">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div className="flex justify-center mb-6">
            <Image src="/icon.png" alt="MoneyTracking" width={56} height={56} className="rounded-xl" />
          </div>
          <h2 className="text-2xl sm:text-3xl font-bold text-white mb-3">
            Pret a optimiser votre agence ?
          </h2>
          <p className="text-blue-100 mb-8 max-w-xl mx-auto">
            30 jours d&apos;essai gratuit. Aucune carte bancaire requise. Toutes les fonctionnalites incluses.
          </p>
          <a
            href="#"
            className="inline-flex items-center gap-3 px-10 py-5 bg-[#FF6B35] text-white text-lg font-bold rounded-2xl hover:brightness-110 transition-all shadow-2xl shadow-orange-500/30 hover:-translate-y-1"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Telecharger maintenant
          </a>
        </div>
      </section>
    </>
  );
}
