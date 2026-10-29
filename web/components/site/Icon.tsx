import React from 'react';

/**
 * Jeu d'icônes du site (trait 1.6, style unique) — un seul endroit au lieu
 * de chemins SVG recopiés dans chaque composant.
 */
const paths = {
  sms: 'M4 6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v8a2.5 2.5 0 0 1-2.5 2.5H10l-4.5 3.5V17H6.5A2.5 2.5 0 0 1 4 14.5v-8Z M8 9.5h8 M8 12.5h5',
  wallet: 'M4 7.5A2.5 2.5 0 0 1 6.5 5H18v3 M4 7.5V17a2 2 0 0 0 2 2h13a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H6.5A2.5 2.5 0 0 1 4 7.5Z M16 13.5h.01',
  chart: 'M4 19h16 M7 15v-4 M12 15V7 M17 15v-6',
  pie: 'M12 3v9h9 M20.5 14.5A9 9 0 1 1 9.5 3.5',
  coins: 'M9 7c0 1.1 2.2 2 5 2s5-.9 5-2-2.2-2-5-2-5 .9-5 2Z M9 7v4c0 1.1 2.2 2 5 2s5-.9 5-2V7 M5 12c0 1.1 2.2 2 5 2 M5 12v4c0 1.1 2.2 2 5 2s5-.9 5-2v-1 M5 12c0-1.1 2.2-2 5-2',
  shield: 'M12 3l7 3v5c0 4.5-3 8.2-7 10-4-1.8-7-5.5-7-10V6l7-3Z M9 12l2 2 4-4',
  offline: 'M3 12a9 9 0 0 1 14.5-7.1 M21 12a9 9 0 0 1-14.5 7.1 M3 3l18 18',
  phone: 'M8 3h8a1.5 1.5 0 0 1 1.5 1.5v15A1.5 1.5 0 0 1 16 21H8a1.5 1.5 0 0 1-1.5-1.5v-15A1.5 1.5 0 0 1 8 3Z M11 18h2',
  users: 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z M3 20c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5 M16 4.5a3.5 3.5 0 0 1 0 6.5 M21 20c0-2.6-1.6-4.6-4-5.3',
  building: 'M4 20h16 M6 20V6l6-3 6 3v14 M10 9h.01 M14 9h.01 M10 13h.01 M14 13h.01 M10 20v-3h4v3',
  tag: 'M3.5 12.5 11.5 4.5H19.5v8l-8 8-8-8Z M15.5 8.5h.01',
  target: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z M12 12h.01',
  export: 'M12 4v11 M8 11l4 4 4-4 M5 20h14',
  lock: 'M7 11V8a5 5 0 0 1 10 0v3 M6 11h12v9H6z M12 15v2',
  sync: 'M20 11a8 8 0 0 0-14.3-4.6L4 8 M4 13a8 8 0 0 0 14.3 4.6L20 16 M4 4v4h4 M20 20v-4h-4',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  download: 'M12 4v11 M8 11l4 4 4-4 M5 20h14',
  arrowRight: 'M5 12h14 M13 6l6 6-6 6',
  arrowDown: 'M12 5v14 M6 13l6 6 6-6',
  arrowUp: 'M12 19V5 M6 11l6-6 6 6',
  swap: 'M7 7h12l-3-3 M17 17H5l3 3',
  plus: 'M12 5v14 M5 12h14',
  ussd: 'M6 4h12v16H6z M9 8h.01 M12 8h.01 M15 8h.01 M9 11h.01 M12 11h.01 M15 11h.01 M9 14h.01 M12 14h.01 M15 14h.01',
  menu: 'M4 7h16 M4 12h16 M4 17h16',
  close: 'M6 6l12 12 M18 6 6 18',
  chevron: 'M9 6l6 6-6 6',
  history: 'M3 12a9 9 0 1 0 3-6.7L3 8 M3 3v5h5 M12 7v5l3 2',
  bell: 'M18 9a6 6 0 1 0-12 0c0 7-3 8-3 8h18s-3-1-3-8 M10.5 21a2 2 0 0 0 3 0',
} as const;

export type IconName = keyof typeof paths;

export default function Icon({
  name,
  className = 'w-5 h-5',
  strokeWidth = 1.6,
}: {
  name: IconName;
  className?: string;
  strokeWidth?: number;
}) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={paths[name]} />
    </svg>
  );
}
