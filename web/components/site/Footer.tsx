import React from 'react';
import Link from 'next/link';
import Image from 'next/image';

const columns = [
  {
    title: 'Produit',
    links: [
      { href: '/features', label: 'Fonctionnalités' },
      { href: '/pricing', label: 'Tarifs' },
      { href: '/download', label: 'Télécharger' },
    ],
  },
  {
    title: 'Aide',
    links: [
      { href: '/docs', label: 'Guide d’utilisation' },
      { href: '/docs#installation', label: 'Installation' },
      { href: '/pricing#faq', label: 'Questions fréquentes' },
    ],
  },
];

export default function Footer() {
  return (
    <footer className="bg-dark text-gray-400">
      <div className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.4fr_1fr_1fr_1fr]">
          <div>
            <Link href="/" className="mb-4 flex items-center gap-2.5">
              <Image src="/logo.png" alt="" width={32} height={32} className="rounded-lg" />
              <span className="font-display font-bold text-white">MoneyTracking</span>
            </Link>
            <p className="max-w-xs text-sm leading-relaxed">
              Vos SMS Mobile Money transformés en comptes clairs, pour les particuliers et les agences
              du Burkina Faso.
            </p>
          </div>
          {columns.map((c) => (
            <div key={c.title}>
              <p className="mb-4 text-xs font-semibold uppercase tracking-wider text-white">{c.title}</p>
              <ul className="space-y-2.5 text-sm">
                {c.links.map((l) => (
                  <li key={l.href}>
                    <Link href={l.href} className="transition-colors hover:text-white">
                      {l.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
          <div>
            <p className="mb-4 text-xs font-semibold uppercase tracking-wider text-white">Contact</p>
            <ul className="space-y-2.5 text-sm">
              <li>
                <a href="mailto:contact@rftech-bf.com" className="transition-colors hover:text-white">
                  contact@rftech-bf.com
                </a>
              </li>
              <li>WhatsApp disponible</li>
              <li>Ouagadougou, Burkina Faso</li>
            </ul>
          </div>
        </div>

        <div className="mt-12 flex flex-col items-center justify-between gap-3 border-t border-white/10 pt-6 text-xs sm:flex-row">
          <p>&copy; {new Date().getFullYear()} MoneyTracking par FEUBLE-TechBuilder</p>
          <p>Fait au Burkina Faso</p>
        </div>
      </div>
    </footer>
  );
}
