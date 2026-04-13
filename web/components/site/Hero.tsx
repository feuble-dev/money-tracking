import React from 'react';
import Link from 'next/link';
import Image from 'next/image';

export default function Hero() {
  return (
    <section className="relative min-h-[92vh] gradient-hero overflow-hidden flex items-center">
      {/* Animated background */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-20 left-10 w-72 h-72 bg-white/5 rounded-full blur-3xl" />
        <div className="absolute bottom-20 right-10 w-96 h-96 bg-accent/10 rounded-full blur-3xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-primary-light/10 rounded-full blur-3xl" />
        <div className="absolute inset-0 opacity-[0.07]" style={{
          backgroundImage: 'radial-gradient(circle at 1px 1px, white 1px, transparent 0)',
          backgroundSize: '40px 40px',
        }} />
      </div>

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Text */}
          <div className="text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-white/10 backdrop-blur-sm border border-white/20 rounded-full mb-8">
              <div className="w-2 h-2 bg-green-400 rounded-full pulse-dot" />
              <span className="text-sm font-medium text-blue-100">Disponible au Burkina Faso</span>
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-black text-white leading-[1.1] mb-6">
              Gérez votre agence
              <span className="block mt-2">
                <span className="relative inline-block">
                  Mobile Money
                  <svg className="absolute -bottom-2 left-0 w-full" viewBox="0 0 300 12" fill="none">
                    <path d="M2 10C50 2 100 2 150 6C200 10 250 4 298 8" stroke="#FF6B35" strokeWidth="3" strokeLinecap="round" />
                  </svg>
                </span>
              </span>
              <span className="block mt-2 text-blue-200">en toute simplicité</span>
            </h1>

            <p className="text-lg sm:text-xl text-blue-100/90 leading-relaxed mb-10 max-w-xl mx-auto lg:mx-0">
              MoneyTracking détecte automatiquement vos SMS <strong className="text-white">Orange Money</strong>, <strong className="text-white">Moov Money</strong> et <strong className="text-white">Coris Money</strong> pour créer vos transactions sans effort.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <Link href="/download"
                className="group inline-flex items-center justify-center gap-3 px-8 py-4 bg-gradient-to-r from-accent to-accent-hover text-white text-lg font-bold rounded-2xl transition-all duration-300 shadow-xl shadow-accent/30 hover:shadow-2xl hover:-translate-y-1">
                <svg className="w-5 h-5 transition-transform group-hover:-translate-y-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
                Télécharger gratuitement
              </Link>
              <Link href="/features"
                className="inline-flex items-center justify-center gap-2 px-8 py-4 border-2 border-white/30 text-white text-lg font-semibold rounded-2xl hover:bg-white/10 backdrop-blur-sm transition-all duration-300">
                Voir les fonctionnalités
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              </Link>
            </div>

            <div className="mt-12 flex flex-wrap gap-6 justify-center lg:justify-start">
              {[
                { icon: '🏦', text: '3 opérateurs' },
                { icon: '📱', text: '100% hors ligne' },
                { icon: '📥', text: 'Import historique' },
                { icon: '⚡', text: '12 fonctionnalités' },
              ].map((b) => (
                <div key={b.text} className="flex items-center gap-2 text-sm text-blue-100/80">
                  <span className="text-lg">{b.icon}</span>
                  <span>{b.text}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Phone mockup */}
          <div className="hidden lg:flex justify-center">
            <div className="relative float-animation px-12 py-8">
              <div className="relative w-[300px] h-[600px] bg-gray-900 rounded-[3rem] p-3 shadow-2xl shadow-black/30 border border-white/10">
                <div className="absolute top-0 left-1/2 -translate-x-1/2 w-36 h-7 bg-gray-900 rounded-b-2xl z-10" />
                <div className="w-full h-full bg-gradient-to-b from-primary-dark via-primary to-primary-light rounded-[2.2rem] overflow-hidden flex flex-col items-center justify-center relative">
                  <Image src="/logo.png" alt="MoneyTracking" width={100} height={100} className="rounded-3xl shadow-2xl mb-6" />
                  <h3 className="text-white text-2xl font-extrabold mb-1">MoneyTracking</h3>
                  <p className="text-blue-200 text-sm">Gestion Mobile Money</p>
                  <div className="mt-8 space-y-3 px-6 w-full">
                    <div className="bg-white/15 backdrop-blur-sm rounded-xl p-3 flex items-center gap-3">
                      <div className="w-8 h-8 bg-green-400/20 rounded-lg flex items-center justify-center text-green-300 text-xs">&#8595;</div>
                      <div className="flex-1">
                        <div className="text-white text-xs font-semibold">Dépôt Orange Money</div>
                        <div className="text-blue-200 text-[10px]">70 12 34 56</div>
                      </div>
                      <span className="text-green-300 text-sm font-bold">+50 000</span>
                    </div>
                    <div className="bg-white/15 backdrop-blur-sm rounded-xl p-3 flex items-center gap-3">
                      <div className="w-8 h-8 bg-orange-400/20 rounded-lg flex items-center justify-center text-orange-300 text-xs">&#8593;</div>
                      <div className="flex-1">
                        <div className="text-white text-xs font-semibold">Retrait Moov Money</div>
                        <div className="text-blue-200 text-[10px]">65 98 76 54</div>
                      </div>
                      <span className="text-orange-300 text-sm font-bold">-25 000</span>
                    </div>
                    <div className="bg-white/15 backdrop-blur-sm rounded-xl p-3 flex items-center gap-3">
                      <div className="w-8 h-8 bg-green-400/20 rounded-lg flex items-center justify-center text-green-300 text-xs">&#8595;</div>
                      <div className="flex-1">
                        <div className="text-white text-xs font-semibold">Dépôt Coris Money</div>
                        <div className="text-blue-200 text-[10px]">76 54 32 10</div>
                      </div>
                      <span className="text-green-300 text-sm font-bold">+100 000</span>
                    </div>
                  </div>
                </div>
              </div>
              {/* Floating SMS card */}
              <div className="absolute top-24 -right-4 bg-white rounded-2xl shadow-large p-3 flex items-center gap-2 z-10" style={{ animation: 'float 5s ease-in-out infinite 1s' }}>
                <div className="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center text-green-600 text-sm">&#10003;</div>
                <div>
                  <div className="text-xs font-bold text-gray-800">SMS détecté</div>
                  <div className="text-[10px] text-gray-500">Orange Money</div>
                </div>
              </div>
              {/* Floating commission card */}
              <div className="absolute bottom-2 left-0 bg-white rounded-2xl shadow-large p-3" style={{ animation: 'float 5s ease-in-out infinite 2s' }}>
                <div className="text-xs font-bold text-gray-800">Commission</div>
                <div className="text-accent font-extrabold text-lg">+250 FCFA</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
