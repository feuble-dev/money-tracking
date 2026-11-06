'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname } from 'next/navigation';
import Icon from './Icon';

const links = [
  { href: '/features', label: 'Fonctionnalités' },
  { href: '/pricing', label: 'Tarifs' },
  { href: '/docs', label: 'Aide' },
];

export default function Navbar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => setOpen(false), [pathname]);

  return (
    <header
      className={`sticky top-0 z-50 transition-[background-color,border-color] duration-200 ${
        scrolled || open ? 'border-b border-gray-200 bg-white' : 'border-b border-transparent bg-soft'
      }`}
    >
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2.5">
          <Image src="/logo.png" alt="" width={34} height={34} className="rounded-lg" priority />
          <span className="font-display text-lg font-bold text-ink">MoneyTracking</span>
        </Link>

        <div className="hidden items-center gap-1 md:flex">
          {links.map((l) => {
            const active = pathname === l.href;
            return (
              <Link
                key={l.href}
                href={l.href}
                className={`relative rounded-lg px-3 py-2 text-sm transition-colors ${
                  active ? 'text-ink' : 'text-muted hover:text-ink'
                }`}
              >
                {l.label}
                <span
                  className={`absolute inset-x-3 -bottom-px h-0.5 rounded-full bg-primary transition-transform duration-300 ${
                    active ? 'scale-x-100' : 'scale-x-0'
                  }`}
                />
              </Link>
            );
          })}
          <Link
            href="/download"
            className="ml-3 rounded-lg bg-ink px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-dark"
          >
            Télécharger
          </Link>
        </div>

        <button
          onClick={() => setOpen(!open)}
          className="rounded-lg p-2 text-dark md:hidden"
          aria-label={open ? 'Fermer le menu' : 'Ouvrir le menu'}
          aria-expanded={open}
        >
          <Icon name={open ? 'close' : 'menu'} strokeWidth={2} />
        </button>
      </nav>

      <div
        className={`grid overflow-hidden transition-[grid-template-rows] duration-300 md:hidden ${
          open ? 'grid-rows-[1fr]' : 'grid-rows-[0fr]'
        }`}
      >
        <div className="min-h-0">
          <div className="space-y-1 px-4 pb-4">
            {links.map((l) => (
              <Link key={l.href} href={l.href} className="block rounded-lg px-3 py-2.5 text-dark hover:bg-soft">
                {l.label}
              </Link>
            ))}
            <Link href="/download" className="mt-2 block rounded-lg bg-ink px-4 py-3 text-center font-semibold text-white">
              Télécharger
            </Link>
          </div>
        </div>
      </div>
    </header>
  );
}
