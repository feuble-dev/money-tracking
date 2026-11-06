'use client';

import { useEffect, useRef, useState } from 'react';

/** Largeur réelle d'un conteneur, pour des graphiques SVG nets à toute taille. */
export function useWidth<T extends HTMLElement>(initial = 600) {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(initial);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(([entry]) => setWidth(Math.max(120, entry.contentRect.width)));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, width] as const;
}

export const shortDate = (iso: string) =>
  new Date(iso).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });

/** Graduations « rondes » pour l'axe des valeurs. */
export function niceMax(v: number) {
  if (v <= 0) return 1;
  const p = Math.pow(10, Math.floor(Math.log10(v)));
  const n = v / p;
  const step = n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10;
  return step * p;
}

/** Ancre d'un libellé d'axe : jamais coupé au bord du graphique. */
export const labelAnchor = (x: number, width: number) =>
  x < 28 ? 'start' : x > width - 28 ? 'end' : 'middle';
