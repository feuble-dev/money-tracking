'use client';

import React from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import Icon from '@/components/site/Icon';
import { navGroups, isActive } from './nav';
import { useAdmin } from './AdminContext';

/** Barre latérale : fixe sur grand écran, tiroir sur mobile. */
export default function Sidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  const pathname = usePathname();
  const { compteurs } = useAdmin();

  return (
    <>
      {open && <div className="fixed inset-0 z-30 bg-dark/40 lg:hidden" onClick={onClose} />}
      <aside
        className={`fixed inset-y-0 left-0 z-40 flex w-64 flex-col border-r border-gray-200/80 bg-white transition-transform duration-200 lg:translate-x-0 ${
          open ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="flex h-16 items-center gap-2.5 px-5">
          <Image src="/logo.png" alt="" width={30} height={30} className="rounded-lg" />
          <span className="font-display text-[15px] font-bold text-ink">MoneyTracking</span>
          <span className="ml-auto rounded-md bg-soft px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-muted">
            Admin
          </span>
        </div>

        <nav className="flex-1 overflow-y-auto px-3 pb-4">
          {navGroups.map((g) => (
            <div key={g.title} className="mt-5 first:mt-2">
              <p className="mb-1.5 px-3 text-[11px] font-semibold uppercase tracking-wider text-gray-400">{g.title}</p>
              <ul className="space-y-0.5">
                {g.items.map((item) => {
                  const active = isActive(item, pathname);
                  const count = item.badge && compteurs ? compteurs[item.badge] : 0;
                  return (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        onClick={onClose}
                        className={`group flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                          active ? 'bg-primary-50 text-primary' : 'text-gray-600 hover:bg-soft hover:text-ink'
                        }`}
                      >
                        <Icon
                          name={item.icon}
                          className={`h-[18px] w-[18px] ${active ? 'text-primary' : 'text-gray-400 group-hover:text-gray-600'}`}
                          strokeWidth={1.8}
                        />
                        <span className="truncate">{item.label}</span>
                        {count > 0 && (
                          <span
                            className={`ml-auto min-w-[20px] rounded-full px-1.5 py-0.5 text-center text-[11px] font-semibold tabular-nums ${
                              item.badge === 'expirent' ? 'bg-amber-100 text-amber-800' : 'bg-accent text-white'
                            }`}
                          >
                            {count}
                          </span>
                        )}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </nav>

        <div className="border-t border-gray-100 p-3">
          <Link
            href="/"
            className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-gray-500 transition-colors hover:bg-soft hover:text-ink"
          >
            <Icon name="external" className="h-[18px] w-[18px]" strokeWidth={1.8} />
            Voir le site
          </Link>
        </div>
      </aside>
    </>
  );
}
