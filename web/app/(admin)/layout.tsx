'use client';

import React, { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Sidebar from '@/components/admin/Sidebar';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const isLoginPage = pathname === '/login';

  useEffect(() => {
    const token = localStorage.getItem('admin_token');
    if (!token && !isLoginPage) {
      router.replace('/login');
    } else {
      setReady(true);
    }
  }, [isLoginPage, router]);

  if (isLoginPage) return <>{children}</>;

  if (!ready) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-soft">
        <div className="w-12 h-12 rounded-full border-4 border-primary/20 border-t-primary animate-spin" />
      </div>
    );
  }

  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    router.replace('/login');
  };

  const pageTitle = pathname.split('/').pop() || 'dashboard';

  return (
    <div className="min-h-screen bg-soft">
      <Sidebar />
      <div className="ml-64">
        {/* Header */}
        <header className="sticky top-0 z-20 bg-white/80 backdrop-blur-xl border-b border-gray-100/50">
          <div className="flex items-center justify-between h-20 px-8">
            <div>
              <h1 className="text-xl font-extrabold text-dark capitalize">{pageTitle}</h1>
            </div>
            <div className="flex items-center gap-4">
              {/* Admin badge */}
              <div className="flex items-center gap-2 px-3 py-1.5 bg-primary-50 rounded-xl">
                <div className="w-2 h-2 bg-green-400 rounded-full pulse-dot" />
                <span className="text-xs font-semibold text-primary">Admin</span>
              </div>
              <button onClick={handleLogout}
                className="flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-red-600 hover:bg-red-50 rounded-xl transition-all">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
                Déconnexion
              </button>
            </div>
          </div>
        </header>
        <main className="p-8">{children}</main>
      </div>
    </div>
  );
}
