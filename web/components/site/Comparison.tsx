import React from 'react';
import Icon from './Icon';
import Reveal from './motion/Reveal';

type Cell = true | false | string;

const rows: { label: string; cahier: Cell; excel: Cell; app: Cell }[] = [
  { label: 'Noter chaque opération', cahier: 'À la main', excel: 'À la main', app: 'Automatique, depuis le SMS' },
  { label: 'Commission de chaque opération', cahier: 'Calcul à la main', excel: 'Formules à tenir', app: true },
  { label: 'Float de chaque puce', cahier: false, excel: 'Recopié', app: 'Lu dans le dernier SMS' },
  { label: 'Point de caisse du soir', cahier: 'Au crayon', excel: 'Possible', app: 'Écart calculé pour vous' },
  { label: 'Retrouver un client par son numéro', cahier: 'Feuilleter', excel: 'Rechercher', app: 'En un geste' },
  { label: 'Voir l’agence depuis chez soi', cahier: false, excel: false, app: 'Vue patron en continu' },
  { label: 'Si le cahier ou le téléphone se perd', cahier: 'Tout est perdu', excel: 'Selon la copie', app: 'Sauvegarde chiffrée' },
];

function Value({ v, strong = false }: { v: Cell; strong?: boolean }) {
  if (v === true) return <Icon name="check" className="h-5 w-5 text-accent" strokeWidth={2.4} />;
  if (v === false) return <span className="text-gray-300">—</span>;
  return <span className={strong ? 'font-semibold text-ink' : 'text-muted'}>{v}</span>;
}

/** Ce que l'app change par rapport au cahier et au tableur des agents. */
export default function Comparison() {
  return (
    <Reveal className="overflow-x-auto rounded-3xl border border-gray-200 bg-white">
      <table className="w-full min-w-[640px] text-left text-sm">
        <thead>
          <tr className="border-b border-gray-200">
            <th className="w-[34%] px-5 py-4 font-medium text-muted"> </th>
            <th className="px-5 py-4 font-display text-base font-bold text-dark">Le cahier</th>
            <th className="px-5 py-4 font-display text-base font-bold text-dark">Le tableur</th>
            <th className="bg-primary-50 px-5 py-4 font-display text-base font-bold text-primary">MoneyTracking</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {rows.map((r) => (
            <tr key={r.label}>
              <td className="px-5 py-4 font-medium text-dark">{r.label}</td>
              <td className="px-5 py-4"><Value v={r.cahier} /></td>
              <td className="px-5 py-4"><Value v={r.excel} /></td>
              <td className="bg-primary-50/50 px-5 py-4"><Value v={r.app} strong /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </Reveal>
  );
}
