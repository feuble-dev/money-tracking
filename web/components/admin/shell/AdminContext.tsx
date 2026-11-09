'use client';

import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { getCompteurs } from '@/lib/api';
import type { Compteurs } from '@/lib/admin-types';

type ToastKind = 'success' | 'error' | 'info';
interface Toast {
  id: number;
  kind: ToastKind;
  text: string;
}

interface AdminCtx {
  compteurs: Compteurs | null;
  /** À appeler après une action qui change un compteur (validation…). */
  refreshCompteurs: () => void;
  toast: (text: string, kind?: ToastKind) => void;
}

const Ctx = createContext<AdminCtx>({
  compteurs: null,
  refreshCompteurs: () => {},
  toast: () => {},
});

export const useAdmin = () => useContext(Ctx);

/** État partagé de l'admin : compteurs des badges et notifications « toast ». */
export function AdminProvider({ children }: { children: React.ReactNode }) {
  const [compteurs, setCompteurs] = useState<Compteurs | null>(null);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const nextId = useRef(0);

  const refreshCompteurs = useCallback(() => {
    getCompteurs().then(setCompteurs).catch(() => {});
  }, []);

  useEffect(() => {
    refreshCompteurs();
    const t = setInterval(refreshCompteurs, 60_000);
    return () => clearInterval(t);
  }, [refreshCompteurs]);

  const toast = useCallback((text: string, kind: ToastKind = 'success') => {
    const id = ++nextId.current;
    setToasts((l) => [...l, { id, kind, text }]);
    setTimeout(() => setToasts((l) => l.filter((x) => x.id !== id)), 3600);
  }, []);

  return (
    <Ctx.Provider value={{ compteurs, refreshCompteurs, toast }}>
      {children}
      <div aria-live="polite" className="pointer-events-none fixed bottom-4 right-4 z-[60] flex flex-col items-end gap-2">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={`fade-up pointer-events-auto flex items-center gap-2.5 rounded-xl px-4 py-3 text-sm font-medium text-white shadow-lg ${
              t.kind === 'error' ? 'bg-red-600' : t.kind === 'info' ? 'bg-ink' : 'bg-emerald-700'
            }`}
          >
            {t.text}
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}
