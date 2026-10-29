import type { IconName } from '@/components/site/Icon';
import type { Compteurs } from '@/lib/admin-types';

export interface NavItem {
  href: string;
  label: string;
  icon: IconName;
  /** Compteur affiché en pastille (voir /api/admin/compteurs/). */
  badge?: keyof Compteurs;
  /** Préfixe d'URL qui active l'entrée (par défaut : href). */
  match?: string;
}

/** Navigation de l'admin, groupée par usage. Source unique pour la barre
 *  latérale, la barre du haut (titre) et la palette de commandes. */
export const navGroups: { title: string; items: NavItem[] }[] = [
  {
    title: 'Pilotage',
    items: [{ href: '/dashboard', label: 'Tableau de bord', icon: 'dashboard' }],
  },
  {
    title: 'À traiter',
    items: [
      { href: '/demandes', label: 'Demandes', icon: 'inbox', badge: 'demandes' },
      { href: '/achats-historique', label: 'Import SMS', icon: 'history', badge: 'achats' },
    ],
  },
  {
    title: 'Comptes',
    items: [
      { href: '/clients', label: 'Clients', icon: 'users' },
      { href: '/licences', label: 'Licences', icon: 'key', badge: 'expirent' },
    ],
  },
  {
    title: 'Catalogue',
    items: [
      { href: '/catalog/countries', label: 'Pays', icon: 'target' },
      { href: '/catalog/operators', label: 'Opérateurs', icon: 'building' },
      { href: '/catalog/transaction-types', label: 'Types d’opération', icon: 'box' },
    ],
  },
  {
    title: 'Communication',
    items: [{ href: '/notifications', label: 'Notifications', icon: 'bell' }],
  },
];

export const navItems = navGroups.flatMap((g) => g.items);

export function isActive(item: NavItem, pathname: string) {
  const base = item.match ?? item.href;
  return pathname === base || pathname.startsWith(`${base}/`);
}

/** Titre de la page courante (barre du haut). */
export function titleFor(pathname: string) {
  if (pathname.startsWith('/clients/')) return 'Fiche client';
  if (pathname.startsWith('/catalog/operators/')) return 'Détail opérateur';
  return navItems.find((i) => isActive(i, pathname))?.label ?? 'Administration';
}
