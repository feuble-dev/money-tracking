'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';

const links = [
  { href: '/', label: 'Accueil' },
  { href: '/features', label: 'Fonctionnalites' },
  { href: '/pricing', label: 'Tarifs' },
  { href: '/docs', label: 'Documentation' },
];

export default function Navbar() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', onScroll);
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <nav className={`sticky top-0 z-50 transition-all duration-200 ${
      scrolled ? 'bg-white border-b border-gray-200 shadow-sm' : 'bg-transparent'
    }`}>
      <div className="max-w-6xl mx-auto px-4 sm:px-6">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2.5">
            <Image src="/logo.png" alt="MoneyTracking" width={36} height={36} className="rounded-lg" />
            <span className="text-lg font-bold text-dark">MoneyTracking</span>
          </Link>

          <div className="hidden md:flex items-center gap-1">
            {links.map((link) => (
              <Link key={link.href} href={link.href}
                className="px-3 py-2 text-sm text-gray-600 hover:text-dark rounded-lg transition-colors">
                {link.label}
              </Link>
            ))}
          </div>

          <div className="hidden md:block">
            <Link href="/download"
              className="px-5 py-2 bg-accent text-white text-sm font-medium rounded-lg hover:bg-accent-hover transition-colors">
              Telecharger
            </Link>
          </div>

          <button onClick={() => setMobileOpen(!mobileOpen)} className="md:hidden p-2 text-gray-600">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              {mobileOpen
                ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              }
            </svg>
          </button>
        </div>

        {mobileOpen && (
          <div className="md:hidden pb-4 border-t border-gray-100 mt-1">
            {links.map((link) => (
              <Link key={link.href} href={link.href} onClick={() => setMobileOpen(false)}
                className="block px-3 py-2.5 text-sm text-gray-600 hover:text-dark">
                {link.label}
              </Link>
            ))}
            <div className="mt-2 px-3">
              <Link href="/download"
                className="block text-center px-4 py-2.5 bg-accent text-white text-sm font-medium rounded-lg">
                Telecharger
              </Link>
            </div>
          </div>
        )}
      </div>
    </nav>
  );
}
