'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import Icon, { type IconName } from '@/components/site/Icon';
import { searchAdmin } from '@/lib/api';
import type { SearchResults } from '@/lib/admin-types';
import { navItems } from './nav';

interface Result {
  key: string;
  group: string;
  icon: IconName;
  label: string;
  hint?: string;
  href: string;
}

/**
 * Palette de commandes (Ctrl+K) : aller à une page, retrouver un client par
 * son numéro, une agence par son nom, une licence par son code.
 */
export default function CommandPalette({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter();
  const [q, setQ] = useState('');
  const [remote, setRemote] = useState<SearchResults | null>(null);
  const [loading, setLoading] = useState(false);
  const [cursor, setCursor] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!open) return;
    setQ('');
    setRemote(null);
    setCursor(0);
    requestAnimationFrame(() => inputRef.current?.focus());
  }, [open]);

  // Recherche serveur, avec un court délai pour ne pas interroger à chaque touche.
  useEffect(() => {
    const term = q.trim();
    if (term.length < 2) {
      setRemote(null);
      return;
    }
    setLoading(true);
    let alive = true;
    const t = setTimeout(() => {
      searchAdmin(term)
        .then((r) => alive && setRemote(r))
        .catch(() => alive && setRemote(null))
        .finally(() => alive && setLoading(false));
    }, 200);
    return () => {
      alive = false;
      clearTimeout(t);
    };
  }, [q]);

  const results = useMemo<Result[]>(() => {
    const term = q.trim().toLowerCase();
    const pages: Result[] = navItems
      .filter((i) => !term || i.label.toLowerCase().includes(term))
      .map((i) => ({ key: `p${i.href}`, group: 'Pages', icon: i.icon, label: i.label, href: i.href }));
    if (!remote) return pages;
    return [
      ...remote.clients.map((c) => ({
        key: `c${c.id}`, group: 'Clients', icon: 'users' as IconName,
        label: c.telephone, hint: [c.nom, c.type === 'agence' ? 'Agence' : 'Particulier'].filter(Boolean).join(' · '),
        href: `/clients/${c.id}`,
      })),
      ...remote.agences.map((a) => ({
        key: `a${a.id}`, group: 'Agences', icon: 'building' as IconName,
        label: a.nom, hint: a.telephone, href: `/clients/${a.client_id}`,
      })),
      ...remote.licences.map((l) => ({
        key: `l${l.id}`, group: 'Licences', icon: 'key' as IconName,
        label: l.code, hint: l.agence, href: `/clients/${l.client_id}`,
      })),
      ...pages,
    ];
  }, [q, remote]);

  useEffect(() => setCursor(0), [results.length]);

  if (!open) return null;

  const go = (r: Result) => {
    onClose();
    router.push(r.href);
  };

  const onKey = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setCursor((c) => Math.min(c + 1, results.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setCursor((c) => Math.max(c - 1, 0));
    } else if (e.key === 'Enter' && results[cursor]) {
      go(results[cursor]);
    } else if (e.key === 'Escape') {
      onClose();
    }
  };

  let lastGroup = '';
  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-dark/40 p-4 pt-[12vh]" onMouseDown={onClose}>
      <div
        className="fade-up w-full max-w-xl overflow-hidden rounded-2xl bg-white shadow-2xl ring-1 ring-black/5"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-3 border-b border-gray-100 px-4">
          <Icon name="search" className="h-5 w-5 text-gray-400" strokeWidth={2} />
          <input
            ref={inputRef}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={onKey}
            placeholder="Numéro, agence, code de licence, page…"
            className="h-14 flex-1 bg-transparent text-[15px] outline-none placeholder:text-gray-400"
          />
          {loading && <span className="h-4 w-4 animate-spin rounded-full border-2 border-gray-300 border-t-primary" />}
          <kbd className="rounded border border-gray-200 px-1.5 py-0.5 text-[10px] text-muted">Échap</kbd>
        </div>
        <ul className="max-h-[50vh] overflow-y-auto p-2">
          {results.length === 0 && (
            <li className="px-3 py-8 text-center text-sm text-muted">Aucun résultat pour « {q} »</li>
          )}
          {results.map((r, i) => {
            const header = r.group !== lastGroup ? r.group : null;
            lastGroup = r.group;
            return (
              <React.Fragment key={r.key}>
                {header && <li className="px-3 pb-1 pt-3 text-[11px] font-semibold uppercase tracking-wider text-gray-400">{header}</li>}
                <li>
                  <button
                    onMouseEnter={() => setCursor(i)}
                    onClick={() => go(r)}
                    className={`flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left text-sm ${
                      i === cursor ? 'bg-primary-50 text-primary' : 'text-ink'
                    }`}
                  >
                    <Icon name={r.icon} className="h-4 w-4 flex-shrink-0 opacity-70" strokeWidth={1.8} />
                    <span className="truncate font-medium">{r.label}</span>
                    {r.hint && <span className="truncate text-xs text-muted">{r.hint}</span>}
                    {i === cursor && <Icon name="arrowRight" className="ml-auto h-4 w-4 flex-shrink-0" strokeWidth={2} />}
                  </button>
                </li>
              </React.Fragment>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
