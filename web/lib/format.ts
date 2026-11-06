/** Formats d'affichage partagés (admin et site). */

const nf = new Intl.NumberFormat('fr-FR');
const compactNf = new Intl.NumberFormat('fr-FR', { notation: 'compact', maximumFractionDigits: 1 });

export const fcfa = (n: number | null | undefined) => `${nf.format(Math.round(n ?? 0))} FCFA`;
export const num = (n: number | null | undefined) => nf.format(n ?? 0);
export const compact = (n: number | null | undefined) => compactNf.format(n ?? 0);

export function dateFr(iso: string | null | undefined, withTime = false) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    ...(withTime ? { hour: '2-digit', minute: '2-digit' } : {}),
  });
}

/** « à l'instant », « il y a 5 min », « il y a 3 h », « hier », date. */
export function ago(iso: string | null | undefined) {
  if (!iso) return '—';
  const d = new Date(iso);
  const s = Math.round((Date.now() - d.getTime()) / 1000);
  if (s < 60) return "à l'instant";
  if (s < 3600) return `il y a ${Math.floor(s / 60)} min`;
  if (s < 86400) return `il y a ${Math.floor(s / 3600)} h`;
  if (s < 172800) return 'hier';
  if (s < 7 * 86400) return `il y a ${Math.floor(s / 86400)} j`;
  return dateFr(iso);
}
