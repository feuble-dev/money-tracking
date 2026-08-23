'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const tabs = [
  { href: '/catalog/countries', label: 'Pays' },
  { href: '/catalog/operators', label: 'Opérateurs' },
  { href: '/catalog/transaction-types', label: 'Types de transaction' },
];

/// Sous-navigation du Catalogue — sans ça, "Types de transaction" n'est
/// atteignable que depuis le détail d'un opérateur, quasi introuvable.
export default function CatalogTabs() {
  const pathname = usePathname();

  return (
    <div className="flex items-center gap-1 border-b border-gray-200 mb-6">
      {tabs.map((tab) => {
        const isActive = pathname.startsWith(tab.href);
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
              isActive
                ? 'border-primary text-primary'
                : 'border-transparent text-muted hover:text-dark'
            }`}
          >
            {tab.label}
          </Link>
        );
      })}
    </div>
  );
}
