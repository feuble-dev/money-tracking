import React from 'react';
import Link from 'next/link';
import Image from 'next/image';

export default function Footer() {
  return (
    <footer className="bg-dark text-gray-400">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-14">
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-10">
          <div>
            <Link href="/" className="flex items-center gap-2.5 mb-4">
              <Image src="/logo.png" alt="MoneyTracking" width={32} height={32} className="rounded-lg" />
              <span className="text-white font-bold">MoneyTracking</span>
            </Link>
            <p className="text-sm leading-relaxed">
              Application de gestion Mobile Money pour les agents au Burkina Faso.
            </p>
          </div>

          <div>
            <p className="text-white text-xs font-semibold uppercase tracking-wider mb-4">Navigation</p>
            <ul className="space-y-2.5 text-sm">
              {[
                { href: '/', label: 'Accueil' },
                { href: '/features', label: 'Fonctionnalites' },
                { href: '/pricing', label: 'Tarifs' },
                { href: '/download', label: 'Telecharger' },
              ].map((l) => (
                <li key={l.href}>
                  <Link href={l.href} className="hover:text-white transition-colors">{l.label}</Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <p className="text-white text-xs font-semibold uppercase tracking-wider mb-4">Support</p>
            <ul className="space-y-2.5 text-sm">
              {[
                { href: '/docs', label: 'Documentation' },
                { href: '/docs#faq', label: 'FAQ' },
                { href: '/docs#installation', label: "Guide d'installation" },
                { href: '/docs#operateurs', label: 'Configurer un operateur' },
              ].map((l, i) => (
                <li key={i}>
                  <Link href={l.href} className="hover:text-white transition-colors">{l.label}</Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <p className="text-white text-xs font-semibold uppercase tracking-wider mb-4">Contact</p>
            <ul className="space-y-2.5 text-sm">
              <li>contact@rftech-bf.com</li>
              <li>WhatsApp disponible</li>
              <li>Ouagadougou, Burkina Faso</li>
            </ul>
          </div>
        </div>

        <div className="mt-12 pt-6 border-t border-white/10 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs">
          <p>&copy; {new Date().getFullYear()} MoneyTracking par FEUBLE-TechBuilder</p>
          <p>Fait au Burkina Faso</p>
        </div>
      </div>
    </footer>
  );
}
