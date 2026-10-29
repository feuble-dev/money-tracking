'use client';

import React, { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Icon from '@/components/site/Icon';
import Sidebar from '@/components/admin/shell/Sidebar';
import CommandPalette from '@/components/admin/shell/CommandPalette';
import { AdminProvider } from '@/components/admin/shell/AdminContext';
import { titleFor } from '@/components/admin/shell/nav';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const isLoginPage = pathname === '/login';

  useEffect(() => {
    if (!localStorage.getItem('admin_token') && !isLoginPage) {
      router.replace('/login');
    } else {
      setReady(true);
    }
  }, [isLoginPage, router]);

  // Ctrl+K / Cmd+K, ou « / » hors d'un champ : ouvre la recherche.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const typing = (e.target as HTMLElement)?.closest('input, textarea, select, [contenteditable]');
      if ((e.key === 'k' && (e.ctrlKey || e.metaKey)) || (e.key === '/' && !typing)) {
        e.preventDefault();
        setPaletteOpen(true);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  if (isLoginPage) return <>{children}</>;

  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-soft">
        <span className="h-8 w-8 animate-spin rounded-full border-[3px] border-primary/20 border-t-primary" />
      </div>
    );
  }

  const logout = () => {
    localStorage.removeItem('admin_token');
    router.replace('/login');
  };

  return (
    <AdminProvider>
      <div className="min-h-screen bg-soft">
        <Sidebar open={menuOpen} onClose={() => setMenuOpen(false)} />
        <div className="lg:pl-64">
          <header className="sticky top-0 z-20 border-b border-gray-200/80 bg-white/90 backdrop-blur">
            <div className="flex h-16 items-center gap-3 px-4 sm:px-6 lg:px-8">
              <button
                onClick={() => setMenuOpen(true)}
                aria-label="Menu"
                className="-ml-1 rounded-lg p-2 text-gray-500 hover:bg-soft lg:hidden"
              >
                <Icon name="menu" className="h-5 w-5" strokeWidth={2} />
              </button>
              <p className="truncate font-display text-[15px] font-semibold text-ink">{titleFor(pathname)}</p>

              <button
                onClick={() => setPaletteOpen(true)}
                className="ml-auto flex h-9 items-center gap-2 rounded-lg border border-gray-200 bg-soft/60 px-3 text-sm text-muted transition-colors hover:border-gray-300 sm:w-72"
              >
                <Icon name="search" className="h-4 w-4" strokeWidth={2} />
                <span className="hidden sm:inline">Rechercher…</span>
                <kbd className="ml-auto hidden rounded border border-gray-200 bg-white px-1.5 text-[10px] sm:inline">Ctrl K</kbd>
              </button>
              <button
                onClick={logout}
                title="Se déconnecter"
                className="flex h-9 items-center gap-2 rounded-lg px-2.5 text-sm font-medium text-gray-500 transition-colors hover:bg-red-50 hover:text-red-600"
              >
                <Icon name="logout" className="h-4 w-4" strokeWidth={2} />
                <span className="hidden md:inline">Déconnexion</span>
              </button>
            </div>
          </header>
          <main key={pathname} className="fade-up mx-auto max-w-[1400px] p-4 sm:p-6 lg:p-8">
            {children}
          </main>
        </div>
        <CommandPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} />
      </div>
    </AdminProvider>
  );
}
