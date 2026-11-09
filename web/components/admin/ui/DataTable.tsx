'use client';

import React, { useMemo, useState } from 'react';
import EmptyState from './EmptyState';

export interface Column<T> {
  key: string;
  header: string;
  render: (row: T) => React.ReactNode;
  /** Rend la colonne triable. */
  sortValue?: (row: T) => string | number;
  className?: string;
  /** Masquée sur petit écran. */
  hideOnMobile?: boolean;
}

/**
 * Tableau générique de l'admin : recherche, tri par colonne, pagination,
 * états chargement/vide. Toutes les listes l'utilisent, pour un
 * comportement identique partout.
 */
export default function DataTable<T>({
  rows,
  columns,
  rowKey,
  searchText,
  searchPlaceholder = 'Rechercher…',
  toolbar,
  loading = false,
  error,
  emptyTitle = 'Rien pour le moment',
  emptyText,
  onRowClick,
  pageSize = 20,
  initialSort,
  initialQuery = '',
}: {
  rows: T[];
  columns: Column<T>[];
  rowKey: (row: T) => string | number;
  searchText?: (row: T) => string;
  searchPlaceholder?: string;
  toolbar?: React.ReactNode;
  loading?: boolean;
  error?: string | null;
  emptyTitle?: string;
  emptyText?: string;
  onRowClick?: (row: T) => void;
  pageSize?: number;
  initialSort?: { key: string; dir: 'asc' | 'desc' };
  /** Recherche pré-remplie (ex. lien `?q=` depuis le tableau de bord). */
  initialQuery?: string;
}) {
  const [query, setQuery] = useState(initialQuery);
  const [sort, setSort] = useState(initialSort ?? null);
  const [page, setPage] = useState(0);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    let list = q && searchText ? rows.filter((r) => searchText(r).toLowerCase().includes(q)) : rows;
    const col = sort && columns.find((c) => c.key === sort.key);
    if (col?.sortValue) {
      const dir = sort!.dir === 'asc' ? 1 : -1;
      list = [...list].sort((a, b) => {
        const va = col.sortValue!(a);
        const vb = col.sortValue!(b);
        return (va > vb ? 1 : va < vb ? -1 : 0) * dir;
      });
    }
    return list;
  }, [rows, query, sort, columns, searchText]);

  const pages = Math.max(1, Math.ceil(filtered.length / pageSize));
  const current = Math.min(page, pages - 1);
  const visible = filtered.slice(current * pageSize, (current + 1) * pageSize);

  const toggleSort = (key: string) =>
    setSort((s) => (s?.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: 'desc' }));

  return (
    <div className="overflow-hidden rounded-2xl border border-gray-200/80 bg-white">
      {(searchText || toolbar) && (
        <div className="flex flex-col gap-3 border-b border-gray-100 p-4 sm:flex-row sm:items-center sm:justify-between">
          {searchText ? (
            <div className="relative w-full sm:max-w-xs">
              <svg className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-4.3-4.3M17 10.5a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0Z" />
              </svg>
              <input
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value);
                  setPage(0);
                }}
                placeholder={searchPlaceholder}
                className="h-10 w-full rounded-lg border border-gray-200 bg-white pl-9 pr-3 text-sm outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/15"
              />
            </div>
          ) : (
            <span />
          )}
          {toolbar && <div className="flex flex-wrap items-center gap-2">{toolbar}</div>}
        </div>
      )}

      {error ? (
        <EmptyState title="Chargement impossible" text={error} />
      ) : loading ? (
        <div className="divide-y divide-gray-100">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="flex gap-4 px-5 py-4">
              <div className="h-4 w-1/4 animate-pulse rounded bg-gray-100" />
              <div className="h-4 w-1/3 animate-pulse rounded bg-gray-100" />
              <div className="h-4 w-1/6 animate-pulse rounded bg-gray-100" />
            </div>
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <EmptyState title={query ? 'Aucun résultat' : emptyTitle} text={query ? `Rien ne correspond à « ${query} ».` : emptyText} />
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-soft/60">
                {columns.map((c) => (
                  <th
                    key={c.key}
                    className={`whitespace-nowrap px-5 py-3 text-left text-xs font-semibold text-muted ${
                      c.hideOnMobile ? 'hidden md:table-cell' : ''
                    } ${c.className ?? ''}`}
                  >
                    {c.sortValue ? (
                      <button onClick={() => toggleSort(c.key)} className="inline-flex items-center gap-1 hover:text-ink">
                        {c.header}
                        <span className="text-[10px]">
                          {sort?.key === c.key ? (sort.dir === 'asc' ? '▲' : '▼') : '↕'}
                        </span>
                      </button>
                    ) : (
                      c.header
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {visible.map((row) => (
                <tr
                  key={rowKey(row)}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                  className={`transition-colors ${onRowClick ? 'cursor-pointer hover:bg-soft/70' : ''}`}
                >
                  {columns.map((c) => (
                    <td
                      key={c.key}
                      className={`px-5 py-3.5 align-middle ${c.hideOnMobile ? 'hidden md:table-cell' : ''} ${c.className ?? ''}`}
                    >
                      {c.render(row)}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {!loading && !error && filtered.length > pageSize && (
        <div className="flex items-center justify-between border-t border-gray-100 px-5 py-3 text-sm text-muted">
          <span>
            {current * pageSize + 1}–{Math.min((current + 1) * pageSize, filtered.length)} sur {filtered.length}
          </span>
          <div className="flex gap-1">
            <button
              disabled={current === 0}
              onClick={() => setPage(current - 1)}
              className="rounded-md border border-gray-200 px-3 py-1 disabled:opacity-40"
            >
              Précédent
            </button>
            <button
              disabled={current >= pages - 1}
              onClick={() => setPage(current + 1)}
              className="rounded-md border border-gray-200 px-3 py-1 disabled:opacity-40"
            >
              Suivant
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
