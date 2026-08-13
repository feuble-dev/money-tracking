import React from 'react';
import Link from 'next/link';
import Image from 'next/image';

export default function Hero() {
  return (
    <section className="gradient-hero">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 pt-20 pb-24 sm:pt-28 sm:pb-32">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          <div>
            <h1 className="text-4xl sm:text-5xl font-extrabold text-white leading-tight tracking-tight">
              Gerez votre agence Mobile Money sans effort
            </h1>
            <p className="mt-5 text-lg text-blue-100 leading-relaxed max-w-xl">
              MoneyTracking detecte vos SMS Orange Money, Moov Money et Coris Money pour creer
              automatiquement vos transactions, calculer vos commissions et suivre votre tresorerie.
            </p>
            <div className="mt-8 flex flex-col sm:flex-row gap-3">
              <Link href="/download"
                className="inline-flex items-center justify-center gap-2 px-6 py-3 bg-accent text-white font-semibold text-sm rounded-lg hover:bg-accent-hover transition-colors">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
                Telecharger pour Android
              </Link>
              <Link href="/features"
                className="inline-flex items-center justify-center px-6 py-3 text-white text-sm font-medium rounded-lg border border-white/25 hover:bg-white/10 transition-colors">
                Decouvrir les fonctionnalites
              </Link>
            </div>
            <div className="mt-10 flex flex-wrap gap-x-6 gap-y-2 text-sm text-blue-200">
              <span>3 operateurs supportes</span>
              <span className="text-blue-400">&middot;</span>
              <span>Fonctionne hors ligne</span>
              <span className="text-blue-400">&middot;</span>
              <span>Essai gratuit 30 jours</span>
            </div>
          </div>

          {/* Phone mockup */}
          <div className="hidden lg:flex justify-center">
            <div className="w-[280px] h-[560px] bg-gray-900 rounded-[2.5rem] p-3 shadow-2xl shadow-black/30 border border-white/10">
              <div className="absolute left-1/2 -translate-x-1/2 w-28 h-6 bg-gray-900 rounded-b-xl" style={{ position: 'relative', margin: '-12px auto 0' }} />
              <div className="w-full h-full bg-gradient-to-b from-primary-dark to-primary rounded-[2rem] overflow-hidden flex flex-col items-center pt-10 relative">
                <Image src="/logo.png" alt="MoneyTracking" width={72} height={72} className="rounded-2xl mb-4" />
                <p className="text-white text-lg font-bold">MoneyTracking</p>
                <p className="text-blue-200 text-xs mb-6">Gestion Mobile Money</p>

                <div className="w-full px-4 space-y-2.5">
                  <div className="bg-white/15 rounded-xl p-3 flex items-center gap-3">
                    <div className="w-8 h-8 bg-green-500/20 rounded-lg flex items-center justify-center">
                      <svg className="w-4 h-4 text-green-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                      </svg>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-xs font-medium">Depot Orange Money</p>
                      <p className="text-blue-200 text-[10px]">70 12 34 56</p>
                    </div>
                    <span className="text-green-300 text-sm font-semibold">+50 000</span>
                  </div>

                  <div className="bg-white/15 rounded-xl p-3 flex items-center gap-3">
                    <div className="w-8 h-8 bg-red-500/20 rounded-lg flex items-center justify-center">
                      <svg className="w-4 h-4 text-red-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 10l7-7m0 0l7 7m-7-7v18" />
                      </svg>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-xs font-medium">Retrait Moov Money</p>
                      <p className="text-blue-200 text-[10px]">65 98 76 54</p>
                    </div>
                    <span className="text-red-300 text-sm font-semibold">-25 000</span>
                  </div>

                  <div className="bg-white/15 rounded-xl p-3 flex items-center gap-3">
                    <div className="w-8 h-8 bg-green-500/20 rounded-lg flex items-center justify-center">
                      <svg className="w-4 h-4 text-green-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                      </svg>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white text-xs font-medium">Depot Coris Money</p>
                      <p className="text-blue-200 text-[10px]">76 54 32 10</p>
                    </div>
                    <span className="text-green-300 text-sm font-semibold">+100 000</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
