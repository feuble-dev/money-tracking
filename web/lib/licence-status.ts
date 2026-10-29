import type { Licence, LicenceStatut } from './admin-types';

const DAY = 86_400_000;

/** Statut réel : une licence encore « active » mais dont la date est passée est expirée. */
export function effectiveStatut(l: Pick<Licence, 'statut' | 'date_fin'>): LicenceStatut {
  if (l.statut === 'suspendue') return 'suspendue';
  return new Date(l.date_fin).getTime() + DAY < Date.now() ? 'expiree' : l.statut;
}

export const daysLeft = (dateFin: string) => Math.ceil((new Date(dateFin).getTime() - Date.now()) / DAY);

export const statutBadge: Record<LicenceStatut, { label: string; variant: 'success' | 'info' | 'danger' | 'neutral' }> = {
  active: { label: 'Payante', variant: 'success' },
  essai: { label: 'Essai', variant: 'info' },
  expiree: { label: 'Expirée', variant: 'neutral' },
  suspendue: { label: 'Suspendue', variant: 'danger' },
};
